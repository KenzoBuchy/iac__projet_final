# Serveur POC (Phase 1) : Node.js + MySQL local — conservé pour la migration des données
resource "aws_instance" "poc_server" {
  ami                    = "ami-0ec10929233384c7f"
  instance_type          = var.instance_type
  key_name               = "projet_final"
  subnet_id              = aws_subnet.public_1.id
  vpc_security_group_ids = [aws_security_group.app_sg.id]
  user_data              = file("${path.module}/scripts/solution_code_poc.sh")

  tags = { Name = "student-poc-server", Environment = "poc", Project = "esgi-iac" }
}

# Serveur App (Phase 2) : Node.js → RDS via Secrets Manager (sans MySQL local)
resource "aws_instance" "app_server" {
  ami                    = "ami-0ec10929233384c7f"
  instance_type          = var.instance_type
  key_name               = "projet_final"
  subnet_id              = aws_subnet.public_1.id
  vpc_security_group_ids = [aws_security_group.app_sg.id]
  iam_instance_profile   = data.aws_iam_instance_profile.lab_profile.name
  user_data              = file("${path.module}/scripts/code_serveur_app.sh")

  # Attend que le secret soit créé avant de démarrer (l'app en a besoin au boot)
  depends_on = [aws_secretsmanager_secret_version.db_secret_value]

  tags = { Name = "student-app-server", Environment = "poc", Project = "esgi-iac" }
}
