resource "aws_elasticache_cluster" "gitlab" {
  cluster_id           = "cluster-gitlab"
  engine               = "redis"
  node_type            = "cache.t3.micro"
  num_cache_nodes      = 1
  parameter_group_name = "default.redis3.2"
  engine_version       = "3.2.10"
  port                 = 6379
  subnet_group_name    = aws_elasticache_subnet_group.gitlab.name
  security_group_ids   = [aws_security_group.redis.id]
}

resource "aws_elasticache_subnet_group" "gitlab" {
  name       = "gitlab-cache-subnet"
  subnet_ids = [for s in aws_subnet.private : s.id]
}

resource "aws_security_group" "redis" {
  name        = "ElasticacheRedisSecurityGroup"
  description = "Communication between the redis and eks worker nodegroups"
  vpc_id      = aws_vpc.devops.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "ElasticacheRedisSecurityGroup"
  }
}

resource "aws_security_group_rule" "redis_inbound" {
  description              = "Allow eks nodes to communicate with Redis"
  from_port                = 6379
  protocol                 = "tcp"
  security_group_id        = aws_security_group.redis.id
  source_security_group_id = aws_eks_cluster.devops.vpc_config[0].cluster_security_group_id
  to_port                  = 6379
  type                     = "ingress"
}
