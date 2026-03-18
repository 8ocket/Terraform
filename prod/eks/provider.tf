# prod/eks/provider.tf

terraform {
  # 테라폼 최소 요구 버전
  required_version = ">= 1.0.0"

  # 인프라(EKS 뼈대)만 생성하므로 오직 AWS 통역사 하나만 호출합니다.
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # EKS 전용 S3 상태 파일 저장 경로로 완벽히 격리합니다.
  backend "s3" {
    bucket         = "8ocket-tfstate-s3"
    key            = "prod/eks/terraform.tfstate"
    region         = "ap-northeast-2"
    encrypt        = true
    dynamodb_table = "8ocket-tfstate-dynamodb"
  }
}

# 1. AWS 통역사 설정
provider "aws" {
  region = "ap-northeast-2"

  default_tags {
    tags = {
      Project = "8ocket"
    }
  }
}