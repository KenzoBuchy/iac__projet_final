resource "aws_launch_template" "app" {
  name_prefix            = "student-app-"
  image_id               = "ami-0ec10929233384c7f"
  instance_type          = var.instance_type
  key_name               = "projet_final"
  vpc_security_group_ids = [aws_security_group.app_sg.id]

  iam_instance_profile {
    name = data.aws_iam_instance_profile.lab_profile.name
  }

  user_data = base64encode(file("${path.module}/scripts/code_serveur_app.sh"))

  tag_specifications {
    resource_type = "instance"
    tags = { Name = "student-app-asg-instance", Environment = "poc", Project = "esgi-iac" }
  }

  tags = { Name = "student-app-lt", Environment = "poc", Project = "esgi-iac" }
}

resource "aws_autoscaling_group" "app" {
  name                      = "student-app-asg"
  min_size                  = 1
  max_size                  = 3
  desired_capacity          = 2
  vpc_zone_identifier       = [aws_subnet.public_1.id, aws_subnet.public_2.id]
  target_group_arns         = [aws_lb_target_group.app.arn]
  health_check_type         = "ELB"
  health_check_grace_period = 300

  launch_template {
    id      = aws_launch_template.app.id
    version = "$Latest"
  }

  depends_on = [aws_secretsmanager_secret_version.db_secret_value]
}

resource "aws_autoscaling_policy" "cpu" {
  name                   = "student-app-cpu-policy"
  autoscaling_group_name = aws_autoscaling_group.app.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = 50.0
  }
}
