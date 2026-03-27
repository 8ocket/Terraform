# prod/app/alb_dns_csi.tf


# 공통: Pod Identity용 신뢰 정책 (Trust Policy)

data "aws_iam_policy_document" "pod_identity_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole", "sts:TagSession"]
    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }
  }
}


# 1. AWS Load Balancer Controller

resource "kubernetes_namespace" "alb" {
  metadata { name = "alb" }
}

# (Best Practice) ALB 공식 IAM 정책 JSON을 깃허브에서 실시간으로 다운로드합니다.
data "http" "alb_iam_policy" {
  url = "https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/main/docs/install/iam_policy.json"
}

resource "aws_iam_policy" "alb" {
  name   = "${var.env}-alb-controller-policy"
  policy = data.http.alb_iam_policy.response_body
}

resource "aws_iam_role" "alb" {
  name               = "${var.env}-alb-controller-role"
  assume_role_policy = data.aws_iam_policy_document.pod_identity_trust.json
}

resource "aws_iam_role_policy_attachment" "alb" {
  role       = aws_iam_role.alb.name
  policy_arn = aws_iam_policy.alb.arn
}

resource "aws_eks_pod_identity_association" "alb" {
  cluster_name    = data.terraform_remote_state.eks.outputs.cluster_name
  namespace       = kubernetes_namespace.alb.metadata[0].name
  service_account = "aws-load-balancer-controller"
  role_arn        = aws_iam_role.alb.arn
}

resource "helm_release" "aws_lbc" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  version    = var.chart_version_aws_lbc
  namespace  = kubernetes_namespace.alb.metadata[0].name
  timeout    = 600

  set {
    name  = "clusterName"
    value = data.terraform_remote_state.eks.outputs.cluster_name
  }
  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }
  set {
    name  = "vpcId"
    value = data.terraform_remote_state.vpc.outputs.vpc_id
  }
  set {
    name  = "region"
    value = data.aws_region.current.name
  }
}


# 2. ExternalDNS

resource "kubernetes_namespace" "externaldns" {
  metadata { name = "externaldns" }
}

