// Definir le provider ici on utilise aws 
provider "aws" {
  // La region est definit dans le vars.tf
  region = var.aws_region
  // Les clefs d'acces dans le terraform.tfvars
  access_key = var.AWS_ACCESS_KEY 
  secret_key = var.AWS_SECRET_KEY
}

// Creation de notre réseau VPC
resource "aws_vpc" "wp_vpc" {
  cidr_block           = var.vpc_cidr_block
  enable_dns_hostnames = true
  tags = {
    Name = "wp_vpc"
  }
}

// Creation de la gateway qui nous permettra de sortir de notre VPC pour aller sur internet
resource "aws_internet_gateway" "wp_igw" {
  vpc_id = aws_vpc.wp_vpc.id
  tags = {
    Name = "wp_igw"
  }
}

// Créer le sous-réseau public
resource "aws_subnet" "wp_public_subnet" {
  // Definir le VPC dans lequel sera notre sous-reseau
  vpc_id            = aws_vpc.wp_vpc.id
  // Definir la plage IP qui est dans le fichier var.tf
  cidr_block        = var.public_subnet_cidr_blocks
  tags = {
    Name = "wp_public_subnet"
  }
}

// Créer le sous-réseau privés
resource "aws_subnet" "wp_private_subnet" {
  vpc_id            = aws_vpc.wp_vpc.id
  // Compter les sous-réseaux pour boucler 
  count             = var.subnet_count.private
  cidr_block        = var.private_subnet_cidr_blocks[count.index]
  availability_zone = var.azs[count.index]
  tags = {
    Name = "wp_private_subnet_${count.index}"
  }
}

// Créer la route, pour pouvoir contacter la BDD et sortir sur internet, la wp_web va devoir sortir de son sous-résau
resource "aws_route_table" "wp_public_rt" {
  // La route sera associé avec tout ce qui sera dans le VPC 
  vpc_id = aws_vpc.wp_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    // Pour communiquer acceder au web on utilisera la gateway 
    gateway_id = aws_internet_gateway.wp_igw.id
  }
}

// Associer la route wp_public_rt au sous-réseaux public
resource "aws_route_table_association" "public" {
  route_table_id = aws_route_table.wp_public_rt.id
  subnet_id      = 	aws_subnet.wp_public_subnet.id
}

// Créer la route, pour pouvoir repondre aux requetes, la BDD va devoir sortir de son sous-résau on crée donc une route vers le VPC
resource "aws_route_table" "wp_private_rt" {
  vpc_id = aws_vpc.wp_vpc.id
}

// Associer la route wp_private_rt aux sous-réseaux privés
resource "aws_route_table_association" "private" {
  count          = var.subnet_count.private
  route_table_id = aws_route_table.wp_private_rt.id
  subnet_id      = aws_subnet.wp_private_subnet[count.index].id
}


// Créer les security group pour le serveur wp_web
resource "aws_security_group" "wp_web_sg" {
  name        = "wp_web_sg"
  vpc_id      = aws_vpc.wp_vpc.id
  ingress {
    description = "Autoriser les entrees pour le web"
    from_port   = "80"
    to_port     = "80"
    protocol    = "tcp"
    // Autoriser tout le monde à acceder 
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "Autoriser les entrees pour le SSH"
    from_port   = "22"
    to_port     = "22"
    protocol    = "tcp"
    // Uniquement notre IP publique /32 pour autoriser que notre IP à acceder en SSH
    cidr_blocks = [ "${var.mon_ip}" ]
  }
  egress {
    description = "Autoriser le traffic sortant pour donner acces au web pour telecharger les paquets pour l installation, les MAJ etc"
    from_port   = 0
    to_port     = 0
    // Tous les protocoles
    protocol    = "-1"
    // Tous le sécurity groupe wp web sg
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "wp_web_sg"
  }
}

