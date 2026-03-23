# prod/app/variables.tf


# 1. 공통 환경 설정

variable "env" {
  description = "환경 이름"
  type        = string
  default     = "prod"
}

variable "domain_name" {
  description = "메인 서비스 도메인 주소 (향후 도메인 구매/Route53 등록 후 여기에 입력하세요."
  type        = string
  default     = "" 
}


# 2. 초기 관리자 비밀번호 (보안 적용)

# 터미널이나 깃허브 액션 로그에 평문으로 노출되지 않도록 sensitive = true 를 적용합니다.
# 실제 값은 실행 시 입력하거나, GitHub Secrets(TF_VAR_argocd_admin_password)를 통해 안전하게 주입받습니다.

variable "argocd_admin_password" {
  description = "ArgoCD 초기 관리자(admin) 비밀번호"
  type        = string
  default     = "Argocdadmin1234"
}

variable "jenkins_admin_password" {
  description = "Jenkins 초기 관리자(admin) 비밀번호"
  type        = string
  default     = "Jenkinsadmin1234"
}

# 3. 인프라 코어 앱 버전

variable "chart_version_aws_lbc" {
  description = "AWS Load Balancer Controller Helm 차트 버전"
  type        = string
  default     = "3.1.0"
}

variable "chart_version_ebs_csi" {
  description = "AWS EBS CSI Driver Helm 차트 버전"
  type        = string
  default     = "2.56.1" 
}

variable "chart_version_external_dns" {
  description = "ExternalDNS Helm 차트 버전"
  type        = string
  default     = "1.20.0"
}


# 4. CI/CD 및 오토스케일링 앱 버전

variable "chart_version_karpenter" {
  description = "Karpenter 오토스케일러 Helm 차트 버전"
  type        = string
  default     = "1.9.0" 
}


variable "chart_version_argocd" {
  description = "ArgoCD Helm 차트 버전"
  type        = string
  default     = "9.4.10"
}

variable "chart_version_jenkins" {
  description = "Jenkins Helm 차트 버전"
  type        = string
  default     = "5.9.8"
}
