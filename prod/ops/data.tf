# prod/ops/data.tf

# 1. 현재 테라폼을 실행하고 있는 AWS 계정 번호(Account ID)를 읽어옵니다.
data "aws_caller_identity" "current" {}

# 2. 현재 인프라가 배포되어 있는 AWS 리전 이름(ap-northeast-2 등)을 읽어옵니다.
data "aws_region" "current" {}

# 3. S3 금고에 저장된 VPC 생성 결과(VPC ID, 서브넷 정보 등)를 읽어옵니다.
data "terraform_remote_state" "vpc" {
  backend = "s3"
  config = {
    bucket = "8ocket-tfstate-s3"
    key    = "prod/vpc/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

# 4. S3 금고에 저장된 EKS 생성 결과(클러스터 이름, OIDC 등)를 읽어옵니다.
data "terraform_remote_state" "eks" {
  backend = "s3"
  config = {
    bucket = "8ocket-tfstate-s3"
    key    = "prod/eks/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

# 5. S3 금고에 저장된 DB 생성 결과(데이터베이스 엔드포인트 등)를 읽어옵니다.
data "terraform_remote_state" "db" {
  backend = "s3"
  config = {
    bucket = "8ocket-tfstate-s3"
    key    = "prod/db/terraform.tfstate"
    region = "ap-northeast-2"
  }
}