// Créer les security group pour la BDD
resource "aws_security_group" "wp_db_sg" {
  name        = "wp_db_sg"
  vpc_id      = aws_vpc.wp_vpc.id
  ingress {
    description     = "Autoriser le wp web a entrer "
    from_port       = "3306"
    to_port         = "3306"
    protocol        = "tcp"
    security_groups = [aws_security_group.wp_web_sg.id]
  }
  tags = {
    Name = "wp_db_sg"
  }
}

// Creation d'un groupe db_subnet_group : Obligatoire, pour permettre à la BDD d'être toujours disponible sur une Zone."
resource "aws_db_subnet_group" "wp_db_subnet_group" {
  name        = "wp_db_subnet_group"
  // On vient boucler sur les 2 sous-réseaux privés pour les ajouter au groupe.
  subnet_ids  = [for subnet in aws_subnet.wp_private_subnet : subnet.id]
}

//Creation db_instance definir le type de base de données
resource "aws_db_instance" "wp_database" {
  // Les valeurs sont choisies dans AWS
  allocated_storage      = 10             // Taille du disque 10G
  engine                 = "mariaDB"      // Moteur de la BDD  
  engine_version         = "10.6.11"      // Version de mariaDB
  instance_class         = "db.t2.micro"  // Type d'instance 
  skip_final_snapshot    = true
  // Les valeurs sont definies dans le fichier secrets.tf
  db_name                = var.db_name
  username               = var.db_username
  password               = var.db_password
  // Le groupe de sous réseaux est definit juste au dessus aws_db_subnet_group
  db_subnet_group_name   = aws_db_subnet_group.wp_db_subnet_group.id
  // On asssocie les security_groups pour permettre à l'instance EC2 de contacter la BDD
  vpc_security_group_ids = [aws_security_group.wp_db_sg.id]
}

// Declarer la clef SSH que l'on souhaite utiliser
resource "aws_key_pair" "key_wp" {
  key_name   = "key_wp"
  public_key = file("key_wp.pub")
}

// Creation d'une EC2_instance VM qui sera utilisé comme serveur pour Wordpress "
resource "aws_instance" "wp_web" {
  ami                    = "ami-0e5d42f5caba49231"
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.wp_public_subnet.id
  key_name               = aws_key_pair.key_wp.key_name
  vpc_security_group_ids = [aws_security_group.wp_web_sg.id]
  // execution des commandes au demarrage de l instance 
  user_data = <<-EOF
#!/bin/bash
sudo apt update && sudo apt upgrade -y
sudo apt-get install -y apache2 awscli mariadb-client php php-mysql
sudo systemctl start apache2
sudo systemctl enable apache2
sudo rm -f /var/www/html/index.html
cd /tmp/ && sudo wget https://wordpress.org/latest.tar.gz
sudo tar -xvzf latest.tar.gz
sudo mv wordpress/wp-config-sample.php wordpress/wp-config.php
sudo rm -f latest.tar.gz
sudo mv wordpress/* /var/www/html/
sudo rm -rf wordpress/
sudo chown -R www-data:www-data /var/www/html/
sudo find /var/www/html/ -type f -exec chmod 644 {} \;
sudo find /var/www/html/ -type d -exec chmod 755 {} \;
sudo sed -i "s/^.*DB_NAME.*$/define('DB_NAME', '${aws_db_instance.wp_database.db_name}');/" /var/www/html/wp-config.php
sudo sed -i "s/^.*DB_USER.*$/define('DB_USER', '${var.db_username}');/" /var/www/html/wp-config.php
sudo sed -i "s/^.*DB_PASSWORD.*$/define('DB_PASSWORD', '${var.db_password}');/" /var/www/html/wp-config.php
sudo sed -i "s/^.*DB_HOST.*$/define('DB_HOST', '${aws_db_instance.wp_database.address}');/" /var/www/html/wp-config.php
sudo chmod 400 /var/www/html/wp-config.php
sudo systemctl restart apache2.service
EOF 
  tags = {
    Name = "wp_web"
  }
}

// Creation d'une Elastic_IP Ip publique fixe associé à wp web
resource "aws_eip" "wp_web_eip" {
  instance = aws_instance.wp_web.id
  vpc      = true
  tags = {
    Name = "wp_web_eip"
  }
}

