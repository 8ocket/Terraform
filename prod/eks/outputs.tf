# prod/eks/outputs.tf

output "cluster_name" {
  description = "EKS 클러스터의 이름입니다."
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "EKS API 서버의 접속 주소입니다."
  value       = module.eks.cluster_endpoint
}

# (추천) 엔드포인트와 함께 반드시 필요한 인증서 정보입니다.
output "cluster_certificate_authority_data" {
  description = "EKS API 서버 통신용 인증서 데이터입니다. (보안을 위해 화면에 숨김 처리됨)"
  value       = module.eks.cluster_certificate_authority_data
  sensitive   = true # 화면에 길고 복잡한 텍스트가 노출되지 않도록 '***' 로 가려줍니다.
}

output "cluster_security_group_id" {
  description = "EKS 클러스터의 기본 보안 그룹 ID입니다."
  value       = module.eks.cluster_security_group_id
}

output "oidc_provider_arn" {
  description = "IRSA 및 구형 애드온을 위한 OIDC 공급자 ARN입니다."
  value       = module.eks.oidc_provider_arn
}

# 알파벳 정렬의 특성을 이용해 무조건 맨 마지막 줄에 출력되도록 'z_' 접두사를 사용했습니다.
output "z_kubeconfig_update_command" {
  description = "내 로컬 PC에서 클러스터에 접속하기 위한 명령어입니다. 복사해서 실행하세요."
  value       = "aws eks update-kubeconfig --region ap-northeast-2 --name ${module.eks.cluster_name}"
}