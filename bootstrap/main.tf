# /root/terraform/bootstrap/main.tf

terraform {
  # ==========================================
  # [추가된 부분] 테라폼 상태(tfstate) 파일 원격 저장소 설정
  # ==========================================
  backend "s3" {
    bucket         = "8ocket-tfstate-s3"           # (필수) 방금 우리가 만든 S3 버킷의 이름을 적어줍니다.
    key            = "bootstrap/terraform.tfstate" # (필수) S3 금고 안에서 이 파일이 저장될 폴더 경로와 파일 이름입니다.
    region         = "ap-northeast-2"              # (필수) S3 버킷이 위치한 서울 리전을 명시합니다.
    encrypt        = true                          # (필수) S3에 저장될 때 파일 내용을 암호화하여 보호합니다.
    dynamodb_table = "8ocket-tfstate-dynamodb"     # (필수) 동시 수정을 막기 위해 방금 만든 DynamoDB 자물쇠 테이블 이름을 적어줍니다.
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "ap-northeast-2"
}

# ==========================================
# 1. 테라폼 상태 저장용 S3 버킷 및 암호화
# ==========================================
resource "aws_s3_bucket" "tfstate" {
  bucket = "8ocket-tfstate-s3" # 요청하신 이름 규약 적용
}

resource "aws_s3_bucket_versioning" "tfstate_versioning" {
  bucket = aws_s3_bucket.tfstate.id
  versioning_configuration {
    status = "Enabled"
  }
}

# (중요) tfstate 파일 내부의 민감 정보(비밀번호 등)를 보호하기 위한 AES256 암호화
resource "aws_s3_bucket_server_side_encryption_configuration" "tfstate_encryption" {
  bucket = aws_s3_bucket.tfstate.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# ==========================================
# 2. 테라폼 상태 잠금용 DynamoDB 테이블
# ==========================================
resource "aws_dynamodb_table" "tflock" {
  name         = "8ocket-tfstate-dynamodb"
  billing_mode = "PAY_PER_REQUEST" # (중요) 쓰지 않을 때 요금이 나가지 않는 온디맨드 모드
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
}

# ==========================================
# 3. 도커 이미지 저장용 ECR 창고
# ==========================================
resource "aws_ecr_repository" "app_repo" {
  name                 = "8ocket-app-repo"
  image_tag_mutability = "MUTABLE"

  # (중요) 이미지가 올라올 때 해킹 취약점을 검사합니다. (경고만 해주고 저장을 막지는 않습니다)
  image_scanning_configuration {
    scan_on_push = true
  }
}

# (중요) 최근 30개 이미지만 남기고 나머지는 자동 삭제하는 수명 주기 정책
resource "aws_ecr_lifecycle_policy" "app_repo_policy" {
  repository = aws_ecr_repository.app_repo.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep last 30 images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 30
      }
      action = {
        type = "expire"
      }
    }]
  })
}

# ==========================================
# 4. GitHub Actions 전용 OIDC 출입증 (Terraform 모듈 사용)
# ==========================================
module "github_oidc_provider" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-github-oidc-provider"
  version = "~> 5.0"
}

module "github_actions_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-github-oidc-role"
  version = "~> 5.0"

  name = "8ocket-github-actions-role"

  # (중요) 8ocket 계정의 Terraform 레포지토리 중 'main' 브랜치에서 실행될 때만 AWS 접근을 허용합니다.
  subjects = ["repo:8ocket/Terraform:ref:refs/heads/main"]

  policies = {
    AdministratorAccess = "arn:aws:iam::aws:policy/AdministratorAccess"
  }
}