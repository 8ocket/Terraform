# prod/ops/variables.tf

# ==========================================
# 1. 네임스페이스 / 라이선스 키 설정
# ==========================================

variable "monitoring_namespace" {
  description = "모니터링 앱(Prometheus 스택)이 배포될 쿠버네티스 네임스페이스"
  type        = string
  default     = "monitoring"
}

variable "newrelic_namespace" {
  type    = string
  default = "newrelic"
}

variable "newrelic_license_key" {
  type      = string
  sensitive = true
}

variable "keda_namespace" {
  description = "KEDA 오토스케일러가 배포될 쿠버네티스 네임스페이스"
  type        = string
  default     = "keda"
}

