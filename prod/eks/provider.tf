# prod/eks/provider.tf

terraform {
  # 테라폼 최소 요구 버전
  required_version = ">= 1.0.0"

  # 3명의 통역사(Provider)를 호출합니다.
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
      version = "~> 2.12" # 내부적으로 Helm 3.x 엔진을 완벽하게 지원하는 안정화 버전입니다.
    }
  }

  # (핵심) EKS 전용 S3 상태 파일 저장 경로로 완벽히 격리합니다.
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

# 2. 쿠버네티스(Kubernetes) 통역사 설정
provider "kubernetes" {
  # (핵심) 다음 단계에서 만들 'module.eks'의 결과값을 바로 넘겨받습니다.
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

  # 타임아웃을 방지하는 실시간 토큰 발급(Exec) 방식입니다.
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
  }
}

# 3. 헬름(Helm) 통역사 설정 (앱 설치용)
provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
    }
  }
}