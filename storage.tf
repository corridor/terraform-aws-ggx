resource "aws_security_group" "efs" {
  name        = "${var.name}-efs-sg"
  description = "EFS security group for ${var.name}"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 2049
    to_port         = 2049
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = local.tags
}

resource "aws_efs_file_system" "this" {
  creation_token = "${var.name}-efs"
  encrypted      = true
  tags           = local.tags
}

resource "aws_efs_mount_target" "this" {
  for_each = toset(var.public_subnet_ids)

  file_system_id  = aws_efs_file_system.this.id
  subnet_id       = each.value
  security_groups = [aws_security_group.efs.id]
}

resource "aws_efs_access_point" "data" {
  file_system_id = aws_efs_file_system.this.id

  posix_user {
    gid = 33
    uid = 33
  }

  root_directory {
    path = "/opt/corridor/data"

    creation_info {
      owner_gid   = 33
      owner_uid   = 33
      permissions = "0755"
    }
  }

  tags = merge(local.tags, { Purpose = "data" })
}

resource "aws_efs_access_point" "uploads" {
  file_system_id = aws_efs_file_system.this.id

  posix_user {
    gid = 33
    uid = 33
  }

  root_directory {
    path = "/opt/corridor/uploads"

    creation_info {
      owner_gid   = 33
      owner_uid   = 33
      permissions = "0755"
    }
  }

  tags = merge(local.tags, { Purpose = "uploads" })
}

resource "aws_efs_access_point" "databases" {
  file_system_id = aws_efs_file_system.this.id

  posix_user {
    gid = 33
    uid = 33
  }

  root_directory {
    path = "/opt/corridor/databases"

    creation_info {
      owner_gid   = 33
      owner_uid   = 33
      permissions = "0755"
    }
  }

  tags = merge(local.tags, { Purpose = "databases" })
}

resource "aws_efs_access_point" "jupyter" {
  file_system_id = aws_efs_file_system.this.id

  posix_user {
    gid = 33
    uid = 33
  }

  root_directory {
    path = "/opt/corridor/jupyter"

    creation_info {
      owner_gid   = 33
      owner_uid   = 33
      permissions = "0755"
    }
  }

  tags = merge(local.tags, { Purpose = "jupyter" })
}

resource "aws_efs_access_point" "notebooks" {
  file_system_id = aws_efs_file_system.this.id

  posix_user {
    gid = 33
    uid = 33
  }

  root_directory {
    path = "/opt/corridor/notebooks"

    creation_info {
      owner_gid   = 33
      owner_uid   = 33
      permissions = "0755"
    }
  }

  tags = merge(local.tags, { Purpose = "notebooks" })
}

resource "aws_efs_access_point" "kernels" {
  file_system_id = aws_efs_file_system.this.id

  # The API and worker run as root and require owner-only kernel directories.
  posix_user {
    gid = 0
    uid = 0
  }

  root_directory {
    path = "/opt/corridor/kernels"

    creation_info {
      owner_gid   = 0
      owner_uid   = 0
      permissions = "0700"
    }
  }

  tags = merge(local.tags, { Purpose = "kernels" })
}
