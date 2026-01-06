provider "aws" {
    region = var.aws_region
}

module "networking" {
  source = "./modules/vpc-network"
}

module "RabbitMQ-Cluster" {
    source = "./modules/ec2-RabbitMQ"

    vpc_id             = module.networking.vpc_id
    alb_sg_id          = module.RabbitMQ-Cluster.alb_sg_id
    private_subnet_ids = module.networking.private_subnets
    public_subnet_ids  = module.networking.public_subnets

    ami_id        = var.ami_id
    instance_type = var.instance_type
    node_count    = 3
    ssh_key_name  = var.ssh_key_name
    erlang_cookie = var.erlang_cookie

    common_tags = {
    Project     = "RabbitMQ-Assignment"
    Environment = "Dev"
  }
}
