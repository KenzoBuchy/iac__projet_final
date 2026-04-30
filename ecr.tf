resource "aws_ecr_repository" "app" {
  name                 = "student-app"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  tags = { Name = "student-app-ecr", Environment = "poc", Project = "esgi-iac" }
}
