# prod/app/cicd.tf

# ==========================================
# 1. 네임스페이스(Namespace) 생성
# ==========================================
resource "kubernetes_namespace" "argocd" {
  metadata {
    name = "argocd"
  }
}

resource "kubernetes_namespace" "jenkins" {
  metadata {
    name = "jenkins"
  }
}

# ==========================================
# 2. Jenkins 영구 데이터 저장소(PVC) 생성
# ==========================================
resource "kubernetes_persistent_volume_claim" "jenkins_pvc" {
  metadata {
    name      = "jenkins-pvc"
    namespace = kubernetes_namespace.jenkins.metadata[0].name
  }
  spec {
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = "gp3" # EBS CSI 드라이버를 통한 가장 빠른 하드디스크 할당
    resources {
      requests = {
        storage = "20Gi" # Helm 삭제 시에도 데이터(빌드 캐시 등) 영구 보존
      }
    }
  }
  wait_until_bound = false

  depends_on = [helm_release.aws_ebs_csi_driver]
}

# ==========================================
# 3. Jenkins용 IAM 역할 및 ECR 접근 권한 (Pod Identity)
# ==========================================
resource "aws_iam_role" "jenkins" {
  name               = "${var.env}-jenkins-role"
  assume_role_policy = data.aws_iam_policy_document.pod_identity_trust.json
}

# Jenkins가 AWS ECR 창고에 도커 이미지를 밀어넣을 수 있도록 공식 권한 부여
resource "aws_iam_role_policy_attachment" "jenkins_ecr" {
  role       = aws_iam_role.jenkins.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser"
}

# 파드(SA)와 AWS 권한(Role)을 안전하게 연결
resource "aws_eks_pod_identity_association" "jenkins" {
  cluster_name    = data.terraform_remote_state.eks.outputs.cluster_name
  namespace       = kubernetes_namespace.jenkins.metadata[0].name
  service_account = "jenkins"
  role_arn        = aws_iam_role.jenkins.arn
}

# ==========================================
# 4. Jenkins 헬름(Helm) 차트 설치
# ==========================================
resource "helm_release" "jenkins" {
  name       = "jenkins"
  repository = "https://charts.jenkins.io"
  chart      = "jenkins"
  version    = var.chart_version_jenkins
  namespace  = kubernetes_namespace.jenkins.metadata[0].name

  timeout    = 600
  # 테라폼으로 직접 만든 분리형 20GB 디스크(PVC) 강제 연결
  
  set {
    name  = "persistence.existingClaim"
    value = kubernetes_persistent_volume_claim.jenkins_pvc.metadata[0].name
  }

  # 초기 관리자 비밀번호 주입
  set {
    name  = "controller.admin.password"
    value = var.jenkins_admin_password
  }

  # 로그 시간대 한국(KST)으로 동기화
  set {
    name  = "controller.javaOpts"
    value = "-Duser.timezone=Asia/Seoul"
  }

  # Pod Identity 권한 맵핑을 위한 SA 이름 고정
  set {
    name  = "serviceAccount.name"
    value = "jenkins"
  }

  set {
    name  = "controller.resources.requests.cpu"
    value = "250m"
  }
  set {
    name  = "controller.resources.requests.memory"
    value = "1024Mi"
  }

  # 파드가 EC2 노드를 마비시키는 것을 막기 위한 자원 한계선 설정
  set {
    name  = "controller.resources.limits.cpu"
    value = "1000m"
  }
  set {
    name  = "controller.resources.limits.memory"
    value = "2048Mi"
  }

set {
    # 테라폼 문법상 마침표(.)는 역슬래시 2개(\\)로 이스케이프해야 에러가 안 납니다.
    name  = "nodeSelector.karpenter\\.sh/capacity-type"
    value = "on-demand"
  }
  
  
  # ALB 도메인 연결을 위한 Ingress 설정
set { name = "controller.ingress.enabled", value = "true" }
  set { name = "controller.ingress.ingressClassName", value = "alb" }
  set { name = "controller.ingress.annotations.alb\\.ingress\\.kubernetes\\.io/group\\.name", value = "alb-group" }
  set { name = "controller.ingress.annotations.alb\\.ingress\\.kubernetes\\.io/scheme", value = "internet-facing" }
  set { name = "controller.ingress.annotations.alb\\.ingress\\.kubernetes\\.io/target-type", value = "ip" }
  set { name = "controller.ingress.annotations.alb\\.ingress\\.kubernetes\\.io/ssl-redirect", value = "443" }
  # 목적지 주소 설정 (결과: jenkins.mindlog.cloud)
  set { name = "controller.ingress.hostName", value = "jenkins.${var.domain_name}" }

  set { 
    name  = "controller.ingress.annotations.alb\\.ingress\\.kubernetes\\.io/certificate-arn"
    value = data.aws_acm_certificate.main.arn 
  }
  set { name = "controller.ingress.annotations.alb\\.ingress\\.kubernetes\\.io/listen-ports", value = "[{\"HTTPS\":443}, {\"HTTP\":80}]" }
  
  # WAF 방화벽 연동
  set { 
    name  = "controller.ingress.annotations.alb\\.ingress\\.kubernetes\\.io/wafv2-acl-arn" 
    value = aws_wafv2_web_acl.main.arn 
  }

  depends_on = [
    helm_release.aws_lbc,
    helm_release.aws_ebs_csi_driver
  ]
}

