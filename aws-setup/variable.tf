variable "region" {
  default     = "us-east-1"
  description = "Region for resources to be deployed in"
}

variable "min_node_group_size" {
  default     = 1
  description = "Minimum node size of control node group."
}

variable "max_node_group_size" {
  default     = 5
  description = "Maximum node size of control node group."
}

variable "node_type" {
  default     = "t3.medium"
  description = "EC2 type for nodes in control node group"
}
