# prod/eks/variables.tf

# ==========================================
# 1. 기본 설정
# ==========================================
variable "env" {
  description = "환경 이름"
  type        = string
  default     = "prod"
}

# ==========================================
# 2. EKS 클러스터 제어판(Control Plane) 설정
# ==========================================
variable "cluster_name" {
  description = "EKS 클러스터 이름"
  type        = string
  default     = "mindlog"
}

variable "cluster_version" {
  description = "Kubernetes 버전"
  type        = string
  default     = "1.34"
}

variable "cluster_endpoint_public_access_cidrs" {
  description = "EKS API 서버 정문(퍼블릭) 개방 범위"
  type        = list(string)
  default     = ["0.0.0.0/0"] # 누구나 노크는 가능하지만, IAM 인증을 통과해야만 들어올 수 있습니다.
}

variable "cloudwatch_log_retention_days" {
  description = "마스터 노드 감사 로그 보관 기간(일)"
  type        = number
  default     = 7 
}

variable "admin_iam_arn" {
  description = "kubectl 최고 관리자 권한을 가질 내 로컬 PC의 AWS 계정 ARN"
  type        = string
  default     = "arn:aws:iam::854439979580:user/mindbreaker" 
}

# ==========================================
# 3. 고정 워커 노드(MNG) 설정 (시스템 파드용)
# ==========================================
variable "mng_instance_types" {
  description = "기본 워커 노드 인스턴스 사양"
  type        = list(string)
  default     = ["m7i.large"] # Jenkins, Prometheus 등 무거운 도구들을 넉넉히 수용합니다.
}

variable "mng_capacity_type" {
  description = "인스턴스 구매 옵션"
  type        = string
  default     = "ON_DEMAND" # Karpenter가 띄울 스팟 인스턴스와 완벽히 분리되어 안정성을 보장합니다.
}

variable "mng_desired_size" {
  description = "기본 워커 노드 개수"
  type        = number
  default     = 3 # 3개의 프라이빗(App) 서브넷에 하나씩 배치됩니다.
}

# ==========================================
# 4. EKS 애드온(Add-on) 설정
# ==========================================
variable "ebs_csi_version" {
  description = "EBS CSI 드라이버 애드온 버전"
  type        = string
  default     = "v1.35.0-eksbuild.1" # EKS 1.34와 호환되는 안정적인 최신 버전입니다.
}