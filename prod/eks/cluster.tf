# prod/eks/cluster.tf

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  # 1. VPC 및 서브넷 위치 지정
  vpc_id                   = data.terraform_remote_state.vpc.outputs.vpc_id
  subnet_ids               = data.terraform_remote_state.vpc.outputs.private_subnets
  control_plane_subnet_ids = data.terraform_remote_state.vpc.outputs.private_subnets

  # 2. 클러스터 엔드포인트 제어
  cluster_endpoint_public_access       = true
  cluster_endpoint_public_access_cidrs = var.cluster_endpoint_public_access_cidrs
  cluster_endpoint_private_access      = true

  # 3. 최신 AWS API 기반의 권한 부여 (Access Entry)
  authentication_mode                      = "API"
  enable_cluster_creator_admin_permissions = true

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

  # 4. 필수 시스템 애드온 (파드 개수 제한 해제용 vpc-cni 설정 포함)
  cluster_addons = {
    vpc-cni = { 
      most_recent = true
      configuration_values = jsonencode({
        env = {
          ENABLE_PREFIX_DELEGATION = "true"
          WARM_PREFIX_TARGET       = "1"
        }
      })
    }
    coredns                = { most_recent = true }
    kube-proxy             = { most_recent = true }
    eks-pod-identity-agent = { most_recent = true }
  }

  # 5. 마스터 노드 감사 로그 켜기
  cluster_enabled_log_types = ["api", "authenticator"]

  # 6. OIDC 공급자 활성화
  enable_irsa = true

  # 7. 시스템 파드가 올라갈 3대의 고정 워커 노드 (AL2023 적용)
  eks_managed_node_groups = {
    mindlog_nodes = {
      min_size       = 1
      max_size       = 3
      desired_size   = var.mng_desired_size
      instance_types = var.mng_instance_types
      capacity_type  = var.mng_capacity_type
      
      # (핵심) 구형 AL2 대신 신형 AL2023 강제 지정
      ami_type       = "AL2023_x86_64_STANDARD"

      labels = {
        "karpenter.sh/capacity-type" = "on-demand"
      }

      # (핵심) AL2023 전용 Kubelet YAML 설정 주입 방식으로 최대 파드 110개 허용
      cloudinit_pre_nodeadm = [
        {
          content_type = "application/node.eks.aws"
          content      = <<-EOT
            ---
            apiVersion: node.eks.aws/v1alpha1
            kind: NodeConfig
            spec:
              kubelet:
                config:
                  maxPods: 110
          EOT
        }
      ]
    }
  }

  # 8. Karpenter 자동 탐색 태그 부착 (워커 노드용 기본 보안 그룹에 부착)
  node_security_group_tags = {
    "karpenter.sh/discovery" = var.cluster_name
  }
}

# =========================================================================
# 9. 서브넷 Karpenter 태그 강제 부착 (매우 중요)
# =========================================================================
resource "aws_ec2_tag" "karpenter_private_subnet_tags" {
  count       = length(data.terraform_remote_state.vpc.outputs.private_subnets)
  resource_id = data.terraform_remote_state.vpc.outputs.private_subnets[count.index]
  key         = "karpenter.sh/discovery"
  value       = var.cluster_name
}