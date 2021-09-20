provider "aws" {
  region  = "us-east-1"
  profile = "default"
}

variable "server_port" {
  description = "The port the server will use for HTTP requests"
  type        = number
  default     = 8080
}

resource "aws_security_group" "terrainstance" {
  name = "terraform-instance"
  ingress {
    from_port   = var.server_port
    to_port     = var.server_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "elb" {
  name = "terraform-elb"
  # Allow all outbound
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  # Inbound HTTP from anywhere
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_launch_configuration" "terra" {
  image_id      = "ami-09e67e426f25ce0d7"
  instance_type = "t2.nano"
  key_name      = "terraform"


  user_data = <<-EOF
              #!/bin/bash
              echo "Hello, World" > index.html
              nohup busybox httpd -f -p "${var.server_port}" &
              EOF

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "asg" {
  launch_configuration = aws_launch_configuration.terra.id
  availability_zones   = ["us-east-1a", "us-east-1b"]

  min_size = 2
  max_size = 10

  load_balancers    = [aws_elb.elb.name]
  health_check_type = "ELB"

  tag {
    key                 = "Name"
    value               = "terraform-asg"
    propagate_at_launch = true
  }
}

resource "aws_elb" "elb" {
  name               = "terraform-asg"
  security_groups    = [aws_security_group.elb.id]
  availability_zones = ["us-east-1a", "us-east-1b"]
  health_check {
    target              = "HTTP:${var.server_port}/"
    interval            = 30
    timeout             = 3
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  # This adds a listener for incoming HTTP requests.
  listener {
    lb_port           = 80
    lb_protocol       = "http"
    instance_port     = var.server_port
    instance_protocol = "http"
  }
}

output "clb_dns_name" {
  value       = aws_elb.elb.dns_name
  description = "The domain name of the load balancer"
}