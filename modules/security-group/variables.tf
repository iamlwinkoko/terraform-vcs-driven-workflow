variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where the security group will be created"
  type        = string
}

variable "http_cidr_block" {
  description = "CIDR block allowed to access HTTP"
  type        = string
}

variable "ssh_cidr_block" {
  description = "CIDR block allowed to access SSH"
  type        = string
  default     = null
}