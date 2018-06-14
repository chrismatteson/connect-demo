provider "aws" {
  region = "${var.aws_region}"
}

resource "random_id" "environment_name" {
  byte_length = 4
  prefix      = "${var.environment_name_prefix}-"
}

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "${random_id.environment_name.hex}"
  cidr = "10.0.0.0/16"

  azs             = ["us-west-2a", "us-west-2b", "us-west-2c"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  enable_nat_gateway = true
  enable_vpn_gateway = true

  tags = {
    Use = "connectdemo"
    Owner = "chrismatteson"
  }
}


module "consul" {
  source        = "github.com/chrismatteson/consul//terraform/aws?ref=connectbeta"
  key_name      = "${var.ssh_key_name}"
  key_path      = "${var.ssh_key_path}"
  consul_binary = "${var.consul_binary}"
  vpc_id        = "${module.vpc.vpc_id}"
  subnets       = "${zipmap(list("0", "1", "2"), module.vpc.public_subnets)}"
  region        = "${var.aws_region}"
}
