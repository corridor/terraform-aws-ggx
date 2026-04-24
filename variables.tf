variable "region" {
  type    = string
  default = "us-west-2"
}

variable "name" {
  type    = string
  default = "genguardx"
}

variable "cluster_name" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "public_subnet_ids" {
  type    = list(string)
  default = []
}

variable "assign_public_ip" {
  type    = bool
  default = true
}

variable "image" {
  type = string
}

variable "hostname" {
  type = string
}

variable "certificate_arn" {
  type = string
}

variable "database_url" {
  type      = string
  sensitive = true
  default   = ""
}

variable "create_database" {
  type    = bool
  default = false
}

variable "database_subnet_ids" {
  type    = list(string)
  default = []
}

variable "database_name" {
  type    = string
  default = "genguardx"
}

variable "database_port" {
  type    = number
  default = 5432
}

variable "database_engine_version" {
  type    = string
  default = "15.4"
}

variable "database_master_username" {
  type    = string
  default = "genguardx"
}

variable "database_master_password" {
  type      = string
  sensitive = true
  default   = ""
}

variable "database_serverless_min_capacity" {
  type    = number
  default = 0.5
}

variable "database_serverless_max_capacity" {
  type    = number
  default = 4
}

variable "database_backup_retention_period" {
  type    = number
  default = 7
}

variable "database_publicly_accessible" {
  type    = bool
  default = false
}

variable "database_apply_immediately" {
  type    = bool
  default = false
}

variable "database_deletion_protection" {
  type    = bool
  default = false
}

variable "database_skip_final_snapshot" {
  type    = bool
  default = true
}

variable "license_key" {
  type      = string
  sensitive = true
}

variable "smtp_from" {
  type    = string
  default = "GGX Sandbox <admin@genguardx.ai>"
}

variable "smtp_username" {
  type      = string
  sensitive = true
  default   = "admin@genguardx.ai"
}

variable "smtp_password" {
  type      = string
  sensitive = true
  default   = ""
}

variable "smtp_host" {
  type    = string
  default = "smtp.gmail.com"
}

variable "smtp_port" {
  type    = number
  default = 465
}

variable "smtp_ssl" {
  type    = bool
  default = true
}

variable "desired_count" {
  type    = number
  default = 1
}

variable "task_cpu" {
  type    = number
  default = 2048
}

variable "task_memory" {
  type    = number
  default = 12288
}

variable "ephemeral_storage_gib" {
  type    = number
  default = 50
}

variable "data_volume_size_gib" {
  type    = number
  default = 500
}

variable "uploads_volume_size_gib" {
  type    = number
  default = 100
}

variable "databases_volume_size_gib" {
  type    = number
  default = 5
}

variable "jupyter_volume_size_gib" {
  type    = number
  default = 20
}

variable "notebooks_volume_size_gib" {
  type    = number
  default = 20
}

variable "tags" {
  type    = map(string)
  default = {}
}
