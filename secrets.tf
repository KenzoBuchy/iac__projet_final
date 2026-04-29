resource "aws_secretsmanager_secret" "db_secret" {
  name                    = "Mydbsecret"
  description             = "Database secret for web app"
  recovery_window_in_days = 0

  tags = { Environment = "poc", Project = "esgi-iac" }
}

# Le secret contient les credentials DB au format attendu par l'application Node.js
resource "aws_secretsmanager_secret_version" "db_secret_value" {
  secret_id = aws_secretsmanager_secret.db_secret.id

  secret_string = jsonencode({
    user     = var.db_username
    password = var.db_password
    host     = aws_db_instance.mysql.address
    db       = "STUDENTS"
  })
}
