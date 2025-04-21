variable "region" {
  default     = "us-east-1"
  description = "Region for resources to be deployed in"
}

variable "remote_state_key" {
  description = "Path to remote state of aws-setup"
}

variable "remote_state_bucket" {
  description = "Name of bucket used for remote state in aws-setup"
}
