locals {
  tags = merge(
    {
      Name       = var.name
      ManagedBy  = "terraform"
      Repository = "terraform-aws-serverless-genguardx"
    },
    var.tags
  )

  database_subnet_ids = length(var.database_subnet_ids) > 0 ? var.database_subnet_ids : var.public_subnet_ids
  database_url = var.create_database ? format(
    "postgresql://%s:%s@%s:%d/%s",
    urlencode(var.database_master_username),
    urlencode(var.database_master_password),
    aws_rds_cluster.this[0].endpoint,
    var.database_port,
    var.database_name
  ) : var.database_url

  common_environment = [
    {
      name  = "CORRIDOR_SQLALCHEMY_DATABASE_URI"
      value = local.database_url
    },
    {
      name  = "CORRIDOR_LICENSE_KEY"
      value = var.license_key
    },
    {
      name  = "CORRIDOR_CELERY_BROKER_URL"
      value = "redis://localhost:6379/2"
    },
    {
      name  = "CORRIDOR_CELERY_RESULT_BACKEND"
      value = "redis://localhost:6379/2"
    },
    {
      name  = "CORRIDOR_OUTPUT_DATA_LOCATION"
      value = "/opt/corridor/data/results/{}.parquet"
    },
    {
      name  = "CORRIDOR_SANDBOX_MODE"
      value = "true"
    },
    {
      name  = "CORRIDOR_ALLOWED_LOGINS"
      value = "['otp', 'password']"
    },
    {
      name  = "CORRIDOR_NOTIFICATION_PROVIDERS__email__from"
      value = var.smtp_from
    },
    {
      name  = "CORRIDOR_NOTIFICATION_PROVIDERS__email__username"
      value = var.smtp_username
    },
    {
      name  = "CORRIDOR_NOTIFICATION_PROVIDERS__email__password"
      value = var.smtp_password
    },
    {
      name  = "CORRIDOR_NOTIFICATION_PROVIDERS__email__host"
      value = var.smtp_host
    },
    {
      name  = "CORRIDOR_NOTIFICATION_PROVIDERS__email__port"
      value = tostring(var.smtp_port)
    },
    {
      name  = "CORRIDOR_NOTIFICATION_PROVIDERS__email__ssl"
      value = var.smtp_ssl ? "true" : "false"
    },
    {
      name  = "PYSPARK_PYTHON"
      value = "/opt/corridor/venv/bin/python3"
    }
  ]

  migration_command = join("\n", [
    "set -e",
    "mkdir -p /opt/corridor/data /opt/corridor/uploads /opt/corridor/databases",
    "cd /opt/corridor",
    "source venv/bin/activate",
    "echo \"Starting database upgrade...\"",
    "/opt/corridor/venv/bin/corridor-api db upgrade",
    "mv /opt/corridor/corridor*.db* /opt/corridor/databases/ || true",
  ])

  app_command = join("\n", [
    "set -e",
    "mkdir -p /opt/corridor/data /opt/corridor/uploads /opt/corridor/databases",
    "cd /opt/corridor",
    "source venv/bin/activate",
    "echo \"Starting corridor-api...\"",
    "exec venv/bin/corridor-api run",
  ])

  worker_command = join("\n", [
    "set -e",
    "mkdir -p /opt/corridor/data /opt/corridor/uploads /opt/corridor/databases",
    "cd /opt/corridor",
    "source venv/bin/activate",
    "sleep 10",
    "echo \"Starting corridor-worker...\"",
    "exec venv/bin/corridor-worker run",
  ])

  jupyter_command = join("\n", [
    "set -e",
    "mkdir -p /opt/corridor/data /opt/corridor/uploads /opt/corridor/notebooks /opt/corridor/jupyter /opt/corridor/pids",
    "cd /opt/corridor",
    "source venv/bin/activate",
    "echo \"Starting corridor-jupyter...\"",
    "exec venv/bin/corridor-jupyter run",
  ])

  log_options = {
    awslogs-group         = aws_cloudwatch_log_group.this.name
    awslogs-region        = var.region
    awslogs-stream-prefix = var.name
  }

  app_mount_points = [
    {
      sourceVolume  = "data-volume"
      containerPath = "/opt/corridor/data"
      readOnly      = false
    },
    {
      sourceVolume  = "uploads-volume"
      containerPath = "/opt/corridor/uploads"
      readOnly      = false
    },
    {
      sourceVolume  = "databases-volume"
      containerPath = "/opt/corridor/databases"
      readOnly      = false
    }
  ]

  worker_mount_points = local.app_mount_points

  jupyter_mount_points = [
    {
      sourceVolume  = "data-volume"
      containerPath = "/opt/corridor/data"
      readOnly      = false
    },
    {
      sourceVolume  = "uploads-volume"
      containerPath = "/opt/corridor/uploads"
      readOnly      = false
    },
    {
      sourceVolume  = "jupyter-volume"
      containerPath = "/opt/corridor/jupyter"
      readOnly      = false
    },
    {
      sourceVolume  = "notebooks-volume"
      containerPath = "/opt/corridor/notebooks"
      readOnly      = false
    }
  ]

  container_definitions = jsonencode([
    {
      name        = "corridor-migration"
      image       = var.image
      essential   = false
      cpu         = 256
      memory      = 1024
      command     = ["/bin/bash", "-ec", local.migration_command]
      environment = local.common_environment
      mountPoints = local.app_mount_points
      logConfiguration = {
        logDriver = "awslogs"
        options   = merge(local.log_options, { awslogs-stream-prefix = "migration" })
      }
    },
    {
      name      = "redis"
      image     = "public.ecr.aws/docker/library/redis:7.2-alpine"
      essential = true
      cpu       = 128
      memory    = 256
      command   = ["redis-server", "--databases", "32"]
      portMappings = [
        {
          containerPort = 6379
          hostPort      = 6379
          protocol      = "tcp"
        }
      ]
      dependsOn = [
        {
          containerName = "corridor-migration"
          condition     = "SUCCESS"
        }
      ]
      healthCheck = {
        command     = ["CMD-SHELL", "redis-cli ping || exit 1"]
        interval    = 10
        timeout     = 5
        retries     = 3
        startPeriod = 30
      }
      logConfiguration = {
        logDriver = "awslogs"
        options   = merge(local.log_options, { awslogs-stream-prefix = "redis" })
      }
    },
    {
      name        = "corridor-app"
      image       = var.image
      essential   = true
      cpu         = 512
      memory      = 3072
      command     = ["/bin/bash", "-ec", local.app_command]
      environment = local.common_environment
      mountPoints = local.app_mount_points
      portMappings = [
        {
          containerPort = 5002
          hostPort      = 5002
          protocol      = "tcp"
        }
      ]
      dependsOn = [
        {
          containerName = "corridor-migration"
          condition     = "SUCCESS"
        },
        {
          containerName = "redis"
          condition     = "HEALTHY"
        }
      ]
      healthCheck = {
        command     = ["CMD-SHELL", "curl -f http://localhost:5002/api || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 90
      }
      logConfiguration = {
        logDriver = "awslogs"
        options   = merge(local.log_options, { awslogs-stream-prefix = "app" })
      }
    },
    {
      name        = "corridor-worker"
      image       = var.image
      essential   = false
      cpu         = 512
      memory      = 4096
      command     = ["/bin/bash", "-ec", local.worker_command]
      environment = local.common_environment
      mountPoints = local.worker_mount_points
      dependsOn = [
        {
          containerName = "corridor-migration"
          condition     = "SUCCESS"
        },
        {
          containerName = "redis"
          condition     = "HEALTHY"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options   = merge(local.log_options, { awslogs-stream-prefix = "worker" })
      }
    },
    {
      name        = "corridor-jupyter"
      image       = var.image
      essential   = false
      cpu         = 512
      memory      = 4096
      command     = ["/bin/bash", "-ec", local.jupyter_command]
      environment = local.common_environment
      mountPoints = local.jupyter_mount_points
      portMappings = [
        {
          containerPort = 5003
          hostPort      = 5003
          protocol      = "tcp"
        }
      ]
      dependsOn = [
        {
          containerName = "corridor-migration"
          condition     = "SUCCESS"
        },
        {
          containerName = "redis"
          condition     = "HEALTHY"
        }
      ]
      healthCheck = {
        command     = ["CMD-SHELL", "curl -f http://localhost:5003/jupyter/hub/health || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 90
      }
      logConfiguration = {
        logDriver = "awslogs"
        options   = merge(local.log_options, { awslogs-stream-prefix = "jupyter" })
      }
    }
  ])
}

resource "aws_cloudwatch_log_group" "this" {
  name              = "/aws/ecs/${var.name}"
  retention_in_days = 14
  tags              = local.tags
}

resource "aws_iam_role" "task_execution" {
  name = "${var.name}-ecs-task-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = local.tags
}

resource "aws_iam_role_policy_attachment" "task_execution" {
  role       = aws_iam_role.task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role" "task" {
  name = "${var.name}-ecs-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = local.tags
}

resource "aws_security_group" "alb" {
  name        = "${var.name}-alb-sg"
  description = "ALB security group for ${var.name}"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = local.tags
}

resource "aws_security_group" "ecs" {
  name        = "${var.name}-ecs-sg"
  description = "ECS security group for ${var.name}"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 5002
    to_port         = 5002
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  ingress {
    from_port       = 5003
    to_port         = 5003
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = local.tags
}

resource "aws_lb" "this" {
  name               = substr("${var.name}-alb", 0, 32)
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = var.public_subnet_ids
  tags               = local.tags
}

resource "aws_lb_target_group" "app" {
  name        = substr("${var.name}-app-tg", 0, 32)
  port        = 5002
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = var.vpc_id

  health_check {
    path                = "/api"
    matcher             = "200-399"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 5
  }

  tags = local.tags
}

resource "aws_lb_target_group" "jupyter" {
  name        = substr("${var.name}-jupyter-tg", 0, 32)
  port        = 5003
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = var.vpc_id

  health_check {
    path                = "/jupyter/hub/health"
    matcher             = "200-399"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 5
  }

  tags = local.tags
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.this.arn
  port              = 443
  protocol          = "HTTPS"
  certificate_arn   = var.certificate_arn
  ssl_policy        = "ELBSecurityPolicy-2016-08"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

resource "aws_lb_listener_rule" "jupyter" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 10

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.jupyter.arn
  }

  condition {
    path_pattern {
      values = ["/jupyter", "/jupyter/*"]
    }
  }
}

resource "aws_ecs_task_definition" "this" {
  family                   = "${var.name}-app"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = tostring(var.task_cpu)
  memory                   = tostring(var.task_memory)
  execution_role_arn       = aws_iam_role.task_execution.arn
  task_role_arn            = aws_iam_role.task.arn
  container_definitions    = local.container_definitions

  ephemeral_storage {
    size_in_gib = var.ephemeral_storage_gib
  }

  volume {
    name = "data-volume"

    efs_volume_configuration {
      file_system_id     = aws_efs_file_system.this.id
      transit_encryption = "ENABLED"

      authorization_config {
        access_point_id = aws_efs_access_point.data.id
        iam             = "ENABLED"
      }
    }
  }

  volume {
    name = "uploads-volume"

    efs_volume_configuration {
      file_system_id     = aws_efs_file_system.this.id
      transit_encryption = "ENABLED"

      authorization_config {
        access_point_id = aws_efs_access_point.uploads.id
        iam             = "ENABLED"
      }
    }
  }

  volume {
    name = "databases-volume"

    efs_volume_configuration {
      file_system_id     = aws_efs_file_system.this.id
      transit_encryption = "ENABLED"

      authorization_config {
        access_point_id = aws_efs_access_point.databases.id
        iam             = "ENABLED"
      }
    }
  }

  volume {
    name = "jupyter-volume"

    efs_volume_configuration {
      file_system_id     = aws_efs_file_system.this.id
      transit_encryption = "ENABLED"

      authorization_config {
        access_point_id = aws_efs_access_point.jupyter.id
        iam             = "ENABLED"
      }
    }
  }

  volume {
    name = "notebooks-volume"

    efs_volume_configuration {
      file_system_id     = aws_efs_file_system.this.id
      transit_encryption = "ENABLED"

      authorization_config {
        access_point_id = aws_efs_access_point.notebooks.id
        iam             = "ENABLED"
      }
    }
  }

  depends_on = [aws_efs_mount_target.this]

  lifecycle {
    precondition {
      condition     = var.create_database || trimspace(var.database_url) != ""
      error_message = "database_url must be set when create_database is false."
    }
  }

  tags = local.tags
}

resource "aws_ecs_service" "this" {
  name                   = "${var.name}-app-service"
  cluster                = data.aws_ecs_cluster.existing.arn
  task_definition        = aws_ecs_task_definition.this.arn
  desired_count          = var.desired_count
  launch_type            = "FARGATE"
  enable_execute_command = true

  network_configuration {
    subnets          = var.public_subnet_ids
    security_groups  = [aws_security_group.ecs.id]
    assign_public_ip = var.assign_public_ip
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.app.arn
    container_name   = "corridor-app"
    container_port   = 5002
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.jupyter.arn
    container_name   = "corridor-jupyter"
    container_port   = 5003
  }

  deployment_minimum_healthy_percent = 100
  deployment_maximum_percent         = 200

  depends_on = [
    aws_lb_listener.https,
    aws_lb_listener_rule.jupyter,
  ]

  tags = local.tags
}
