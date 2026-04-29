# SG des serveurs web : HTTP public + SSH admin
resource "aws_security_group" "app_sg" {
  name        = "student-app-sg"
  description = "Acces HTTP et SSH pour les serveurs web"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP public"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH administration"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "MySQL depuis le VPC pour migration Cloud9"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "student-app-sg", Environment = "poc", Project = "esgi-iac" }
}

# SG RDS : MySQL accessible uniquement depuis les serveurs web et Cloud9 (migration)
resource "aws_security_group" "rds_sg" {
  name        = "student-rds-sg"
  description = "MySQL accessible depuis app et Cloud9 uniquement"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "MySQL depuis les serveurs web"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.app_sg.id]
  }

  ingress {
    description = "MySQL depuis le VPC pour migration Cloud9"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "student-rds-sg", Environment = "poc", Project = "esgi-iac" }
}
