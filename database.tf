resource "aws_security_group" "database" {
  count = var.create_database ? 1 : 0

  name        = "${var.name}-db-sg"
  description = "Database security group for ${var.name}"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = var.database_port
    to_port         = var.database_port
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.tags, { Purpose = "database" })
}

resource "aws_db_subnet_group" "this" {
  count = var.create_database ? 1 : 0

  name       = "${var.name}-db-subnets"
  subnet_ids = local.database_subnet_ids

  tags = merge(local.tags, { Purpose = "database" })
}

resource "aws_rds_cluster" "this" {
  count = var.create_database ? 1 : 0

  cluster_identifier      = "${var.name}-aurora"
  engine                  = "aurora-postgresql"
  engine_mode             = "provisioned"
  engine_version          = var.database_engine_version
  database_name           = var.database_name
  master_username         = var.database_master_username
  master_password         = var.database_master_password
  port                    = var.database_port
  db_subnet_group_name    = aws_db_subnet_group.this[0].name
  vpc_security_group_ids  = [aws_security_group.database[0].id]
  backup_retention_period = var.database_backup_retention_period
  storage_encrypted       = true
  skip_final_snapshot     = var.database_skip_final_snapshot
  deletion_protection     = var.database_deletion_protection
  apply_immediately       = var.database_apply_immediately
  copy_tags_to_snapshot   = true

  serverlessv2_scaling_configuration {
    min_capacity = var.database_serverless_min_capacity
    max_capacity = var.database_serverless_max_capacity
  }

  lifecycle {
    precondition {
      condition     = trimspace(var.database_master_username) != ""
      error_message = "database_master_username must be set when create_database is true."
    }

    precondition {
      condition     = trimspace(var.database_master_password) != ""
      error_message = "database_master_password must be set when create_database is true."
    }

    precondition {
      condition     = length(local.database_subnet_ids) >= 2
      error_message = "database_subnet_ids or public_subnet_ids must contain at least two subnets when create_database is true."
    }
  }

  tags = merge(local.tags, { Purpose = "database" })
}

resource "aws_rds_cluster_instance" "this" {
  count = var.create_database ? 1 : 0

  identifier           = "${var.name}-aurora-1"
  cluster_identifier   = aws_rds_cluster.this[0].id
  instance_class       = "db.serverless"
  engine               = aws_rds_cluster.this[0].engine
  engine_version       = aws_rds_cluster.this[0].engine_version
  db_subnet_group_name = aws_db_subnet_group.this[0].name
  publicly_accessible  = var.database_publicly_accessible

  tags = merge(local.tags, { Purpose = "database" })
}
