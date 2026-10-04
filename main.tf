data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

module "network" {
  source = "./modules/network"

  project_name       = var.project_name
  vpc_cidr           = var.vpc_cidr
  public_subnet_cidr = var.public_subnet_cidr
  availability_zone  = var.availability_zone
}

module "security_group" {
  source = "./modules/security-group"

  project_name = var.project_name
  vpc_id       = module.network.vpc_id

  http_cidr_blocks = ["0.0.0.0/0"]
  ssh_cidr_blocks  = var.ssh_cidr_blocks
}

module "compute" {
  source = "./modules/compute"

  project_name  = var.project_name
  ami_id        = data.aws_ami.amazon_linux.id
  instance_type = var.instance_type

  subnet_id = module.network.public_subnet_id

  security_group_ids = [
    module.security_group.security_group_id
  ]
}