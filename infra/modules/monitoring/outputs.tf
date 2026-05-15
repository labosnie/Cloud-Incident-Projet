output "sns_topic_arn" {
  description = "ARN du topic SNS des alertes."
  value       = aws_sns_topic.alerts.arn
}

output "sns_topic_name" {
  description = "Nom du topic SNS des alertes."
  value       = aws_sns_topic.alerts.name
}

output "alarm_5xx_name" {
  description = "Nom de alarme CloudWatch 5XX cible."
  value       = aws_cloudwatch_metric_alarm.target_5xx.alarm_name
}

output "alarm_latency_name" {
  description = "Nom de alarme CloudWatch latence cible."
  value       = aws_cloudwatch_metric_alarm.target_latency.alarm_name
}
