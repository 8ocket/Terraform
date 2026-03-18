# prod/app/external_eso.tf


# 1. 외부 데이터베이스 연결용 서비스 (ExternalName)

# (Best Practice) 앱들이 복잡한 AWS 주소 대신 'rds'라는 짧은 이름표만 보고 찾아갈 수 있게 연결해 줍니다.

resource "kubernetes_service" "rds" {
  metadata {
    # 쿠버네티스 내부에서 호출할 별명입니다. (예: rds.default.svc.cluster.local)
    name      = "rds"
    # 앱들이 기본적으로 설치될 default 네임스페이스에 생성합니다.
    namespace = "default" 
  }

  spec {
    # 외부 주소로 트래픽을 토스해주는 특수 서비스 타입입니다.
    type = "ExternalName"
    
    # db 폴더의 테라폼 실행 결과에서 RDS 접속 주소를 동적으로 끌어옵니다.
    external_name = data.terraform_remote_state.db.outputs.rds_endpoint
  }
}

resource "kubernetes_service" "redis" {
  metadata {
    # 쿠버네티스 내부에서 호출할 별명입니다. (예: redis.default.svc.cluster.local)
    name      = "redis"
    namespace = "default"
  }

  spec {
    type = "ExternalName"
    
    # db 폴더의 결과에서 Valkey(Redis) 접속 주소를 동적으로 끌어옵니다.
    external_name = data.terraform_remote_state.db.outputs.valkey_endpoint
  }
}


# 2. External Secrets Operator (ESO) 전용 네임스페이스

# 보안 관련 도구이므로 다른 앱들과 섞이지 않도록 격리된 'secrets' 방을 만듭니다.

resource "kubernetes_namespace" "secrets" {
  metadata {
    name = "secrets"
  }
}


# 3. External Secrets Operator (ESO) 헬름 차트 설치

# 향후 AWS Secrets Manager에서 비밀번호를 안전하게 배달해 줄 핵심 엔진을 설치합니다.

resource "helm_release" "external_secrets" {
  # 헬름으로 설치될 앱의 이름입니다.
  name       = "external-secrets"
  
  # ESO 공식 헬름 차트 저장소 주소입니다.
  repository = "https://charts.external-secrets.io"
  chart      = "external-secrets"
  
  # EKS 1.34와 완벽히 호환되는 최신 안정화 버전으로 고정합니다.
  version    = "0.10.4"
  
  # 위에서 만든 'secrets' 네임스페이스에 안전하게 설치합니다.
  namespace  = kubernetes_namespace.secrets.metadata[0].name

  # (핵심) ESO가 작동하기 위해 필요한 필수 K8s 설계도(CRD)를 함께 설치하도록 강제합니다.
  set {
    name  = "installCRDs"
    value = "true"
  }
  depends_on = [helm_release.aws_lbc]
}