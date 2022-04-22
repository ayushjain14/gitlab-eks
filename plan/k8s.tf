resource "kubernetes_namespace" "gitlab" {
  metadata {
    name = "gitlab"
  }
}

resource "kubernetes_service_account" "gitlab" {
  metadata {
    name      = "aws-access"
    namespace = "gitlab"

    labels = {
      "app.kubernetes.io/name" = "aws-access"
    }
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.gitlab-access.arn
    }
  }
}

data "template_file" "gitlab-values" {
  template = <<EOF

# Values for gitlab/gitlab chart on EKS
global:
  serviceAccount:
    enabled: true
    create: false
    name: aws-access
  platform:
    eksRoleArn: ${aws_iam_role.gitlab-access.arn}

  nodeSelector:
    eks.amazonaws.com/nodegroup: private
    
  shell:
    authToken:
      secret: ${kubernetes_secret.shell-secret.metadata.0.name}
      key: password
  edition: ce

  hosts:
    domain: ${var.public_dns_name}
    https: true
    gitlab:
      name: gitlab.${var.public_dns_name}
      https: true
    ssh: ~

  ## doc/charts/globals.md#configure-ingress-settings
  ingress:
    tls:
      enabled: false
 
  ## doc/charts/globals.md#configure-postgresql-settings
  psql:
    password:
       secret: ${kubernetes_secret.gitlab-postgres.metadata.0.name}
       key: psql-password
    host: ${aws_db_instance.gitlab-primary.address}
    port: ${var.rds_port}
    username: gitlab
    database: gitlabhq_production

  redis:
    password:
      enabled: false
    host: ${aws_elasticache_cluster.gitlab.cache_nodes[0].address}

  ## doc/charts/globals.md#configure-minio-settings
  minio:
    enabled: false

  ## doc/charts/globals.md#configure-appconfig-settings
  ## Rails based portions of this chart share many settings
  appConfig:
    ## doc/charts/globals.md#general-application-settings
    enableUsagePing: false

    ## doc/charts/globals.md#lfs-artifacts-uploads-packages
    backups:
      bucket: ${aws_s3_bucket.gitlab-backups.id}
    lfs:
      bucket: ${aws_s3_bucket.git-lfs.id}
      connection:
        secret: ${kubernetes_secret.s3-storage-credentials.metadata.0.name}
        key: connection
    artifacts:
      bucket: ${aws_s3_bucket.gitlab-artifacts.id}
      connection:
        secret: ${kubernetes_secret.s3-storage-credentials.metadata.0.name}
        key: connection
    uploads:
      bucket: ${aws_s3_bucket.gitlab-uploads.id}
      connection:
        secret: ${kubernetes_secret.s3-storage-credentials.metadata.0.name}
        key: connection
    packages:
      bucket: ${aws_s3_bucket.gitlab-packages.id}
      connection:
        secret: ${kubernetes_secret.s3-storage-credentials.metadata.0.name}
        key: connection
    ## doc/charts/globals.md#pseudonymizer-settings
    pseudonymizer:
      bucket: ${aws_s3_bucket.gitlab-pseudo.id}
      connection:
        secret: ${kubernetes_secret.s3-storage-credentials.metadata.0.name}
        key: connection
nginx-ingress:
  controller:
    config:
        use-forwarded-headers: "true" 
    service:
        annotations:
            service.beta.kubernetes.io/aws-load-balancer-backend-protocol: http
            service.beta.kubernetes.io/aws-load-balancer-connection-idle-timeout: "3600"
            service.beta.kubernetes.io/aws-load-balancer-ssl-cert: ${var.acm_gitlab_arn}
            service.beta.kubernetes.io/aws-load-balancer-ssl-ports: https
        targetPorts:
            https: http # the ELB will send HTTP to 443

certmanager-issuer:
  email: ${var.certmanager_issuer_email}

prometheus:
  install: false

redis:
  install: false

# https://docs.gitlab.com/ee/ci/runners/#configuring-runners-in-gitlab
gitlab-runner:
  install: false

gitlab:
  gitaly:
    persistence:
      volumeName: ${kubernetes_persistent_volume_claim.gitaly.metadata.0.name}
    nodeSelector:
      topology.kubernetes.io/zone: ${var.az[0]}
  task-runner:
    backups:
      objectStorage:
        backend: s3
        config:
          secret: ${kubernetes_secret.s3-storage-credentials.metadata.0.name}
          key: connection
    annotations:
      eks.amazonaws.com/role-arn: ${aws_iam_role.gitlab-access.arn}
  webservice:
    annotations:
      eks.amazonaws.com/role-arn: ${aws_iam_role.gitlab-access.arn}
  sidekiq:
    annotations:
      eks.amazonaws.com/role-arn: ${aws_iam_role.gitlab-access.arn}
  migrations:
    # Migrations pod must point directly to PostgreSQL primary
    psql:
      password:
        secret: ${kubernetes_secret.gitlab-postgres.metadata.0.name}
        key: psql-password
      host: ${aws_db_instance.gitlab-primary.address}
      port: ${var.rds_port}

postgresql:
  install: false

gitlab-runner:
  install: true
  rbac:
    create: true
  runners:
    locked: false

registry:
  enabled: true
  annotations:
    eks.amazonaws.com/role-arn: aws_iam_role.gitlab-access.arn
  storage:
    secret: ${kubernetes_secret.s3-registry-storage-credentials.metadata.0.name}
    key: config

EOF
}

