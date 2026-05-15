variable "name_prefix" {
  description = "Prefixe pour nommer topic SNS et alarmes CloudWatch."
  type        = string
}

variable "alb_arn_suffix" {
  description = "Suffixe dimension LoadBalancer (exemple app/nom/id)."
  type        = string
}

variable "target_group_arn_suffix" {
  description = "Suffixe dimension TargetGroup incluant le prefixe targetgroup/ (exemple targetgroup/nom/id)."
  type        = string
}

variable "alert_email" {
  description = "Adresse email qui recevra les alertes SNS (confirmation manuelle requise)."
  type        = string
}

variable "http_5xx_threshold" {
  description = "Seuil alarme 5XX cible (somme sur la periode)."
  type        = number
  default     = 1
}

variable "latency_threshold_seconds" {
  description = "Seuil alarme latence cible en secondes (moyenne TargetResponseTime)."
  type        = number
  default     = 3
}

variable "alarm_period_seconds" {
  description = "Periode en secondes pour chaque datapoint des alarmes."
  type        = number
  default     = 60
}

variable "alarm_evaluation_periods" {
  description = "Nombre de periodes consecutives au-dessus du seuil avant ALARM."
  type        = number
  default     = 2
}
