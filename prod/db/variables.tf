# prod/db/variables.tf

# ==========================================
# 1. 공통 설정
# ==========================================
variable "env" {
  description = "환경 이름"
  type        = string
  default     = "prod"
}

# ==========================================
# 2. RDS (PostgreSQL) 설정
# ==========================================
variable "db_name" {
  description = "PostgreSQL 데이터베이스 이름"
  type        = string
  default     = "mindlog_db"
}

variable "db_user" {
  description = "데이터베이스 최고 관리자 계정"
  type        = string
  default     = "mindlog"
}

variable "db_password" {
  description = "데이터베이스 관리자 비밀번호"
  type        = string
  default     = "test1234"
  sensitive   = true # 터미널 화면이나 깃허브 액션 로그에 비밀번호가 평문으로 노출되는 것을 막아줍니다.
}

variable "db_instance_class" {
  description = "RDS 인스턴스 사양"
  type        = string
  default     = "db.t4g.micro"
}

variable "db_allocated_storage" {
  description = "RDS 할당 용량 (GB)"
  type        = number
  default     = 20
}

variable "db_engine_version" {
  description = "PostgreSQL 엔진 버전"
  type        = string
  default     = "18"
}

# ==========================================
# 3. Valkey (Redis 대체) 설정
# ==========================================
variable "redis_node_type" {
  description = "Valkey 인스턴스 사양"
  type        = string
  default     = "cache.t4g.micro"
}

variable "redis_engine_version" {
  description = "Valkey 엔진 버전"
  type        = string
  default     = "8.2"
}