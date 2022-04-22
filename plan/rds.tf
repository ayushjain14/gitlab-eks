resource "random_string" "db_suffix" {
  length = 4
  special = false
  upper = false
}

resource "random_password" "db_password" {
  length = 12
  special = true
  upper = true
}

resource "aws_db_instance" "gitlab-primary" {

  # Engine options
  engine                              = "postgres"
  engine_version                      = "12.5"

  # Settings
  name                                = "gitlabhq_production"
  identifier                          = "gitlab-primary"

  # Credentials Settings
  username                            = "gitlab"
  password                            = "p${random_password.db_password.result}"

  # DB instance size
  instance_class                      = "db.t3.micro"

  # Storage
  storage_type                        = "gp2"
  allocated_storage                   = 100
  max_allocated_storage               = 200

  # Availability & durability
  multi_az                            = true

  # Connectivity
  db_subnet_group_name                = aws_db_subnet_group.sg.id

  publicly_accessible                 = false
  vpc_security_group_ids              = [aws_security_group.sg.id]
  port                                = var.rds_port

  # Database authentication
  iam_database_authentication_enabled = false 

  # Additional configuration
  parameter_group_name                = "default.postgres12"

  # Backup
  backup_retention_period             = 14
  backup_window                       = "03:00-04:00"
  final_snapshot_identifier           = "gitlab-postgresql-final-snapshot-${random_string.db_suffix.result}" 
  delete_automated_backups            = true
  skip_final_snapshot                 = false

  # Encryption
  storage_encrypted                   = true

  # Maintenance
  auto_minor_version_upgrade          = true
  maintenance_window                  = "Sat:00:00-Sat:02:00"

  # Deletion protection
  deletion_protection                 = false

  tags = {
    Environment = "core"
  }
}

resource "aws_db_instance" "gitlab-replica" {
  count = 2

  # Engine options
  engine                              = "postgres"
  engine_version                      = "12.5"

  # Settings
  name                                = "gitlabhq_production"
  identifier                          = "gitlab-replica-${count.index}"

  replicate_source_db                 = "gitlab-primary"  
  skip_final_snapshot                 = true
  final_snapshot_identifier           = null

  # DB instance size
  instance_class                      = "db.t3.micro"

  # Storage
  storage_type                        = "gp2"
  allocated_storage                   = 100
  max_allocated_storage               = 200

  publicly_accessible                 = false
  vpc_security_group_ids              = [aws_security_group.sg.id]
  port                                = var.rds_port

  # Database authentication
  iam_database_authentication_enabled = false 

  # Additional configuration
  parameter_group_name                = "default.postgres12"

  # Encryption
  storage_encrypted                   = true

  # Deletion protection
  deletion_protection                 = false

  tags = {
    Environment = "core"
  }

  depends_on = [
    aws_db_instance.gitlab-primary
  ]
}

resource "aws_db_subnet_group" "sg" {
  name       = "gitlab"
  subnet_ids = [for s in aws_subnet.private : s.id]

  tags = {
    Environment = "core"
    Name        = "gitlab"
  }
}

resource "aws_security_group" "sg" {
  name        = "gitlab"
  description = "Allow inbound/outbound traffic"
  vpc_id      = aws_vpc.devops.id

  ingress {
    from_port       = var.rds_port
    to_port         = var.rds_port
    protocol        = "tcp"
    cidr_blocks = [for s in aws_subnet.private : s.cidr_block]
  }

  egress {
    from_port       = 0
    to_port         = 65535
    protocol        = "tcp"
    cidr_blocks = [for s in aws_subnet.private : s.cidr_block]
  }

  tags = {
    Environment = "core"
    Name        = "gitlab"
  }
}
