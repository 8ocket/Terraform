# /root/terraform/bootstrap/main.tf

terraform {
  # ==========================================
  # 테라폼 상태(tfstate) 파일 원격 저장소 설정
  # ==========================================
  backend "s3" {
    bucket         = "8ocket-tfstate-s3"           # 상태 파일이 저장될 S3 버킷
    key            = "bootstrap/terraform.tfstate" # 파일 경로 및 이름
    region         = "ap-northeast-2"              # 리전 설정
    encrypt        = true                          # 암호화 활성화
    dynamodb_table = "8ocket-tfstate-dynamodb"     # 잠금용 DynamoDB 테이블
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
  bucket = "8ocket-tfstate-s3"
}

resource "aws_s3_bucket_versioning" "tfstate_versioning" {
  bucket = aws_s3_bucket.tfstate.id
  versioning_configuration {
    status = "Enabled"
  }
}

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
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
}

# ==========================================
# 3. 도커 이미지 저장용 ECR 창고
# ==========================================
locals {
  ecr_repos = ["mindlog-fe", "mindlog-be", "mindlog-ai"]
}

resource "aws_ecr_repository" "app_repo" {
  for_each             = toset(local.ecr_repos)
  name                 = each.key
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_lifecycle_policy" "app_repo_policy" {
  for_each   = aws_ecr_repository.app_repo
  repository = each.value.name

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
# 4. GitHub Actions 전용 OIDC 출입증 (수동 리소스 방식)
# ==========================================

# (중요) 깃허브 OIDC 공급자 설정은 기존 모듈을 유지하거나 아래처럼 직접 정의할 수 있습니다.
resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
  
  # (핵심 수정) 깃허브의 최신 지문 2개를 모두 넣어서 인증 실패를 원천 차단합니다.
  # AWS가 최근 지문을 자동 관리하지만, 수동 리소스에서는 명시하는 것이 가장 확실합니다.
  thumbprint_list = [
    "6938fd4d98bab03faadb97b34396831e3780aea1", 
    "1c58a3a8518e8759bf075b76b750d4f2df264fcd"
  ]
}

data "aws_iam_policy_document" "github_allow" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity", "sts:TagSession"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      
      # (핵심 해결책) 깃허브가 보내는 '환경(approve)' 신분증을 명부에 추가합니다!
      values   = [
        "repo:8ocket/Terraform:environment:approve",
        "repo:8ocket/terraform:environment:approve",
        # (유지) 만약 환경 설정을 빼고 돌릴 때를 대비해 기존 main 브랜치 값도 남겨둡니다.
        "repo:8ocket/Terraform:ref:refs/heads/main",
        "repo:8ocket/terraform:ref:refs/heads/main"
      ]
    }
  }
}

# IAM 역할 생성
resource "aws_iam_role" "github_actions_role" {
  name               = "8ocket-github-actions-role"
  assume_role_policy = data.aws_iam_policy_document.github_allow.json
}

# 관리자 권한 연결
resource "aws_iam_role_policy_attachment" "admin_attach" {
  role       = aws_iam_role.github_actions_role.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}