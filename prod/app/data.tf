# prod/app/data.tf


# 1. 내 AWS 계정 및 리전 정보 불러오기
data "aws_caller_identity" "current" {}

data "aws_region" "current" {}


# 2. 이전 인프라(VPC, EKS) 결과물 불러오기

# S3 금고에 저장된 VPC 생성 결과(서브넷 ID, EFS ID 등)를 읽어옵니다.
data "terraform_remote_state" "vpc" {
  backend = "s3"
  config = {
    bucket = "8ocket-tfstate-s3"
    key    = "prod/vpc/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

# S3 금고에 저장된 EKS 생성 결과(클러스터 이름, 주소, OIDC 등)를 읽어옵니다.
data "terraform_remote_state" "eks" {
  backend = "s3"
  config = {
    bucket = "8ocket-tfstate-s3"
    key    = "prod/eks/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

data "terraform_remote_state" "db" {
  backend = "s3"
  config = {
    bucket = "8ocket-tfstate-s3"
    key    = "prod/db/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

# 3. EKS 클러스터 인증 정보 동적 조회

# 앞서 불러온 EKS 이름을 바탕으로, 해당 클러스터의 상세 정보를 한 번 더 조회합니다.
data "aws_eks_cluster" "cluster" {
  name = data.terraform_remote_state.eks.outputs.cluster_name
}


# 4. Route53 도메인 및 ACM 인증서 불러오기

# ExternalDNS가 도메인을 조작할 수 있도록 Route53 호스팅 영역 정보를 찾습니다.
data "aws_route53_zone" "main" {
  name         = "testkt.cloud" 
  private_zone = false # 퍼블릭 도메인이므로 false로 설정합니다.
}

# (주의) 아직 발급받은 인증서가 없으므로 임시로 주석 처리합니다.
/*
data "aws_acm_certificate" "main" {
  domain   = "testkt.cloud"
  
  # 만약 발급받으실 때 와일드카드 인증서로 받으셨다면 아래 줄을 대신 사용하세요.
  # domain   = "*.testkt.cloud" 
  
  statuses = ["ISSUED"] # 발급 완료된 정상 인증서만 가져옵니다.
  most_recent = true    # 가장 최근에 발급된 것을 선택합니다.
}
*/