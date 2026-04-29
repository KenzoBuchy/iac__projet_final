# Groupe de sous-réseaux privés pour RDS (2 AZ obligatoires)
resource "aws_db_subnet_group" "rds_subnet_group" {
  name       = "student-rds-subnet-group"
  subnet_ids = [aws_subnet.private_1.id, aws_subnet.private_2.id]

  tags = { Name = "student-rds-subnet-group", Environment = "poc", Project = "esgi-iac" }
}

resource "aws_db_instance" "mysql" {
  identifier             = "student-db"
  engine                 = "mysql"
  engine_version         = "8.0"
  instance_class         = "db.t3.micro"
  allocated_storage      = 20
  db_name                = "STUDENTS"
  username               = var.db_username
  password               = var.db_password
  db_subnet_group_name   = aws_db_subnet_group.rds_subnet_group.name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  skip_final_snapshot    = true
  publicly_accessible    = false

  tags = { Name = "student-db", Environment = "poc", Project = "esgi-iac" }
}
