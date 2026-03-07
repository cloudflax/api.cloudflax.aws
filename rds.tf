# ---------- IP pública del desarrollador (dinámica) ----------

data "http" "my_ip" {
  url = "https://checkip.amazonaws.com"
}

locals {
  my_public_ip = "${trimspace(data.http.my_ip.response_body)}/32"
}

# ---------- VPC y Security Group ----------

data "aws_vpc" "default" {
  default = true
}

data "aws_security_group" "default" {
  vpc_id = data.aws_vpc.default.id
  name   = "default"
}

resource "aws_security_group" "rds_dev_access" {
  name        = "cloudflax-${var.environment}-rds-dev-access"
  description = "Allow developer IP to access RDS on port 5432"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [local.my_public_ip]
    description = "PostgreSQL from developer IP"
  }
}

# ---------- RDS Instance ----------

resource "aws_db_instance" "rds_instance" {
  identifier             = "cloudflax-${var.environment}-rds"
  engine                 = "postgres"
  engine_version         = "17.4"
  instance_class         = "db.t3.micro"
  allocated_storage      = 20
  db_name                = "cloudflax"
  username               = var.db_username
  password               = var.db_password
  skip_final_snapshot    = true
  publicly_accessible    = true
  vpc_security_group_ids = [data.aws_security_group.default.id, aws_security_group.rds_dev_access.id]
}
