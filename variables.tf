variable "project_name" {
  description = "Project name"
  type        = string
  default     = "terraform-vcs"
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-northeast-1"
}

variable "availability_zone" {
  description = "AWS availability zone"
  type        = string
  default     = "ap-northeast-1a"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR block for public subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "ssh_cidr_block" {
  description = "CIDR block permitted to access SSH"
  type        = string
  default     = null
}

variable "allowed_http_cidr_block" {
  description = "CIDR block permitted to access HTTP"
  type        = string
  default     = "10.0.0.0/8"
}