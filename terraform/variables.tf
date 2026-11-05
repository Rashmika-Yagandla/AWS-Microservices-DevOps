variable "aws_region" {
  type    = string
  default = "ap-south-1"
}

variable "project_name" {
  type    = string
  default = "microservices-devops"
}

variable "instance_type" {
  type    = string
  default = "t3.small"
}

variable "key_pair_name" {
  type        = string
  description = "Existing EC2 key pair name"
}

variable "allowed_ssh_cidr" {
  type        = string
  description = "Your public IP in CIDR format, e.g. 203.0.113.10/32"
  validation {
    condition     = can(cidrhost(var.allowed_ssh_cidr, 0))
    error_message = "Provide a valid CIDR block. Restrict SSH to your IP (/32)."
  }
}

variable "root_volume_size" {
  type    = number
  default = 20
}
