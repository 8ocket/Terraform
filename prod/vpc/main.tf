# prod/vpc/main.tf

# ==========================================
# 1. AWS VPC 공식 모듈 호출 및 네트워크 뼈대 구성
# ==========================================
module "vpc" {
  # (중요) 사용할 모듈의 인터넷 주소와 버전입니다. 모듈 버전은 여기서 지정합니다.
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  # variables.tf에서 만들어둔 변수들을 모듈의 입력값으로 전달합니다.
  name = var.vpc_name
  cidr = var.vpc_cidr
  azs  = var.azs

  # 퍼블릭, 프라이빗(App), 데이터베이스(DB) 서브넷 대역과 이름을 매핑합니다.
  public_subnets        = var.public_subnets
  public_subnet_names   = var.public_subnet_names
  private_subnets       = var.private_subnets
  private_subnet_names  = var.private_subnet_names
  database_subnets      = var.database_subnets
  database_subnet_names = var.database_subnet_names

  # (핵심) 비용 절감을 위해 NAT 게이트웨이를 1개만 생성하고 모든 프라이빗 서브넷이 공유합니다.
  enable_nat_gateway = true
  single_nat_gateway = true

  # (핵심) EKS 파드와 DB가 IP 대신 이름(도메인)으로 서로를 찾을 수 있게 해줍니다.
  enable_dns_hostnames = true

  # (핵심) RDS를 프라이빗 망에 배포하기 위해 꼭 필요한 서브넷 묶음을 자동으로 만들어줍니다.
  create_database_subnet_group = true

  # ==========================================
  # [EKS 로드밸런서 자동 인식 태그 설정]
  # ==========================================
  # 인터넷과 연결된 퍼블릭 서브넷에는 외부용 ALB(elb)를 만들라는 태그를 붙입니다.
  public_subnet_tags = {
    "kubernetes.io/role/elb"                    = 1
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }

  # 인터넷이 차단된 프라이빗 서브넷에는 내부용 ALB(internal-elb)를 만들라는 태그를 붙입니다.
  private_subnet_tags = {
    "kubernetes.io/role/internal-elb"           = 1
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }
}

# ==========================================
# 2. 중앙 통제용 보안 그룹 (Security Group)
# ==========================================

# 2-1. 외부 사용자가 접속할 ALB용 방화벽 (웹 트래픽 허용)
resource "aws_security_group" "alb_sg" {
  name        = "${var.env}-alb-sg"
  description = "Security group for Application Load Balancer"
  # 위에서 만든 VPC 안에 이 보안 그룹을 위치시킵니다.
  vpc_id      = module.vpc.vpc_id

  # (Inbound) 인터넷(0.0.0.0/0)에서 들어오는 HTTP(80) 접속을 허용합니다.
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # (Inbound) 인터넷에서 들어오는 HTTPS(443) 보안 접속을 허용합니다.
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # (Outbound) ALB가 내부의 EKS 파드들에게 데이터를 전달할 수 있도록 모든 길을 열어둡니다.
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# 2-2. EKS 워커 노드(파드가 뜨는 컴퓨터)용 방화벽
resource "aws_security_group" "eks_node_sg" {
  name        = "${var.env}-eks-node-sg"
  description = "Security group for EKS Worker Nodes"
  vpc_id      = module.vpc.vpc_id

  # (Inbound) ALB에서 들어오는 트래픽만 안전하게 통과시킵니다.
  ingress {
    from_port       = 0
    to_port         = 65535
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  # (Outbound) 파드가 외부(DB, 인터넷 등)와 통신할 수 있게 열어둡니다.
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# 2-3. 데이터베이스 (RDS & Redis)용 핀셋 방화벽
resource "aws_security_group" "db_sg" {
  name        = "${var.env}-db-sg"
  description = "Security group for RDS and Redis"
  vpc_id      = module.vpc.vpc_id

  # (Inbound) EKS 노드에서 보내는 PostgreSQL(5432) 접속만 딱 집어서 허용합니다.
  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.eks_node_sg.id]
  }

  # (Inbound) EKS 노드에서 보내는 Redis(6379) 접속만 딱 집어서 허용합니다.
  ingress {
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [aws_security_group.eks_node_sg.id]
  }

  # (Outbound) DB가 밖으로 나갈 일은 제한적이므로 모든 포트를 여는 대신 필요한 통신만 구성하는 것이 안전하지만, 편의상 열어둡니다.
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# 2-4. VPC 엔드포인트 전용 방화벽
resource "aws_security_group" "vpc_endpoint_sg" {
  name        = "${var.env}-vpc-endpoint-sg"
  description = "Security group for VPC Endpoints (ECR, Bedrock, STS)"
  vpc_id      = module.vpc.vpc_id

  # (Inbound) VPC 내부(10.0.0.0/16)에서 보내는 HTTPS(443) 통신만 허용합니다.
  # AWS API 통신은 모두 암호화된 HTTPS를 사용하기 때문입니다.
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  # (Outbound) 엔드포인트가 외부로 직접 나갈 일은 없으므로 생략해도 무방하나, 
  # 테라폼 기본 동작과의 충돌을 막기 위해 열어둡니다.
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}