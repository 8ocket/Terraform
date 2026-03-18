# prod/eks/cluster.tf

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  # 1. VPC 및 서브넷 위치 지정 (S3 원격 상태에서 App 프라이빗 서브넷을 가져옵니다)
  vpc_id                   = data.terraform_remote_state.vpc.outputs.vpc_id
  subnet_ids               = data.terraform_remote_state.vpc.outputs.private_subnets
  control_plane_subnet_ids = data.terraform_remote_state.vpc.outputs.private_subnets

  # 2. 클러스터 엔드포인트 제어 (외부 노크 허용, 내부 통신 허용)
  cluster_endpoint_public_access       = true
  cluster_endpoint_public_access_cidrs = var.cluster_endpoint_public_access_cidrs
  cluster_endpoint_private_access      = true

  # 3. 최신 AWS API 기반의 권한 부여 (Access Entry)
  authentication_mode = "API"
  # 테라폼을 실행하는 주체(GitHub Actions 등)에게도 최고 관리자 권한 자동 부여
  enable_cluster_creator_admin_permissions = true

  # aws cli 로그인 후 계정에 '최고 관리자(cluster-admin)' 권한 부여
  access_entries = {
    local_admin = {
      kubernetes_groups = []
      principal_arn     = var.admin_iam_arn

      policy_associations = {
        cluster_admin = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = {
            type = "cluster"
          }
        }
      }
    }
  }

  # 4. 필수 시스템 애드온 (AWS 기본값 최신 버전 사용)
  cluster_addons = {
    vpc-cni                = { most_recent = true }
    coredns                = { most_recent = true }
    kube-proxy             = { most_recent = true }
    # Pod Identity Agent를 기본으로 설치하여 IRSA의 복잡함을 덜어냅니다.
    eks-pod-identity-agent = { most_recent = true }
  }

  # 5. 마스터 노드 감사 로그 켜기 (비용 발생 O)
  cluster_enabled_log_types = ["api", "authenticator"]

  # 6. OIDC 공급자 활성화 (구형 앱 호환성을 위한 IRSA 예비망)
  enable_irsa = true

  # 7. 시스템 파드가 올라갈 3대의 고정 워커 노드 (MNG)
  eks_managed_node_groups = {
    default_mng = {
      min_size     = 1
      max_size     = 3
      desired_size = var.mng_desired_size

      instance_types = var.mng_instance_types
      capacity_type  = var.mng_capacity_type # variables.tf에 설정된 "ON_DEMAND" 적용

      # 앱들이 온디맨드 노드임을 알아챌 수 있도록 명찰(라벨) 달아주기
      labels = {
        "karpenter.sh/capacity-type" = "on-demand"
      }
    }
  }

  # 8. Karpenter 자동 탐색 태그 부착 (워커 노드용 기본 보안 그룹에 부착)
  node_security_group_tags = {
    "karpenter.sh/discovery" = var.cluster_name
  }
}

# =========================================================================
# 9. 서브넷 Karpenter 태그 강제 부착 (매우 중요)
# VPC는 이전에 만들어졌으므로, EKS 코드를 짤 때 기존 프라이빗 App 서브넷에 
# Karpenter가 찾아올 수 있도록 '이름표(Tag)'를 덧붙여 주는 안전장치입니다.
# =========================================================================
resource "aws_ec2_tag" "karpenter_private_subnet_tags" {
  count       = length(data.terraform_remote_state.vpc.outputs.private_subnets)
  resource_id = data.terraform_remote_state.vpc.outputs.private_subnets[count.index]
  key         = "karpenter.sh/discovery"
  value       = var.cluster_name
}