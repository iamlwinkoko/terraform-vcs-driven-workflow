variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where the security group will be created"
  type        = string
}

variable "ssh_cidr_blocks" {
  description = "CIDR blocks allowed to access SSH"
  type        = list(string)
  default     = []
}

variable "http_cidr_blocks" {
  description = "CIDR blocks allowed to access HTTP"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}