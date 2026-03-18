# prod/vpc/outputs.tf

output "vpc_id" {
  description = "생성된 VPC의 고유 ID"
  value       = module.vpc.vpc_id
}

output "public_subnets" {
  description = "퍼블릭 서브넷들의 ID 목록"
  value       = module.vpc.public_subnets
}

output "private_subnets" {
  description = "프라이빗(EKS) 서브넷들의 ID 목록"
  value       = module.vpc.private_subnets
}

output "database_subnets" {
  description = "프라이빗(DB) 서브넷들의 ID 목록"
  value       = module.vpc.database_subnets
}

# 향후 RDS 생성 시 필수적으로 연결해야 할 서브넷 그룹 이름
output "database_subnet_group_name" {
  description = "자동으로 생성된 DB 서브넷 그룹의 이름"
  value       = module.vpc.database_subnet_group_name
}

# 향후 EKS, RDS 등에서 사용할 중앙 통제용 보안 그룹 ID
output "alb_sg_id" {
  description = "ALB용 보안 그룹의 ID"
  value       = aws_security_group.alb_sg.id
}

output "eks_node_sg_id" {
  description = "EKS 워커 노드용 보안 그룹의 ID"
  value       = aws_security_group.eks_node_sg.id
}

output "db_sg_id" {
  description = "데이터베이스용 보안 그룹의 ID"
  value       = aws_security_group.db_sg.id
}


output "efs_id" {
  description = "생성된 EFS의 고유 ID"
  value       = aws_efs_file_system.main.id
}