# ==========================================
# 5. ArgoCD 헬름(Helm) 차트 설치
# ==========================================
resource "helm_release" "argocd" {
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = var.chart_version_argocd
  namespace  = kubernetes_namespace.argocd.metadata[0].name

  # 관리자 초기 비밀번호 주입 (bcrypt 암호화 필수)
  set {
    name  = "configs.secret.argocdServerAdminPassword"
    value = bcrypt(var.argocd_admin_password)
  }

set {
    name  = "nodeSelector.karpenter\\.sh/capacity-type"
    value = "on-demand"
  }

  set {
    name  = "configs.cm.resource\\.customizations\\.ignoreDifferences\\.apps_Deployment"
    value = "jqPathExpressions:\n- .spec.replicas"
  }
  
  set {
    name  = "configs.cm.resource\\.customizations\\.ignoreDifferences\\.apps_StatefulSet"
    value = "jqPathExpressions:\n- .spec.replicas"
  }


  # ALB 도메인 연결을 위한 Ingress 설정
set { name = "server.ingress.enabled", value = "true" }
  set { name = "server.ingress.ingressClassName", value = "alb" }
  set { name = "server.ingress.annotations.alb\\.ingress\\.kubernetes\\.io/group\\.name", value = "alb-group" }
  set { name = "server.ingress.annotations.alb\\.ingress\\.kubernetes\\.io/scheme", value = "internet-facing" }
  set { name = "server.ingress.annotations.alb\\.ingress\\.kubernetes\\.io/target-type", value = "ip" }
  

  set { name = "server.ingress.annotations.alb\\.ingress\\.kubernetes\\.io/ssl-redirect", value = "443" }
  set { name = "server.ingress.annotations.alb\\.ingress\\.kubernetes\\.io/backend-protocol", value = "HTTPS" }
  
  set { name = "server.ingress.hosts[0]", value = "argocd.${var.domain_name}" }

  # ACM 인증서 동적 연결
  set { 
    name  = "server.ingress.annotations.alb\\.ingress\\.kubernetes\\.io/certificate-arn"
    value = data.aws_acm_certificate.main.arn 
  }
  set { name = "server.ingress.annotations.alb\\.ingress\\.kubernetes\\.io/listen-ports", value = "[{\"HTTPS\":443}, {\"HTTP\":80}]" }
  
  # WAF 방화벽 연동
  set { 
    name  = "server.ingress.annotations.alb\\.ingress\\.kubernetes\\.io/wafv2-acl-arn" 
    value = aws_wafv2_web_acl.main.arn 
  }

  depends_on = [helm_release.aws_lbc]
