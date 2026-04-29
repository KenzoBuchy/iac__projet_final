# Environnement Cloud9 pour exécuter les scripts CLI (migration, load test)
resource "aws_cloud9_environment_ec2" "cloud9" {
  name          = "student-app-cloud9"
  instance_type = "t3.micro"
  subnet_id     = aws_subnet.public_1.id
  image_id      = "amazonlinux-2023-x86_64"

  tags = { Environment = "poc", Project = "esgi-iac" }
}
