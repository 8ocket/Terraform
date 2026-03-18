# prod/eks/data.tf

# 1. 내 AWS 계정 정보 조회
# 현재 테라폼을 실행하고 있는(터미널에 로그인된) AWS 계정 번호와 권한 정보를 실시간으로 읽어옵니다.
data "aws_caller_identity" "current" {}

# 2. VPC 인프라 원격 상태(Remote State) 불러오기
# S3 금고에 저장되어 있는 'prod/vpc' 폴더의 테라폼 실행 결과를 그대로 읽어옵니다.
data "terraform_remote_state" "vpc" {
  backend = "s3"

  config = {
    bucket = "8ocket-tfstate-s3"
    key    = "prod/vpc/terraform.tfstate"
    region = "ap-northeast-2"
  }
}