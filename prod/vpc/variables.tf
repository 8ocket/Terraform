# prod/vpc/variables.tf

# ==========================================
# 1. 기본 설정 변수
# ==========================================
variable "env" {
  description = "환경 이름 (예: prod, dev)"
  type        = string
  default     = "prod"
}

# (핵심 수정) 숫자로 시작하면 안 되는 리소스들을 위해 이름을 영문자로 시작하게 변경합니다.
variable "vpc_name" {
  description = "VPC의 기본 이름"
  type        = string
  default     = "vpc-8ocket" # (수정) 8ocket-vpc -> vpc-8ocket
}

# 향후 EKS의 로드밸런서(ALB)가 서브넷을 자동으로 찾기 위해 꼭 필요한 태그용 변수입니다.
variable "cluster_name" {
  description = "EKS 클러스터 이름"
  type        = string
  default     = "mindlog"
}

# ==========================================
# 2. 네트워크(IP 대역) 및 가용 영역 변수
# ==========================================
variable "vpc_cidr" {
  description = "VPC 전체 IP 대역"
  type        = string
  default     = "10.0.0.0/16"
}

variable "azs" {
  description = "사용할 가용 영역(AZ) 목록"
  type        = list(string)
  default     = ["ap-northeast-2a", "ap-northeast-2b", "ap-northeast-2c"]
}

variable "public_subnets" {
  description = "퍼블릭 서브넷 IP 대역 목록"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "private_subnets" {
  description = "프라이빗(EKS) 서브넷 IP 대역 목록"
  type        = list(string)
  default     = ["10.0.16.0/20", "10.0.32.0/20", "10.0.48.0/20"]
}

variable "database_subnets" {
  description = "프라이빗(DB) 서브넷 IP 대역 목록"
  type        = list(string)
  default     = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
}

# ==========================================
# 3. 서브넷 이름 지정 변수
# ==========================================
# (핵심 수정) 모든 서브넷 이름도 리소스 유형이 먼저 오도록 변경합니다.
variable "public_subnet_names" {
  description = "퍼블릭 서브넷 이름 목록"
  type        = list(string)
  default     = ["pub-subnet-1-8ocket", "pub-subnet-2-8ocket", "pub-subnet-3-8ocket"]
}

variable "private_subnet_names" {
  description = "프라이빗(App) 서브넷 이름 목록"
  type        = list(string)
  default     = ["pri-subnet-1-8ocket", "pri-subnet-2-8ocket", "pri-subnet-3-8ocket"]
}

variable "database_subnet_names" {
  description = "프라이빗(DB) 서브넷 이름 목록"
  type        = list(string)
  default     = ["db-subnet-1-8ocket", "db-subnet-2-8ocket", "db-subnet-3-8ocket"]
}