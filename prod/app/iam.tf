# ---------------------------------------------------------
# 1. S3 특정 버킷 접근 권한(Policy) 정의
# ---------------------------------------------------------
resource "aws_iam_policy" "s3_access_policy" {
  name         = "8ocket-s3-backend-photos-policy"
  description  = "Specific access to 8ocket-backend-photos-prod bucket"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:ListBucket",
          "s3:DeleteObject"
        ]
        Resource = [
          "arn:aws:s3:::8ocket-backend-photos-prod",       
          "arn:aws:s3:::8ocket-backend-photos-prod/*"         
        ]
      }
    ]
  })
}

# ---------------------------------------------------------
# 2. 파드가 사용할 IAM 역할(Role) 생성
# ---------------------------------------------------------
resource "aws_iam_role" "pod_identity_role" {
  name = "8ocket-backend-s3-role"


  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "pods.eks.amazonaws.com"
        }
        Action = [
          "sts:AssumeRole",
          "sts:TagSession"
        ]
      }
    ]
  })
}

# 역할을 권한(Policy)과 연결
resource "aws_iam_role_policy_attachment" "s3_attach" {
  policy_arn = aws_iam_policy.s3_access_policy.arn
  role       = aws_iam_role.pod_identity_role.name
}

# ---------------------------------------------------------
# 3. EKS Pod Identity Association (연결 고리)
# ---------------------------------------------------------
resource "aws_eks_pod_identity_association" "be_s3_association" {
  cluster_name    = data.terraform_remote_state.eks.outputs.cluster_name 
  namespace       = "default"                                          
  service_account = "mindlog-be-sa"                                    
  role_arn        = aws_iam_role.pod_identity_role.arn                
}