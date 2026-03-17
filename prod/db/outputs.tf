# prod/db/outputs.tf

# ==========================================
# 1. RDS PostgreSQL 출력 값
# ==========================================
output "rds_endpoint" {
  description = "RDS 데이터베이스의 실제 접속 주소"
  # 모듈이 만들어낸 긴 AWS 접속 주소를 가져옵니다.
  value       = module.db.db_instance_address
}

output "rds_port" {
  description = "RDS 데이터베이스 포트"
  value       = module.db.db_instance_port
}

output "rds_db_name" {
  description = "RDS 내부 데이터베이스 이름"
  value       = module.db.db_instance_name
}

output "rds_connection_string" {
  description = "RDS 전체 연결 문자열 (주소:포트)"
  # (핵심) EKS 파드 환경변수에 바로 넣기 편하도록 주소와 포트를 조합합니다.
  value       = "${module.db.db_instance_address}:${module.db.db_instance_port}"
}

output "rds_password" {
  description = "RDS 관리자 비밀번호"
  value       = var.db_password
  # (핵심) 터미널 화면이나 깃허브 액션 로그에 평문으로 노출되는 것을 막아줍니다.
  sensitive   = true 
}

# ==========================================
# 2. Valkey (Redis) 출력 값
# ==========================================
output "valkey_endpoint" {
  description = "Valkey(Redis)의 실제 접속 주소"
  # 복제 그룹이 만들어낸 마스터 노드의 접속 주소를 가져옵니다.
  value       = aws_elasticache_replication_group.valkey.primary_endpoint_address
}

output "valkey_port" {
  description = "Valkey(Redis) 포트"
  value       = aws_elasticache_replication_group.valkey.port
}

output "valkey_connection_string" {
  description = "Valkey(Redis) 전체 연결 문자열 (주소:포트)"
  value       = "${aws_elasticache_replication_group.valkey.primary_endpoint_address}:${aws_elasticache_replication_group.valkey.port}"
}