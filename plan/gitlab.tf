resource "aws_iam_role" "gitlab-access" {
  name = "gitlab-access"

  assume_role_policy = jsonencode({
        "Version": "2012-10-17",
        "Statement": [
            {
                "Effect": "Allow",
                "Principal": {
                    "Federated": aws_iam_openid_connect_provider.openid.arn
                },
                "Action": "sts:AssumeRoleWithWebIdentity",
                "Condition": {
                    "StringEquals": {
                        "${replace(aws_iam_openid_connect_provider.openid.url, "https://", "")}:sub": "system:serviceaccount:gitlab:aws-access"
                    }
                }
            }
        ]
    })
}

resource "aws_iam_role_policy" "gitlab-access" {
  name = "gitlab-access"
  role = aws_iam_role.gitlab-access.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
            "s3:ListBucket",
            "s3:GetBucketLocation",
            "s3:ListBucketMultipartUploads"
        ]
        Effect   = "Allow"
        Resource = [
            aws_s3_bucket.gitlab-backups.arn,
            aws_s3_bucket.gitlab-registry.arn,
            aws_s3_bucket.gitlab-runner-cache.arn,
            aws_s3_bucket.gitlab-pseudo.arn,
            aws_s3_bucket.git-lfs.arn,
            aws_s3_bucket.gitlab-artifacts.arn,
            aws_s3_bucket.gitlab-uploads.arn,
            aws_s3_bucket.gitlab-packages.arn
        ]
      },
      {
        Action = [
            "s3:PutObject",
            "s3:GetObject",
            "s3:DeleteObject",
            "s3:ListMultipartUploadParts",
            "s3:AbortMultipartUpload"
        ]
        Effect   = "Allow"
        Resource = [
            "${aws_s3_bucket.gitlab-backups.arn}/*",
            "${aws_s3_bucket.gitlab-registry.arn}/*",
            "${aws_s3_bucket.gitlab-runner-cache.arn}/*",
            "${aws_s3_bucket.gitlab-pseudo.arn}/*",
            "${aws_s3_bucket.git-lfs.arn}/*",
            "${aws_s3_bucket.gitlab-artifacts.arn}/*",
            "${aws_s3_bucket.gitlab-uploads.arn}/*",
            "${aws_s3_bucket.gitlab-packages.arn}/*"
        ]
      }
    ]
  })
}

resource "aws_route53_record" "gitlab" {
 zone_id    = data.aws_route53_zone.public.zone_id
 name       = "gitlab.${var.public_dns_name}"
 type       = "CNAME"
 ttl        = "300"
 records    = [data.kubernetes_service.gitlab-webservice.status.0.load_balancer.0.ingress.0.hostname]

 depends_on = [
   helm_release.gitlab,
   data.kubernetes_service.gitlab-webservice
 ]
}

resource "aws_s3_bucket" "gitlab-registry" {
  bucket = "${data.aws_caller_identity.current.account_id}-${var.region}-gitlab-registry"
  acl    = "private"

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm     = "AES256"
      }
    }
  }

  tags = {
    Name        = "Gitlab Registry"
    Environment = "core"
  }
}

resource "aws_s3_bucket" "gitlab-runner-cache" {
  bucket = "${data.aws_caller_identity.current.account_id}-${var.region}-runner-cache"
  acl    = "private"

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm     = "AES256"
      }
    }
  }

  tags = {
    Name        = "Gitlab Runner Cache"
    Environment = "core"
  }
}

resource "aws_s3_bucket" "gitlab-backups" {
  bucket = "${data.aws_caller_identity.current.account_id}-${var.region}-gitlab-backups"
  acl    = "private"

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm     = "AES256"
      }
    }
  }

  tags = {
    Name        = "Gitlab Backups"
    Environment = "core"
  }
}

resource "aws_s3_bucket" "gitlab-pseudo" {
  bucket = "${data.aws_caller_identity.current.account_id}-${var.region}-gitlab-pseudo"
  acl    = "private"

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm     = "AES256"
      }
    }
  }

  tags = {
    Name        = "Gitlab Pseudo"
    Environment = "core"
  }
}

resource "aws_s3_bucket" "git-lfs" {
  bucket = "${data.aws_caller_identity.current.account_id}-${var.region}-git-lfs"
  acl    = "private"

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm     = "AES256"
      }
    }
  }

  tags = {
    Name        = "Git Large File Storage"
    Environment = "core"
  }
}

resource "aws_s3_bucket" "gitlab-artifacts" {
  bucket = "${data.aws_caller_identity.current.account_id}-${var.region}-gitlab-artifacts"
  acl    = "private"

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm     = "AES256"
      }
    }
  }

  tags = {
    Name        = "Gitlab Artifacts"
    Environment = "core"
  }
}

resource "aws_s3_bucket" "gitlab-uploads" {
  bucket = "${data.aws_caller_identity.current.account_id}-${var.region}-gitlab-uploads"
  acl    = "private"

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm     = "AES256"
      }
    }
  }

  tags = {
    Name        = "Gitlab Uploads"
    Environment = "core"
  }
}

resource "aws_s3_bucket" "gitlab-packages" {
  bucket = "${data.aws_caller_identity.current.account_id}-${var.region}-gitlab-packages"
  acl    = "private"

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm     = "AES256"
      }
    }
  }

  tags = {
    Name        = "Gitlab Packages"
    Environment = "core"
  }
}

resource "aws_ebs_volume" "gitaly" {
  availability_zone = var.az[0]
  size              = 100
  type              = "gp2"

  tags = {
    Name = "gitaly"
  }
}