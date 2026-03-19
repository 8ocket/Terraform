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

    type = "ExternalName"
    

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


resource "kubernetes_namespace" "secrets" {
  metadata {
    name = "secrets"
  }
}


# 3. External Secrets Operator (ESO) 헬름 차트 설치



resource "helm_release" "external_secrets" {
  # 헬름으로 설치될 앱의 이름입니다.
  name       = "external-secrets"
  

  repository = "https://charts.external-secrets.io"
  chart      = "external-secrets"
  

  version    = "0.10.4"
  

  namespace  = kubernetes_namespace.secrets.metadata[0].name


  set {
    name  = "installCRDs"
    value = "true"
  }
  depends_on = [helm_release.aws_lbc]
}