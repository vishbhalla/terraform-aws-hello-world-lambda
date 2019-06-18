variable "terraform_state" {
  description = "Terraform backend state setup for S3"
  type        = "map"
  default     = {}
}

variable "region" {
  description = "region"
  type        = "string"
  default     = "eu-west-1"
}
