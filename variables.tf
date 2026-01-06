variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "eu-central-1"
}

variable "ami_id" {
  type        = string
  description = "The AMI ID for the EC2 instances"
}

variable "instance_type" {
  type        = string
  default     = "t3.micro"
}

variable "erlang_cookie" {
  type        = string
  sensitive   = true
  description = "Shared secret cookie for RabbitMQ clustering"
}

variable "ssh_key_name" {
  type        = string
  description = "The name of the SSH key pair"
}