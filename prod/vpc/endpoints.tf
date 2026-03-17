# prod/vpc/endpoints.tf

# 현재 인프라가 배포되는 리전(ap-northeast-2)의 정확한 이름을 자동으로 가져옵니다.
data "aws_region" "current" {}

# -------------------------------------------------------------------------
# 1. Gateway형 엔드포인트 (S3)
# -------------------------------------------------------------------------
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = module.vpc.vpc_id
  service_name      = "com.amazonaws.${data.aws_region.current.name}.s3"
  vpc_endpoint_type = "Gateway"

  # (핵심) VPC 모듈이 만든 프라이빗 라우팅 테이블들에 자동으로 S3 게이트웨이를 연결합니다.
  route_table_ids = module.vpc.private_route_table_ids

  # 추후 iam 역할 설정 필요
}

# -------------------------------------------------------------------------
# 2. Interface형 엔드포인트 (ECR, STS, Bedrock)
# -------------------------------------------------------------------------

# 2-1. ECR API 엔드포인트 (인증 및 메타데이터용)
resource "aws_vpc_endpoint" "ecr_api" {
  vpc_id            = module.vpc.vpc_id
  service_name      = "com.amazonaws.${data.aws_region.current.name}.ecr.api"
  vpc_endpoint_type = "Interface"

  # 인터페이스형은 서브넷 안에 생성되므로, 프라이빗 서브넷 3곳에 모두 배치합니다.
  subnet_ids = module.vpc.private_subnets

  # (핵심) 프라이빗 DNS를 활성화하여 앱 코드 수정 없이 기존 ECR 도메인을 그대로 쓰게 합니다.
  private_dns_enabled = true

  # main.tf에서 만든 엔드포인트 전용 보안 그룹을 입혀줍니다.
  security_group_ids = [aws_security_group.vpc_endpoint_sg.id]

  # 추후 iam 역할 설정 필요
}

# 2-2. ECR DKR 엔드포인트 (실제 이미지 다운로드용)
resource "aws_vpc_endpoint" "ecr_dkr" {
  vpc_id              = module.vpc.vpc_id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.ecr.dkr"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = module.vpc.private_subnets
  private_dns_enabled = true
  security_group_ids  = [aws_security_group.vpc_endpoint_sg.id]
  
  # 추후 iam 역할 설정 필요
}

# 2-3. STS 엔드포인트 (파드가 AWS 자원에 접근할 때 임시 권한을 받기 위함)
resource "aws_vpc_endpoint" "sts" {
  vpc_id              = module.vpc.vpc_id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.sts"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = module.vpc.private_subnets
  private_dns_enabled = true
  security_group_ids  = [aws_security_group.vpc_endpoint_sg.id]
  
  # 추후 iam 역할 설정 필요
}

# 2-4. Bedrock Runtime 엔드포인트 (AI 모델 직접 호출용)
resource "aws_vpc_endpoint" "bedrock_runtime" {
  vpc_id              = module.vpc.vpc_id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.bedrock-runtime"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = module.vpc.private_subnets
  private_dns_enabled = true
  security_group_ids  = [aws_security_group.vpc_endpoint_sg.id]
  
  # 추후 iam 역할 설정 필요
}