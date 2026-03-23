# prod/app/waf.tf

resource "aws_wafv2_web_acl" "main" {
  name        = "prod-waf-8ocket"
  description = "콘솔 관리용 WAF"
  scope       = "REGIONAL" # ALB에 붙일 것이므로 리전(Regional)으로 고정

  # 기본적으로 모든 트래픽을 통과시킴 (콘솔에서 변경 가능)
  default_action {
    allow {}
  }

  # CloudWatch 지표 수집 설정 (API 필수 요구사항)
  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "prod-waf-8ocket-metrics"
    sampled_requests_enabled   = true
  }


  # 보안팀이 콘솔에서 추가한 룰을 테라폼이 지우지 못하도록 강제 방어
  
  lifecycle {
    ignore_changes = [
      rule,
      default_action,
      visibility_config
    ]
  }
}