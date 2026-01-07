variable "vpc_id" {
  type        = string
}

variable "nat_gateway_id" {
  type        = string
}

variable "private_subnet_ids" {
  type        = list(string)
}

variable "public_subnet_ids" {
  type        = list(string)
}

variable "ami_id" {
  type        = string
}

variable "instance_type" {
  type    = string
  default = "t3.micro"
}

variable "node_count" {
  type    = number
  default = 3
}

variable "erlang_cookie" {
  type      = string
  sensitive = true
}

variable "ssh_key_name" {
  type        = string
}

variable "alb_sg_id" {
  description = "The ID of the Security Group for the Load Balancer"
  type        = string
}

variable "common_tags" {
  type = map(string)
}
