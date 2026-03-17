# prod/vpc/variables.tf

# ==========================================
# 1. 기본 설정 변수
# ==========================================
variable "env" {
  description = "환경 이름 (예: prod, dev)"
  type        = string
  default     = "prod"
}

# (중요) AWS 자원들의 기본 뼈대가 될 이름입니다.
variable "vpc_name" {
  description = "VPC의 기본 이름"
  type        = string
  default     = "8ocket-vpc"
}

# (중요) 향후 EKS의 로드밸런서(ALB)가 서브넷을 자동으로 찾기 위해 꼭 필요한 태그용 변수입니다.
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
# (중요) AWS VPC 모듈이 자동으로 짓는 이름 대신, 명시적으로 지정하신 이름을 부여하기 위한 리스트입니다.
variable "public_subnet_names" {
  description = "퍼블릭 서브넷 이름 목록"
  type        = list(string)
  default     = ["8ocket-pub-subnet-1", "8ocket-pub-subnet-2", "8ocket-pub-subnet-3"]
}

variable "private_subnet_names" {
  description = "프라이빗(App) 서브넷 이름 목록"
  type        = list(string)
  default     = ["8ocket-pri-subnet-1", "8ocket-pri-subnet-2", "8ocket-pri-subnet-3"]
}

variable "database_subnet_names" {
  description = "프라이빗(DB) 서브넷 이름 목록"
  type        = list(string)
  default     = ["8ocket-db-subnet-1", "8ocket-db-subnet-2", "8ocket-db-subnet-3"]
}