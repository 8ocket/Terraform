# prod/db/data.tf

# ==========================================
data "terraform_remote_state" "vpc" {
  backend = "s3"

  config = {
    bucket = "8ocket-tfstate-s3"
    key    = "prod/vpc/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

data "terraform_remote_state" "eks" {
  backend = "s3"
  config = {
    bucket = "8ocket-tfstate-s3"
    key    = "prod/eks/terraform.tfstate"
    region = "ap-northeast-2"
  }
}