data "aws_iam_policy_document" "externaldns" {
  statement {
    effect    = "Allow"
    actions   = ["route53:ChangeResourceRecordSets"]
    resources = ["arn:aws:route53:::hostedzone/*"] # 모든 도메인 제어 허용
  }
  statement {
    effect    = "Allow"
    actions   = ["route53:ListHostedZones", "route53:ListResourceRecordSets", "route53:ListTagsForResource"]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "externaldns" {
  name   = "${var.env}-externaldns-policy"
  policy = data.aws_iam_policy_document.externaldns.json
}

resource "aws_iam_role" "externaldns" {
  name               = "${var.env}-externaldns-role"
  assume_role_policy = data.aws_iam_policy_document.pod_identity_trust.json
}

resource "aws_iam_role_policy_attachment" "externaldns" {
  role       = aws_iam_role.externaldns.name
  policy_arn = aws_iam_policy.externaldns.arn
}

resource "aws_eks_pod_identity_association" "externaldns" {
  cluster_name    = data.terraform_remote_state.eks.outputs.cluster_name
  namespace       = kubernetes_namespace.externaldns.metadata[0].name
  service_account = "external-dns"
  role_arn        = aws_iam_role.externaldns.arn
}

resource "helm_release" "external_dns" {
  name       = "external-dns"
  repository = "https://kubernetes-sigs.github.io/external-dns/"
  chart      = "external-dns"
  version    = var.chart_version_external_dns
  namespace  = kubernetes_namespace.externaldns.metadata[0].name
  timeout    = 600

  set {
    name  = "serviceAccount.name"
    value = "external-dns"
  }
  set {
    name  = "provider"
    value = "aws"
  }
  set {
    name  = "txtOwnerId"
    value = data.terraform_remote_state.eks.outputs.cluster_name
  }
}


# 3. EBS CSI Driver & 기본 gp3 설정

resource "kubernetes_namespace" "csi_driver" {
  metadata { name = "csi-driver" }
}

resource "aws_iam_role" "ebs_csi" {
  name               = "${var.env}-ebs-csi-role"
  assume_role_policy = data.aws_iam_policy_document.pod_identity_trust.json
}

resource "aws_iam_role_policy_attachment" "ebs_csi_base" {
  role       = aws_iam_role.ebs_csi.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

# (추후 적용) 디스크 암호화를 위한 KMS 권한이 필요할 경우 주석을 해제하세요.
/*
resource "aws_iam_policy" "ebs_csi_kms" {
  name   = "${var.env}-ebs-csi-kms-policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["kms:CreateGrant", "kms:ListGrants", "kms:RevokeGrant", "kms:Encrypt", "kms:Decrypt", "kms:GenerateDataKeyWithoutPlaintext"]
      Resource = "*" # 특정 KMS Key ARN으로 제한하는 것이 좋습니다.
    }]
  })
}
resource "aws_iam_role_policy_attachment" "ebs_csi_kms" {
  role       = aws_iam_role.ebs_csi.name
  policy_arn = aws_iam_policy.ebs_csi_kms.arn
}
*/

resource "aws_eks_pod_identity_association" "ebs_csi" {
  cluster_name    = data.terraform_remote_state.eks.outputs.cluster_name
  namespace       = kubernetes_namespace.csi_driver.metadata[0].name
  service_account = "ebs-csi-controller-sa"
  role_arn        = aws_iam_role.ebs_csi.arn
}

resource "helm_release" "aws_ebs_csi_driver" {
  name       = "aws-ebs-csi-driver"
  repository = "https://kubernetes-sigs.github.io/aws-ebs-csi-driver"
  chart      = "aws-ebs-csi-driver"
  version    = var.chart_version_ebs_csi
  namespace  = kubernetes_namespace.csi_driver.metadata[0].name
  timeout    = 600

  set {
    name  = "controller.serviceAccount.name"
    value = "ebs-csi-controller-sa"
  }
}

# 파드가 디스크를 요청할 때 자동으로 가장 빠르고 저렴한 gp3가 물리도록 기본값으로 덮어씌웁니다.
resource "kubernetes_storage_class" "gp3" {
  metadata {
    name = "gp3"
    annotations = {
      "storageclass.kubernetes.io/is-default-class" = "true"
    }
  }
  storage_provisioner = "ebs.csi.aws.com"
  volume_binding_mode = "WaitForFirstConsumer"
  parameters = {
    type      = "gp3"
    fsType    = "ext4"
    encrypted = "true"
  }
  
  # csi 드라이버가 완전히 설치된 이후에 생성되도록 의존성을 부여합니다.
  depends_on = [helm_release.aws_ebs_csi_driver]
}

# 4. AWS EFS CSI Driver & 동적 프로비저닝 스토리지 클래스

resource "kubernetes_namespace" "efs_csi_driver" {
  metadata { name = "efs-csi-driver" }
}

resource "aws_iam_role" "efs_csi" {
  name               = "${var.env}-efs-csi-role"
  assume_role_policy = data.aws_iam_policy_document.pod_identity_trust.json
}

# EFS 제어를 위한 AWS 공식 관리형 정책 연결
resource "aws_iam_role_policy_attachment" "efs_csi_base" {
  role       = aws_iam_role.efs_csi.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEFSCSIDriverPolicy"
}

resource "aws_eks_pod_identity_association" "efs_csi" {
  cluster_name    = data.terraform_remote_state.eks.outputs.cluster_name
  namespace       = kubernetes_namespace.efs_csi_driver.metadata[0].name
  service_account = "efs-csi-controller-sa"
  role_arn        = aws_iam_role.efs_csi.arn
}

resource "helm_release" "aws_efs_csi_driver" {
  name       = "aws-efs-csi-driver"
  repository = "https://kubernetes-sigs.github.io/aws-efs-csi-driver/"
  chart      = "aws-efs-csi-driver"
  version    = "3.0.3"
  namespace  = kubernetes_namespace.efs_csi_driver.metadata[0].name
  timeout    = 600

  set {
    name  = "controller.serviceAccount.name"
    value = "efs-csi-controller-sa"
  }
}

# 파드가 EFS를 요청(PVC)하면 자동으로 하위 폴더(Access Point)를 쪼개서 생성해주는 규칙
resource "kubernetes_storage_class" "efs" {
  metadata {
    name = "efs"
  }
  storage_provisioner = "efs.csi.aws.com"
  
  parameters = {
    provisioningMode = "efs-ap"
    # VPC 계층에서 만들어진 EFS ID를 상태 파일에서 동적으로 참조합니다.
    fileSystemId     = data.terraform_remote_state.vpc.outputs.efs_id
    directoryPerms   = "700"
  }

  # 드라이버(통역사)가 먼저 설치된 후에 스토리지 클래스가 만들어지도록 순서 강제
  depends_on = [helm_release.aws_efs_csi_driver]
}