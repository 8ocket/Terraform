# prod/app/provider.tf

terraform {
  # 테라폼 최소 요구 버전
  required_version = ">= 1.0.0"

  required_providers {
    # 1. AWS 자원(IAM, Route53 등) 생성용
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    # 2. 쿠버네티스 기본 자원(Namespace, ServiceAccount 등) 생성용
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.30"
    }
    # 3. 헬름 차트(ArgoCD, Prometheus 등 패키지 앱) 설치용
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12"
    }
    # 4. 순수 YAML 파일(Karpenter 설정 등) 강제 배포용 (Best Practice 추가)
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = ">= 1.14.0"
    }
  }

  # (핵심) 'app' 폴더 전용 S3 상태 파일 저장 경로 및 DynamoDB 잠금 설정
  backend "s3" {
    bucket         = "8ocket-tfstate-s3"
    key            = "prod/app/terraform.tfstate"
    region         = "ap-northeast-2"
    encrypt        = true
    dynamodb_table = "8ocket-tfstate-dynamodb"
  }
}


# 1. AWS 설정

provider "aws" {
  region = "ap-northeast-2"

  # API 호출 제한(Rate Limit) 방지를 위한 재시도 횟수 증가
  max_retries = 10

  # 이 폴더에서 만들어지는 모든 AWS 자원(IAM Role 등)에 자동으로 이름표 부착
  default_tags {
    tags = {
      Project = "8ocket"
      Env     = "prod"
    }
  }
}


# 2. 쿠버네티스(Kubernetes) 설정

provider "kubernetes" {
  # data.tf에서 읽어온 EKS 클러스터 주소를 동적으로 주입
  host                   = data.terraform_remote_state.eks.outputs.cluster_endpoint
  # 인증서 에러 방지를 위한 Base64 디코딩 처리
  cluster_ca_certificate = base64decode(data.terraform_remote_state.eks.outputs.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", data.terraform_remote_state.eks.outputs.cluster_name]
  }
}


# 3. 헬름(Helm) 설정

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


# 4. Kubectl 설정 (순수 YAML용)

provider "kubectl" {
  host                   = data.terraform_remote_state.eks.outputs.cluster_endpoint
  cluster_ca_certificate = base64decode(data.terraform_remote_state.eks.outputs.cluster_certificate_authority_data)
  
  # 로컬 PC의 Kubeconfig 파일을 읽지 않도록 강제 설정 (깃액션 환경 에러 방지)
  load_config_file       = false

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", data.terraform_remote_state.eks.outputs.cluster_name]
  }
}