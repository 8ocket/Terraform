# prod/db/provider.tf

terraform {
  # (필수) 테라폼 최소 요구 버전을 설정합니다. (GitHub Actions의 1.14.0과 호환됩니다.)
  required_version = ">= 1.0.0"

  required_providers {
    aws = {
      # (필수) 해시코프 공식 AWS 공급자를 사용합니다.
      source  = "hashicorp/aws"
      # (필수) 기존 vpc 폴더와 동일하게 5.x 버전을 사용하여 일관성을 유지합니다.
      version = "~> 5.0"
    }
  }

  # (중요) 테라폼 상태 파일(뇌)을 S3 금고에 안전하게 보관하는 설정입니다.
  backend "s3" {
    # 상태 파일이 저장될 S3 버킷 이름입니다.
    bucket         = "8ocket-tfstate-s3"
    # (핵심) vpc 폴더와 덮어쓰기 충돌이 나지 않도록 db 전용 폴더 경로로 격리했습니다.
    key            = "prod/db/terraform.tfstate"
    # S3 버킷이 위치한 서울 리전입니다.
    region         = "ap-northeast-2"
    # 파일 내용을 알아볼 수 없게 암호화합니다.
    encrypt        = true
    # 동시 수정을 막아주는 DynamoDB 자물쇠 테이블 이름입니다.
    dynamodb_table = "8ocket-tfstate-dynamodb"
  }
}

provider "aws" {
  # 리소스를 생성할 기본 위치를 서울 리전으로 설정합니다.
  region = "ap-northeast-2"

  # (선택) 이 폴더에서 만들어지는 모든 자원에 자동으로 붙는 공통 이름표입니다.
  default_tags {
    tags = {
      # 이 태그 하나로 AWS에서 프로젝트 전체 비용을 추적할 수 있습니다.
      Project = "8ocket"
    }
  }
}