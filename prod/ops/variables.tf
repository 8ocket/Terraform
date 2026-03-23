# prod/ops/variables.tf

# ==========================================
# 1. 공통 환경 및 네트워크 설정
# ==========================================

variable "env" {
  description = "환경 이름"
  type        = string
  default     = "prod"
}

variable "domain_name" {
  description = "향후 모니터링 외부 접속을 위한 도메인 주소"
  type        = string
  default     = "" 
}

variable "monitoring_namespace" {
  description = "모니터링 앱(Prometheus 스택)이 배포될 쿠버네티스 네임스페이스"
  type        = string
  default     = "monitoring"
}

variable "keda_namespace" {
  description = "KEDA 오토스케일러가 배포될 쿠버네티스 네임스페이스"
  type        = string
  default     = "keda"
}

# ==========================================
# 2. 헬름(Helm) 차트 버전
# ==========================================

variable "chart_version_kube_prometheus_stack" {
  description = "Kube-Prometheus-Stack Helm 차트 버전"
  type        = string
  default     = "82.10.5" # EKS 1.34 완벽 호환 최신 버전
}

variable "chart_version_keda" {
  description = "KEDA (이벤트 기반 스케일러) Helm 차트 버전"
  type        = string
  default     = "2.19.0"  # (요청 사항) 공식 차트 릴리즈 안정화 버전 반영
}