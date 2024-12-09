variable "cf_space_id" {
  type        = string
  description = "cloud.gov space GUID"
}

variable "name" {
  type        = string
  description = "Name of the database service instance"
}

variable "rds_plan_name" {
  type        = string
  description = "service plan to use"
  # See options at https://cloud.gov/docs/services/relational-database/#plans
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
  # See options at https://cloud.gov/docs/services/relational-database/#setting-optional-parameters-1
}
