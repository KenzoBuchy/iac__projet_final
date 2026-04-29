variable "aws_region" {
  description = "Region AWS ou deployer l infrastructure"
  type        = string
  default     = "us-east-1"
}

variable "instance_type" {
  description = "Type d instance EC2"
  type        = string
  default     = "t3.micro"
}

variable "db_username" {
  description = "Nom d utilisateur de la base de données RDS"
  type        = string
  default     = "nodeapp"
}

variable "db_password" {
  description = "Mot de passe de la base de données RDS"
  type        = string
  sensitive   = true
}
