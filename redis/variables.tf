variable "cf_org_name" {
  type        = string
  description = "cloud.gov organization name"
}

variable "cf_space_name" {
  type        = string
  description = "cloud.gov space name (staging or prod)"
}

variable "name" {
  type        = string
  description = "name for the redis service instance"
}

variable "redis_plan_name" {
  type        = string
  description = "name of the service plan name to create"
}

variable "tags" {
  description = "A list of tags to add to the resource"
  type        = list(string)
  default     = []
}

variable "json_params" {
  description = "A JSON string of arbitrary parameters"
  type        = string
  default     = null
  # See options at https://cloud.gov/docs/services/aws-elasticache/#setting-optional-parameters
}
