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

#  enable_nat_gateway = true
#  enable_vpn_gateway = true

  tags = {
    Use = "connectdemo"
    Owner = "chrismatteson"
  }
}

module "vpc2" {
  source = "terraform-aws-modules/vpc/aws"

  name = "${random_id.environment_name.hex}"
  cidr = "172.16.0.0/16"

  azs             = ["us-west-2a", "us-west-2b", "us-west-2c"]
  private_subnets = ["172.16.1.0/24", "172.16.2.0/24", "172.16.3.0/24"]
  public_subnets  = ["172.16.101.0/24", "172.16.102.0/24", "172.16.103.0/24"]

#  enable_nat_gateway = true
#  enable_vpn_gateway = true

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

resource "aws_instance" "client" {
    ami = "ami-ecc63a94"
    instance_type = "t2.micro"
    key_name = "${var.ssh_key_name}"
    count = "3"
    security_groups = ["${aws_security_group.clients.id}"]
    subnet_id =  "${lookup(zipmap(list("0", "1", "2"), module.vpc2.public_subnets), count.index % 3)}"

    connection {
        user = "ubuntu"
        private_key = "${file("${var.ssh_key_path}")}"
    }

    #Instance tags
    tags {
        Name = "connect-client-${count.index}"
        ConsulRole = "Client"
    }

    provisioner "file" {
        source = "scripts/consul.service"
        destination = "/tmp/consul.service"
    }

    provisioner "remote-exec" {
        inline = [
            "echo ${module.consul.server_address} > /tmp/consul-server-addr",
            "cd /tmp; wget ${var.consul_binary} -O consul.zip --quiet"
        ]
    }

    provisioner "remote-exec" {
        scripts = [
            "scripts/install.sh",
            "scripts/service.sh",
            "scripts/ip_tables.sh",
        ]
    }
}

resource "aws_security_group" "clients" {
    name = "consul_${random_id.environment_name.hex}"
    description = "Consul internal traffic + maintenance."
    vpc_id = "${module.vpc2.vpc_id}"

    // These are for internal traffic
    ingress {
        from_port = 0
        to_port = 65535
        protocol = "tcp"
        self = true
    }

    ingress {
        from_port = 0
        to_port = 65535
        protocol = "udp"
        self = true
    }

    // These are for maintenance
    ingress {
        from_port = 22
        to_port = 22
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    // These are for consul
    ingress {
        from_port = 8300
        to_port = 8301
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    // This is for outbound internet access
    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
}

