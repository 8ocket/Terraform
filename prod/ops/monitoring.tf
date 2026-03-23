# prod/ops/monitoring.tf

resource "helm_release" "prometheus_stack" {
  name             = "prometheus-stack"
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "kube-prometheus-stack"
  version          = var.chart_version_kube_prometheus_stack
  namespace        = var.monitoring_namespace
  create_namespace = true
  wait             = true  # 파드가 모두 Running 상태가 될 때까지 안전하게 대기
  timeout          = 600
  atomic           = true

  # ---------------------------------------------------------
  # 인프라 핵심 컴포넌트 온디맨드 노드 강제 배치
  # ---------------------------------------------------------
  
  set {
    name  = "prometheusOperator.nodeSelector.karpenter\\.sh/capacity-type"
    value = "on-demand"
  }

  set {
    name  = "prometheus.prometheusSpec.nodeSelector.karpenter\\.sh/capacity-type"
    value = "on-demand"
  }

  set {
    name  = "grafana.nodeSelector.karpenter\\.sh/capacity-type"
    value = "on-demand"
  }

  set {
    name  = "alertmanager.alertmanagerSpec.nodeSelector.karpenter\\.sh/capacity-type"
    value = "on-demand"
  }

  set {
    name  = "kubeStateMetrics.nodeSelector.karpenter\\.sh/capacity-type"
    value = "on-demand"
  }

  # ---------------------------------------------------------
  # 향후 도메인 접속(ALB)을 위한 Ingress 주석 템플릿
  # ---------------------------------------------------------
  /*
  # Grafana 접속 주소
  set { name = "grafana.ingress.enabled", value = "true" }
  set { name = "grafana.ingress.ingressClassName", value = "alb" }
  set { name = "grafana.ingress.annotations.alb\\.ingress\\.kubernetes\\.io/group\\.name", value = "monitoring-group" }
  set { name = "grafana.ingress.annotations.alb\\.ingress\\.kubernetes\\.io/scheme", value = "internet-facing" }
  set { name = "grafana.ingress.annotations.alb\\.ingress\\.kubernetes\\.io/target-type", value = "ip" }
  set { name = "grafana.ingress.hosts[0]", value = "grafana.${var.domain_name}" }
  
  # HTTPS 인증서 설정 (나중에 실제 발급받은 ARN으로 변경하세요)
  set { name = "server.ingress.annotations.alb\\.ingress\\.kubernetes\\.io/certificate-arn", value = "arn:aws:acm:ap-northeast-2:내계정번호:certificate/인증서-고유번호" }
  set { name = "server.ingress.annotations.alb\\.ingress\\.kubernetes\\.io/listen-ports", value = "[{\"HTTPS\":443}, {\"HTTP\":80}]" }

  # WAF 고유번호(ARN) 연동
  set { 
    name  = "server.ingress.annotations.alb\\.ingress\\.kubernetes\\.io/wafv2-acl-arn" 
    value = aws_wafv2_web_acl.main.arn 
  }

  # Prometheus 접속 주소
  set { name = "prometheus.ingress.enabled", value = "true" }
  set { name = "prometheus.ingress.ingressClassName", value = "alb" }
  set { name = "prometheus.ingress.annotations.alb\\.ingress\\.kubernetes\\.io/group\\.name", value = "monitoring-group" }
  set { name = "prometheus.ingress.annotations.alb\\.ingress\\.kubernetes\\.io/scheme", value = "internet-facing" }
  set { name = "prometheus.ingress.annotations.alb\\.ingress\\.kubernetes\\.io/target-type", value = "ip" }
  set { name = "prometheus.ingress.hosts[0]", value = "prometheus.${var.domain_name}" }
    
    # HTTPS 인증서 설정 (나중에 실제 발급받은 ARN으로 변경하세요)
  set { name = "server.ingress.annotations.alb\\.ingress\\.kubernetes\\.io/certificate-arn", value = "arn:aws:acm:ap-northeast-2:내계정번호:certificate/인증서-고유번호" }
  set { name = "server.ingress.annotations.alb\\.ingress\\.kubernetes\\.io/listen-ports", value = "[{\"HTTPS\":443}, {\"HTTP\":80}]" }
  
    # WAF 고유번호(ARN) 연동
  set { 
    name  = "server.ingress.annotations.alb\\.ingress\\.kubernetes\\.io/wafv2-acl-arn" 
    value = aws_wafv2_web_acl.main.arn 
  }
  */
}