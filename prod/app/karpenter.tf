# prod/app/karpenter.tf

# ==========================================
# 1. Karpenter 권한(IAM) 및 알림(SQS) 구성 (AWS 공식 모듈)
# ==========================================
module "karpenter" {
  source  = "terraform-aws-modules/eks/aws//modules/karpenter"
  version = "~> 20.0"

  cluster_name = data.terraform_remote_state.eks.outputs.cluster_name

  # 카펜터 v1 API 권한 부여 및 최신 Pod Identity 연동
  enable_v1_permissions           = true
  enable_pod_identity             = true
  create_pod_identity_association = true

  # 카펜터가 찍어낼 EC2들이 가지게 될 신분증(IAM Role) 이름
  node_iam_role_name            = "${var.env}-karpenter-node"
  node_iam_role_use_name_prefix = false
}

# ==========================================
# 2. Karpenter 헬름(Helm) 차트 설치
# ==========================================
resource "helm_release" "karpenter" {
  namespace        = "kube-system"
  name             = "karpenter"
  repository       = "oci://public.ecr.aws/karpenter"
  chart            = "karpenter"
  version          = var.chart_version_karpenter # 사용자 지정: 1.9.0
  
  # (수정) 카펜터가 완전히 켜질 때까지 기다리도록 강제하여 다음 단계의 CRD 에러 방지
  wait             = true

  # (요청 사항 반영) 카펜터 프로그램 본체는 스팟이 아니라 안전한 '온디맨드'에 띄움
  set {
    name  = "nodeSelector.karpenter\\.sh/capacity-type"
    value = "on-demand"
  }

  set {
    name  = "settings.clusterName"
    value = data.terraform_remote_state.eks.outputs.cluster_name
  }

  set {
    name  = "settings.clusterEndpoint"
    value = data.terraform_remote_state.eks.outputs.cluster_endpoint
  }

  set {
    name  = "settings.interruptionQueue"
    value = module.karpenter.queue_name
  }

  depends_on = [module.karpenter]
}

# ==========================================
# 3. EC2NodeClass: 노드의 하드웨어 스펙 (레시피)
# ==========================================
resource "kubectl_manifest" "karpenter_node_class" {
  
  yaml_body = <<-YAML
    apiVersion: karpenter.k8s.aws/v1
    kind: EC2NodeClass
    metadata:
      name: default
    spec:
      amiFamily: AL2023
      amiSelectorTerms:
        - alias: al2023@latest

      role: "${var.env}-karpenter-node"
      
      subnetSelectorTerms:
        - tags:
            karpenter.sh/discovery: "${data.terraform_remote_state.eks.outputs.cluster_name}"
      securityGroupSelectorTerms:
        - tags:
            karpenter.sh/discovery: "${data.terraform_remote_state.eks.outputs.cluster_name}"
            
      blockDeviceMappings:
        - deviceName: /dev/xvda
          ebs:
            volumeSize: 50Gi
            volumeType: gp3
            encrypted: true
            deleteOnTermination: true
  YAML

  depends_on = [helm_release.karpenter]
}

# ==========================================
# 4. NodePool: 오토스케일링 규칙 (메뉴판)
# ==========================================
resource "kubectl_manifest" "karpenter_node_pool" {
  
  yaml_body = <<-YAML
    apiVersion: karpenter.sh/v1
    kind: NodePool
    metadata:
      name: default
    spec:
      template:
        spec:
          nodeClassRef:
            group: karpenter.k8s.aws
            kind: EC2NodeClass
            name: default
          requirements:
            # 1. 스팟과 온디맨드 모두 허용 (우선순위는 스팟)
            - key: karpenter.sh/capacity-type
              operator: In
              values: ["spot", "on-demand"]
            # 2. (요청 사항) ARM 배제, 오직 x86_64(amd64)만 허용
            - key: kubernetes.io/arch
              operator: In
              values: ["amd64"]
            # 3. (요청 사항) 비싸고 특이한 노드 배제, 범용(c, m, r, t) 패밀리만 허용
            - key: karpenter.k8s.aws/instance-family
              operator: In
              values: ["c", "m", "r", "t"]
            # 4. 구형 인스턴스(1~3세대) 배제, 4세대 이상 최신 장비만 허용
            - key: karpenter.k8s.aws/instance-generation
              operator: Gt
              values: ["4"]
              
      # (요청 사항) CPU 1000개 도달 시 무한 확장 정지 (요금 폭탄 방지)
      limits:
        cpu: 1000
        
      # (요청 사항) 노드가 텅 비면 정확히 3분(180초) 대기 후 노드 삭제
      disruption:
        consolidationPolicy: WhenEmpty
        consolidateAfter: 3m
  YAML

  depends_on = [kubectl_manifest.karpenter_node_class]
}