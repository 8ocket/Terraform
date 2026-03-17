# prod/db/data.tf

# ==========================================
# 1. VPC 인프라 결과물(상태 파일) 불러오기
# ==========================================
# 테라폼 원격 상태(remote_state) 기능을 사용하여 이전 작업의 결과물을 가져옵니다.
data "terraform_remote_state" "vpc" {
  # 읽어올 상태 파일이 저장된 방식이 S3임을 명시합니다.
  backend = "s3"

  # S3 금고에 접근하기 위한 정확한 주소와 열쇠 정보를 설정합니다.
  config = {
    # VPC 상태 파일이 보관된 S3 버킷의 이름입니다.
    bucket = "8ocket-tfstate-s3"
    # (매우 중요) vpc 폴더에서 저장했던 정확한 파일 경로(Key)입니다.
    key    = "prod/vpc/terraform.tfstate"
    # 해당 S3 버킷이 위치한 서울 리전을 명시합니다.
    region = "ap-northeast-2"
  }
}