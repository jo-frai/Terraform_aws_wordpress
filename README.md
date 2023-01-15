# AWS , VPC , EC2, RDS
## Etapes 
### Pré-requis:
- [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) installer 
- [Terraform](https://www.terraform.io/downloads) installer

### Creer un Terraform user via IAM

### Creer le fichier Secrets file : secrets.tfvars
  - AWS_ACCESS_KEY <-- Key generé via IAM pour la création du user terraform
  - AWS_SECRET_KEY <-- Secret récuperé lors de la création de l'utilisateur
  - db_username <-- L'utilisateur qui sera créé pour le RDS
  - db_password <-- Le password pour l'utilisateur du RDS 
  - mon_ip <-- L'IP autorisé à se connecter en SSH 

### Créer une paire de clés SSH : ssh-keygen (with name key_wp.pem)

## Commandes pour utiliser Terraform
### Initialiser le projet
terraform init

### Planifier ce qui va etre deployé 
terraform plan -var-file="secrets.tfvars

### Appliquer le déploiement 
terraform apply -var-file="secrets.tfvars

### Detruire l'infrastructure
terraform destroy -var-file="secrets.tfvars"
