8ocket 인프라스트럭처 (Mindlog 프로젝트)
**개요**

목적: Mindlog 서비스 운영을 위한 AWS 클라우드 네이티브 인프라 구축 및 자동화

방식: Terraform을 활용한 선언형 인프라스트럭처 코드(IaC, Infrastructure as Code) 적용

배포: GitHub Actions를 통한 CI/CD 파이프라인 연동 및 형상 관리

**사용 기술 스택 (Tech Stack)**
| 분류 (Category) | 기술 (Technology) | 역할 및 설명 (Description) |
| :--- | :--- | :--- |
| **IaC (인프라 코드화)** | **Terraform (v1.14.0)** | 코드를 통한 인프라 자동 구축 및 형상 관리 |
| | **AWS S3 & DynamoDB** | 테라폼 상태 파일 안전 보관 및 동시 작업 충돌 방지 |
| **Cloud & Orchestration**| **AWS** | 메인 클라우드 인프라 제공 |
| | **Amazon EKS (v1.34)** | 애플리케이션(파드) 24시간 무중단 관리 및 운영 |
| | **Karpenter** | 트래픽 폭주 시 1분 내 서버(컴퓨터) 자동 추가 및 축소 |
| | **KEDA** | 대기열(작업량) 증가 시 일할 파드 자동 추가 |
| **Database & Storage** | **Amazon RDS (PostgreSQL 18)**| 고객 정보 및 서비스 핵심 데이터 영구 저장소 |
| | **Valkey (v8.2)** | 속도 향상을 위한 초고속 임시 기억 장치 (캐시) |
| | **Amazon EFS / EBS (gp3)** | 컨테이너 데이터 유실을 막기 위한 고성능 하드디스크 |
| **CI/CD & Security** | **GitHub Actions** | 인프라 구축 코드(Terraform) 자동 실행 파이프라인 |
| | **Jenkins** | 개발팀의 앱 코드를 실행 가능한 형태(이미지)로 포장 |
| | **ArgoCD** | 포장된 앱을 클라우드(EKS)에 자동으로 배포하고 유지 |
| | **External Secrets Operator**| DB 비밀번호 등 민감 정보를 안전하게 앱에 전달 |
| | **AWS WAF** | 해킹 및 악의적인 웹 트래픽 자동 차단 방화벽 |

---

**폴더 구조 (Directory Structure)**
각 폴더는 인프라 생명주기와 의존성에 따라 모듈화되어 있습니다. 배포 시 하향식(순차적)으로 실행됩니다.
```
root/terraform.
├── .github/workflows/   # CI/CD 자동 배포 스크립트 (계층별 및 전체 통합 파이프라인)
├── bootstrap/           # [최초 1회 실행] 인프라 구축의 뼈대 (S3 tfstate, DynamoDB Lock, ECR, Github OIDC)
├── prod/                # 운영(Production) 환경 테라폼 코드
│   ├── vpc/             # 네트워크 계층 (VPC, Subnet, NAT, Security Group, VPC Endpoint, EFS)
│   ├── eks/             # 컴퓨팅 계층 (EKS Cluster, Worker Node 설정)
│   ├── db/              # 데이터 계층 (RDS PostgreSQL, Valkey, S3 Photo Bucket)
│   ├── app/             # 쿠버네티스 코어 앱 (ALB Controller, ExternalDNS, Karpenter, Jenkins, ArgoCD 등)
│   └── ops/             # 운영/모니터링 계층 (Namespace 구성, New Relic License 주입)
└── README.md            # 프로젝트 개요 및 아키텍처 설명
```

**인프라 배포 파이프라인 (CI/CD)**
GitHub OIDC 기반 인증: AWS 액세스 키 노출 없이 안전한 접근 권한(AssumeRole) 획득

경로 기반 트리거(Path Filtering): prod/vpc/** 변경 시 VPC 파이프라인만 실행되는 등 독립적이고 안전한 배포 지원

Apply-All: workflow_dispatch를 통한 인프라 전체 일괄 프로비저닝 지원 (vpc ➔ eks ➔ db ➔ app ➔ ops)

Apply-**: git push 된 폴더만 개별 배포
