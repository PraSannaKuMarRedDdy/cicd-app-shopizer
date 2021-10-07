resource "aws_launch_template" "javaapp_dev_app_lc" {
  name_prefix              = var.java_app_name
  image_id                    = "ami-0b0af3577fe5e3532"
  instance_type               = "t2.large"
  vpc_security_group_ids             = [aws_security_group.app_instance_sg.id]
  iam_instance_profile        {
        name = aws_iam_instance_profile.application_instance_profile.name
  }
  user_data = base64encode(local.instance_userdata)
  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size = 40
    }
  }
  lifecycle {
    create_before_destroy = true
  }
}

locals {
  instance_userdata = <<EOT
#!/bin/bash
set -x
sudo yum install -y https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/linux_amd64/amazon-ssm-agent.rpm
sudo yum install unzip -y
sudo yum install git -y
sudo yum install maven -y
sudo yum install wget -y
systemctl status amazon-ssm-agent
curl "https://s3.amazonaws.com/aws-cli/awscli-bundle.zip" -o "awscli-bundle.zip"
sudo ./awscli-bundle/install -i /usr/local/aws -b /usr/local/bin/aws
java -version
cd /tmp
//wget https://dlcdn.apache.org/tomcat/tomcat-9/v9.0.54/bin/apache-tomcat-9.0.54.tar.gz
//tar xzf apache-tomcat-9.0.54.tar.gz
//mv apache-tomcat-9.0.54 /usr/local/tomcat9
//cd /usr/local/tomcat9
//./bin/startup.sh
EOT
}

resource "aws_security_group" "app_instance_sg" {
  name = "${var.java_app_name}-instance-sg"
  description = "Allow access to services from LB traffic"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    description = "Applicaton port"
    security_groups = [aws_security_group.app_lb_sg.id]
  }
  ingress {
    from_port       = 0
    to_port         = 65535
    protocol        = "tcp"
    description = "VPC CIDR"
    cidr_blocks = ["10.0.0.0/8", "30.0.0.0/8", "10.124.248.0/22" ]
  }
ingress {
    from_port       = 0
    to_port         = 65535
    protocol        = "tcp"
    description = "VPC CIDR"
    cidr_blocks = ["0.0.0.0/0" ]
  }
    ingress {
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    description = "application port"
    security_groups = [aws_security_group.app_lb_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


resource "aws_autoscaling_group" "app_asg" {
  name = "${var.java_app_name}-instance-asg"
  max_size                  = 2
  min_size                  = 1
  health_check_grace_period = 300
  default_cooldown          = 15
  health_check_type         = "EC2"
  termination_policies = ["NewestInstance"]
  desired_capacity          = 1
  force_delete              = false
  launch_template {
    id      = aws_launch_template.javaapp_dev_app_lc.id
    version = "$Latest"
  }
  # launch_configuration      = aws_launch_template.ansible_tower_lc[count.index].name
  vpc_zone_identifier       = data.aws_subnet_ids.dev_subnet.ids
  target_group_arns         = [aws_lb_target_group.app_tg.arn]
  provisioner "local-exec" {
    command = "sleep 10"
  }
  # enabled_metrics           = ["GroupDesiredCapacity, GroupInServiceCapacity, GroupPendingCapacity, GroupMinSize, GroupMaxSize, GroupInServiceInstances, GroupPendingInstances, GroupStandbyInstances, GroupStandbyCapacity, GroupTerminatingCapacity, GroupTerminatingInstances, GroupTotalCapacity, GroupTotalInstances"]

  lifecycle {
    create_before_destroy = true
  }
  tag {
    key                 = "Name"
    value               = "java-app-instance"
    propagate_at_launch = true
  }
}

resource "aws_autoscaling_policy" "app_scaling_policy" {
  name                   = "${var.java_app_name}-asg-policy"
  policy_type            = "TargetTrackingScaling"
  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = 75.0
  }
  estimated_instance_warmup = 10
  autoscaling_group_name = aws_autoscaling_group.app_asg.name
}

resource "aws_lb" "app_lb" {
  name        = var.java_app_name # Max 6 characters
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.app_lb_sg.id]
  subnets            = data.aws_subnet_ids.dev_subnet.ids
}

resource "aws_lb_listener" "app_lb_80_listener" {
  load_balancer_arn = aws_lb.app_lb.arn
  port              = "8080"
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_tg.arn
  }
}


//resource "aws_lb_listener" "app_lb_443_listener" {
//  load_balancer_arn = aws_lb.app_lb.arn
//  port              = "443"
//  protocol          = "HTTPS"
//  certificate_arn   =  "arn:aws:acm:us-east-1:501429885081:certificate/ca691ba8-6bf0-45cf-b905-2aab8975e1da"
//  default_action {
//    type             = "forward"
//    target_group_arn = aws_lb_target_group.app_tg.arn
//  }
//}

resource "aws_lb_target_group" "app_tg" {
  name_prefix     = var.java_app_name
  port     = 8080
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    protocol = "HTTP"
    path = "/"
  }
}


resource "aws_security_group" "app_lb_sg" {
  name = "${var.java_app_name}-lbsg"
  description = "Allow web traffic from everywhere"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port       = 0
    to_port         = 65535
    protocol        = "tcp"
    description = "VPC CIDR"
    cidr_blocks = ["0.0.0.0/0" ]
  }

   ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port       = 0
    to_port         = 65535
    protocol        = "tcp"
    description = "VPC CIDR"
    cidr_blocks = ["10.0.0.0/8", "30.0.0.0/8", "10.124.248.0/22" ]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

