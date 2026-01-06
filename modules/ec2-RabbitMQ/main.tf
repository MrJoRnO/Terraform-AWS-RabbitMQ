resource "aws_security_group" "rabbitmq_sg" {
  name        = "rabbitmq-sg"
  description = "Security group for RabbitMQ cluster"
  vpc_id      = var.vpc_id

  # 1. RabbitMQ Client Port (Internal only)
  ingress {
    from_port   = 5672
    to_port     = 5672
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"] 
  }

  # 2. Management UI - Allow ONLY from the Load Balancer (Security Requirement)
  ingress {
    from_port       = 15672
    to_port         = 15672
    protocol        = "tcp"
    # במקום 0.0.0.0/0, נשתמש ב-Security Group של ה-ALB
    security_groups = [var.alb_sg_id] 
  }

  # 3. Clustering & Inter-node (Crucial for High Availability)
  # Allowing all internal VPC traffic for RabbitMQ ports
  ingress {
    from_port   = 4369
    to_port     = 4369
    protocol    = "tcp"
    self        = true
  }

  ingress {
    from_port   = 25672
    to_port     = 25672
    protocol    = "tcp"
    self        = true
  }

  # 4. SSH Access - Allow ONLY from Bastion (Security Requirement)
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"] # Only internal or Bastion IP
  }

  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    self      = true 
  }

  # 5. Outbound Access (Fixes your "Connection Timed Out" issue)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "rabbitmq-sg" }
}

resource "aws_security_group" "alb_sg" {
  name        = "rabbitmq-alb-sg"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 15672
    to_port     = 15672
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] 
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_iam_role" "rabbitmq_role" {
  name = "rabbitmq-instance-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = var.common_tags
}

# יצירת ה-Profile שמחבר את ה-Role לשרת
resource "aws_iam_instance_profile" "rabbitmq_profile" {
  name = "rabbitmq-instance-profile"
  role = aws_iam_role.rabbitmq_role.name
}

resource "aws_instance" "rabbitmq" {
  count                  = var.node_count
  ami                    = var.ami_id
  instance_type          = var.instance_type
  subnet_id              = var.private_subnet_ids[count.index % 2]
  vpc_security_group_ids = [aws_security_group.rabbitmq_sg.id]
  key_name               = var.ssh_key_name
  iam_instance_profile   = aws_iam_instance_profile.rabbitmq_profile.name
  private_ip             = count.index == 0 ? "10.0.10.50" : null

  user_data = <<-EOF
    #!/bin/bash
    # 1. Network setup - Force IPv4 for stable downloads
    echo 'Acquire::ForceIPv4 "true";' > /etc/apt/apt.conf.d/99force-ipv4
    export DEBIAN_FRONTEND=noninteractive

    # 2. Add Cloudsmith repositories
    curl -1sLf 'https://setup.cloudsmith.io/rabbitmq/rabbitmq-erlang/setup.deb.sh' | bash
    curl -1sLf 'https://setup.cloudsmith.io/rabbitmq/rabbitmq-server/setup.deb.sh' | bash

    # 3. Install RabbitMQ and Erlang
    apt-get update -y
    apt-get install -y erlang-nox rabbitmq-server

    # 4. Clustering configuration (Injected by Terraform)
    mkdir -p /var/lib/rabbitmq/
    echo "${var.erlang_cookie}" > /var/lib/rabbitmq/.erlang.cookie
    chown rabbitmq:rabbitmq /var/lib/rabbitmq/.erlang.cookie
    chmod 400 /var/lib/rabbitmq/.erlang.cookie

    # 5. Service start
    systemctl restart rabbitmq-server
    systemctl enable rabbitmq-server

    # 6. Management UI and Admin User
    sleep 20
    /usr/sbin/rabbitmq-plugins enable rabbitmq_management
    /usr/sbin/rabbitmqctl add_user admin admin123 || true
    /usr/sbin/rabbitmqctl set_user_tags admin administrator
    /usr/sbin/rabbitmqctl set_permissions -p / admin ".*" ".*" ".*"

    # 7. Cluster Join Logic (Automatically joins nodes 1 and 2 to node 0)
    NODE_INDEX=${count.index}
    if [ "$NODE_INDEX" -ne 0 ]; then
        sleep 60
        /usr/sbin/rabbitmqctl stop_app
        /usr/sbin/rabbitmqctl reset
        /usr/sbin/rabbitmqctl join_cluster rabbit@ip-10-0-10-50
        /usr/sbin/rabbitmqctl start_app
    fi
  EOF

  tags = merge(var.common_tags, {
    Name = "rabbitmq-node-${count.index}"
  })
}

resource "aws_lb" "rabbitmq_alb" {
  name               = "rabbitmq-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = var.public_subnet_ids
  tags               = var.common_tags
}

resource "aws_lb_target_group" "rabbitmq_tg" {
  name     = "rabbitmq-mgmt-tg"
  port     = 15672
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    path = "/"
    port = "15672"
  }
}

resource "aws_lb_listener" "mgmt_listener" {
  load_balancer_arn = aws_lb.rabbitmq_alb.arn
  port              = 15672
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.rabbitmq_tg.arn
  }
}

resource "aws_lb_target_group_attachment" "rabbitmq_attachment" {
  count            = var.node_count
  target_group_arn = aws_lb_target_group.rabbitmq_tg.arn
  target_id        = aws_instance.rabbitmq[count.index].id
}
