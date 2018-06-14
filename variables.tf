variable "environment_name_prefix" {
  default     = "connectdemo"
  description = "Environment Name prefix eg my-hashistack-env"
}

variable "aws_region" {
  default     = "us-west-2"
  description = "Region where resources will be provisioned"
}

variable "ssh_key_name" {
  description = "Name of SSH key to use"
}

variable "ssh_key_path" {
  description = "Path to SSH key"
}

variable "consul_binary" {
  description = "Path to consul binary to install"
}
