# prod/ops/

# 모니터링(프로메테우스/그라파나) 전용 네임스페이스
resource "kubernetes_namespace" "monitoring" {
  metadata {
    name = var.monitoring_namespace
  }
}

# New Relic 전용 네임스페이스
resource "kubernetes_namespace" "newrelic" {
  metadata {
    name = var.newrelic_namespace
  }
}

# kead 전용 네임스페이스
resource "kubernetes_namespace" "keda" {
  metadata {
    name = var.keda_namespace
  }
}

# 2. license key

resource "kubernetes_secret" "newrelic_license" {
  depends_on = [kubernetes_namespace.newrelic]

  metadata {
    name      = "newrelic-license-key" 
    namespace = "newrelic"
  }

  data = {
    licenseKey = var.newrelic_license_key
  }
}