// Declarer les variables dans le fichier secrets.tfvars
variable "AWS_ACCESS_KEY" {}
variable "AWS_SECRET_KEY" {}
variable "db_username" {}
variable "db_password" {}
variable "db_name" {}
variable "mon_ip" {}


variable "aws_region" {
  description = "Definition de la region eu-west-3 => Paris"
  default = "eu-west-3"
}

variable "azs" {
  description = "Permet d'assurer la disponibilite de la BDD dans 2 zones"
  default     = ["eu-west-3a", "eu-west-3b"]
}

variable "vpc_cidr_block" {
  description = "Definir la plage IP du VPC"
  default     = "10.0.0.0/16"
}

variable "subnet_count" {
  description = "Definir des numeros pour les sous réseaux, pour boucler sur la creation de subnet"
  default = {
    public  = 1,
    private = 2
  }
}

variable "public_subnet_cidr_blocks" {
  description = "Definir la plage IP du sous-réseaux public"
  default = "10.0.1.0/24"
}

variable "private_subnet_cidr_blocks" {
  description = "Definir la plage IP des sous-réseaux privé"
  default = ["10.0.11.0/24", "10.0.12.0/24"]
}

