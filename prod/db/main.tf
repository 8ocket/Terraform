# prod/db/main.tf
resource "aws_kms_key" "db_key" {
  description             = "KMS key for RDS and Valkey encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true # 매년 자동으로 키를 바꿔주는 보안 설정
}

resource "aws_kms_alias" "db_key_alias" {
  name          = "alias/${var.env}-db-key"
  target_key_id = aws_kms_key.db_key.key_id
}

# ==========================================
# (추가) RDS TLS(SSL) 강제 통신을 위한 커스텀 파라미터 그룹
# ==========================================
resource "aws_db_parameter_group" "rds_postgres" {
  name   = "rds-params-${var.env}-8ocket"
  family = "postgres18" # 아래 RDS 모듈의 family 버전에 맞춥니다.

  parameter {
    name  = "rds.force_ssl"
    value = "1" # 1로 설정 시 평문 통신을 거부하고 TLS 암호화 통신만 허용
  }
}

# ==========================================
# 1. RDS PostgreSQL (공식 모듈 사용)
# ==========================================
module "db" {
  source  = "terraform-aws-modules/rds/aws"
  version = "~> 6.0"

  identifier = "rds-${var.env}-8ocket" 

  engine               = "postgres"
  engine_version       = var.db_engine_version
  family               = "postgres18" # 엔진 버전에 맞는 기본 파라미터 그룹 패밀리
  major_engine_version = "18"
  instance_class       = var.db_instance_class

  allocated_storage = var.db_allocated_storage
  storage_type      = "gp3"

  db_name  = var.db_name
  username = var.db_user
  password = var.db_password
  port     = 5432

  manage_master_user_password = false

  multi_az = false

  db_subnet_group_name   = data.terraform_remote_state.vpc.outputs.database_subnet_group_name
  vpc_security_group_ids = [data.terraform_remote_state.vpc.outputs.db_sg_id]

  deletion_protection = false
  skip_final_snapshot = true

  kms_key_id = aws_kms_key.db_key.arn
  # kms key 사용하여 rds 에 쓰기작업
  # (수정) 파라미터 커스텀 블록을 제거하여 AWS 기본값을 사용하도록 반영했습니다.
  
  # ==========================================
  # (추가) 위에서 생성한 커스텀 파라미터 그룹을 RDS에 연결합니다.
  # ==========================================
  parameter_group_name = aws_db_parameter_group.rds_postgres.name
}

# ==========================================
# 2. Valkey (ElastiCache 기본 리소스 사용)
# ==========================================
resource "aws_elasticache_subnet_group" "valkey" {
  name       = "valkey-subnet-group-${var.env}-8ocket"
  subnet_ids = data.terraform_remote_state.vpc.outputs.database_subnets
}

# (수정) 파라미터 그룹도 최소한의 클러스터 모드 Off 설정만 남기고 기본값을 따릅니다.
resource "aws_elasticache_parameter_group" "valkey" {
  name   = "valkey-params-${var.env}-8ocket"
  family = "valkey8" 

  parameter {
    name  = "cluster-enabled"
    value = "no" 
  }
}

resource "aws_elasticache_replication_group" "valkey" {
  replication_group_id = "valkey-${var.env}-8ocket"
  description          = "Valkey 8.2 single node for 8ocket project"
  
  engine               = "valkey"
  engine_version       = var.redis_engine_version
  node_type            = var.redis_node_type
  port                 = 6379

  num_cache_clusters         = 1
  automatic_failover_enabled = false

  parameter_group_name = aws_elasticache_parameter_group.valkey.name
  subnet_group_name    = aws_elasticache_subnet_group.valkey.name
  
  # (필수) 이 보안 그룹이 있어야 EKS 파드가 Redis에 접속할 수 있습니다.
  security_group_ids   = [data.terraform_remote_state.vpc.outputs.db_sg_id]

  at_rest_encryption_enabled = true
  # (수정) 본 서버 구축을 대비하여 데이터 전송 구간 암호화를 미리 켜둡니다.
  transit_encryption_enabled = true 

  kms_key_id = aws_kms_key.db_key.arn
  #kms 키 사용하여 db 에 쓰기
}

# ----------------------------------------------------------
# 3.사진 저장용 s3

resource "aws_s3_bucket" "backend_photos" {
  bucket        = var.s3_photo_bucket_name
  
  # 버킷 내부에 사진 데이터가 존재하더라도 terraform destroy 시 강제로 모두 삭제합니다.
  force_destroy = true 
}

resource "aws_s3_bucket_versioning" "backend_photos" {
  bucket = aws_s3_bucket.backend_photos.id
  versioning_configuration {
    status = "Enabled"
  }
}


resource "aws_s3_bucket_public_access_block" "backend_photos_public" {
  bucket                  = aws_s3_bucket.backend_photos.id
  block_public_acls       = false
  ignore_public_acls      = false
  block_public_policy     = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "backend_photos_public_read" {
  bucket     = aws_s3_bucket.backend_photos.id
  depends_on = [aws_s3_bucket_public_access_block.backend_photos_public]

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Principal = "*"
        Effect    = "Allow"
        Action    = ["s3:GetObject"]
        Resource  = ["${aws_s3_bucket.backend_photos.arn}/*"]
      }
    ]
  })
}

# =======================================================
# RDS(PostgreSQL)용 인바운드 규칙
resource "aws_security_group_rule" "db_allow_eks_postgres" {
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  security_group_id        = data.terraform_remote_state.vpc.outputs.db_sg_id
  source_security_group_id = data.terraform_remote_state.eks.outputs.node_security_group_id
}

# ==========================================
# Redis용 인바운드 규칙
resource "aws_security_group_rule" "db_allow_eks_redis" {
  type                     = "ingress"
  from_port                = 6379
  to_port                  = 6379
  protocol                 = "tcp"
  security_group_id        = data.terraform_remote_state.vpc.outputs.db_sg_id
  source_security_group_id = data.terraform_remote_state.eks.outputs.node_security_group_id
}