# prod/ops/keda.tf

resource "helm_release" "keda" {
  name             = "keda"
  repository       = "https://kedacore.github.io/charts"
  chart            = "keda"
  version          = var.chart_version_keda
  namespace        = var.keda_namespace
  create_namespace = true
  
  # 배포 안정성 옵션
  wait    = true
  timeout = 600
  atomic  = true

  # ---------------------------------------------------------
  # 인프라 핵심 컴포넌트 온디맨드 노드 강제 배치
  # (테라폼 문법에 따라 마침표는 역슬래시 2개(\\)로 이스케이프 처리)
  # ---------------------------------------------------------
  
  set {
    name  = "operator.nodeSelector.karpenter\\.sh/capacity-type"
    value = "on-demand"
  }

  set {
    name  = "metricsServer.nodeSelector.karpenter\\.sh/capacity-type"
    value = "on-demand"
  }

  set {
    name  = "webhooks.nodeSelector.karpenter\\.sh/capacity-type"
    value = "on-demand"
  }

  # ---------------------------------------------------------
  # AWS IAM 권한 연동을 위한 신분증(ServiceAccount) 이름 고정
  # ---------------------------------------------------------
  
  set {
    name  = "serviceAccount.operator.name"
    value = "keda-operator-sa"
  }
}