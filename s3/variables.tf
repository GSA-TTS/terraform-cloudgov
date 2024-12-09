variable "cf_space_id" {
  type        = string
  description = "cloud.gov space id"
}

variable "name" {
  type        = string
  description = "name of the cloud.gov service instance"
}

variable "s3_plan_name" {
  type        = string
  description = "service plan to use"
  default     = "basic"
  # See options at https://cloud.gov/docs/services/s3/#plans
}

variable "tags" {
  description = "A list of tags to add to the resource"
  type        = set(string)
  default     = []
}

variable "json_params" {
  description = "A JSON string of arbitrary parameters"
  type        = string
  default     = null
  # See options at https://cloud.gov/docs/services/s3/#setting-optional-parameters
}
