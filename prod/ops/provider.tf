# prod/ops/provider.tf

terraform {
  # 1. 테라폼 최소 요구 버전 강제
  required_version = ">= 1.0.0"

  # 2. S3 상태 파일(tfstate) 저장소 설정 (경로 완벽 분리)
  backend "s3" {
    bucket         = "8ocket-tfstate-s3"
    key            = "prod/ops/terraform.tfstate" # 기존 app 폴더와 겹치지 않는 독립된 장부
    region         = "ap-northeast-2"
    dynamodb_table = "8ocket-tfstate-dynamodb"        # 동시 작업 충돌 방지용 자물쇠
    encrypt        = true
  }

  # 3. 사용할(Provider) 버전 정의
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.30"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = ">= 1.14.0"
    }
  }
}

# ---------------------------------------------------------
# 통역사(Provider) 세부 설정
# ---------------------------------------------------------

# 1. AWS 설정
provider "aws" {
  region = "ap-northeast-2"

  # 생성되는 모든 AWS 자원에 자동으로 꼬리표(Tag) 부착
  default_tags {
    tags = {
      Environment = "prod"
      Layer       = "ops"
    }
  }
}

# 2. 쿠버네티스 설정 (토큰 만료 방지 Exec 인증)
provider "kubernetes" {
  host                   = data.terraform_remote_state.eks.outputs.cluster_endpoint
  cluster_ca_certificate = base64decode(data.terraform_remote_state.eks.outputs.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", data.terraform_remote_state.eks.outputs.cluster_name]
  }
}

# 3. 헬름 설정 (토큰 만료 방지 Exec 인증)
provider "helm" {
  kubernetes {
    host                   = data.terraform_remote_state.eks.outputs.cluster_endpoint
    cluster_ca_certificate = base64decode(data.terraform_remote_state.eks.outputs.cluster_certificate_authority_data)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", data.terraform_remote_state.eks.outputs.cluster_name]
    }
  }
}

# 4. Kubectl 설정 (순수 YAML 배포용, 토큰 만료 방지 Exec 인증)
provider "kubectl" {
  host                   = data.terraform_remote_state.eks.outputs.cluster_endpoint
  cluster_ca_certificate = base64decode(data.terraform_remote_state.eks.outputs.cluster_certificate_authority_data)
  load_config_file       = false # 깃액션 등 외부 환경에서의 권한 에러 방지

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", data.terraform_remote_state.eks.outputs.cluster_name]
  }
}