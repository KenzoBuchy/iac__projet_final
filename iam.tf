# AWS Academy interdit la création de rôles IAM.
# LabInstanceProfile est un profil pré-existant dans le lab avec les permissions nécessaires
# (dont secretsmanager:GetSecretValue).
data "aws_iam_instance_profile" "lab_profile" {
  name = "LabInstanceProfile"
}