resource "helm_release" "gitlab" {
  name       = "gitlab"
  namespace  = "gitlab"
  timeout    = 600

  chart      = "gitlab/gitlab"
  values     = [data.template_file.gitlab-values.rendered]

  depends_on = [
      aws_eks_node_group.private,
      aws_eks_node_group.public,
      aws_db_instance.gitlab-primary,
      aws_elasticache_cluster.gitlab,
      aws_iam_role_policy.gitlab-access,
      kubernetes_namespace.gitlab,
      kubernetes_secret.gitlab-postgres,
      kubernetes_secret.s3-storage-credentials,
      kubernetes_secret.s3-registry-storage-credentials,
      kubernetes_persistent_volume_claim.gitaly
  ]
}

    # load_balancing:
    #   hosts:
    #   - ${aws_db_instance.gitlab-replica[0].address}
    #   - ${aws_db_instance.gitlab-replica[1].address}

# aws_db_instance.gitlab-replica,

data "kubernetes_service" "gitlab-webservice" {
  metadata {
    name      = "gitlab-nginx-ingress-controller"
    namespace = "gitlab"
  }
  
  depends_on = [
    helm_release.gitlab
  ]
}

resource "kubernetes_secret" "gitlab-postgres" {
  metadata {
    name       = "gitlab-postgres"
    namespace  = "gitlab"
  }

  data = {
   psql-password = "p${random_password.db_password.result}"
  }
}

resource "kubernetes_secret" "s3-storage-credentials" {
  metadata {
    name       = "s3-storage-credentials"
    namespace  = "gitlab"
  }

  data = {
    connection = data.template_file.rails-s3-yaml.rendered
  }
}

data "template_file" "rails-s3-yaml" {
  template = <<EOF
provider: AWS
region: ${var.region}

EOF
}

resource "kubernetes_secret" "s3-registry-storage-credentials" {
  metadata {
    name       = "s3-registry-storage-credentials"
    namespace  = "gitlab"
  }

  data = {
    config = data.template_file.registry-s3-yaml.rendered
  }
}

data "template_file" "registry-s3-yaml" {
  template = <<EOF
s3:
    bucket: ${aws_s3_bucket.gitlab-registry.id}
    region: ${var.region}
    v4auth: true
EOF
}

resource "random_password" "shell-secret" {
  length = 12
  special = true
  upper = true
}

resource "kubernetes_secret" "shell-secret" {
  metadata {
    name       = "shell-secret"
    namespace  = "gitlab"
  }

  data = {
    password = random_password.shell-secret.result
  }
}

resource "kubernetes_persistent_volume" "gitaly" {
  metadata {
    name      = "gitaly-pv"
  }
  spec {
    capacity = {
      storage = "50Gi"
    }
    access_modes = ["ReadWriteOnce"]
    storage_class_name = "ebs-gp2"
    persistent_volume_source {
        aws_elastic_block_store {
            fs_type   = "ext4"
            volume_id = aws_ebs_volume.gitaly.id
        }
    }
  }
}

resource "kubernetes_persistent_volume_claim" "gitaly" {
  metadata {
    name      = "repo-data-gitlab-gitaly-0"
    namespace = "gitlab"
  }
  spec {
    access_modes = ["ReadWriteOnce"]
    storage_class_name = "ebs-gp2"
    resources {
      requests = {
        storage = "50Gi"
      }
    }
    volume_name = kubernetes_persistent_volume.gitaly.metadata.0.name
  }
}

resource "kubernetes_storage_class" "gitaly" {
  metadata {
    name = "ebs-gp2"
  }
  storage_provisioner = "kubernetes.io/aws-ebs"
  reclaim_policy      = "Retain"

  parameters = {
    type = "gp2"
  }

  allowed_topologies {
    match_label_expressions {
      key = "failure-domain.beta.kubernetes.io/zone"
      values = var.az
    }
  }
}
