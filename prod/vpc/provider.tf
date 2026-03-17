# prod/vpc/provider.tf

terraform {
  # 테라폼 최소 요구 버전 설정
  required_version = ">= 1.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      # 약속한 AWS Provider 버전
      version = "~> 5.0"
    }
  }

  # (중요) 상태 파일을 로컬이 아닌 S3에 안전하게 보관하는 설정
  backend "s3" {
    bucket         = "8ocket-tfstate-s3"
    # (중요) vpc 전용 상태 파일이 저장될 폴더와 파일 이름
    key            = "prod/vpc/terraform.tfstate"
    region         = "ap-northeast-2"
    encrypt        = true
    dynamodb_table = "8ocket-tfstate-dynamodb"
  }
}

provider "aws" {
  region = "ap-northeast-2"

  # (중요) 이 폴더에서 만들어지는 모든 자원에 자동으로 붙는 공통 이름표
  default_tags {
    tags = {
      Project = "8ocket"
    }
  }
}