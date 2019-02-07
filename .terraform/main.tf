variable "AWS_ACCESS_KEY_ID" {}
variable "AWS_SECRET_ACCESS_KEY" {}
variable "APPLICATION_SERVER_ADDRESS" {}

provider "aws" {
  region = "us-east-1"
  access_key = "${var.AWS_ACCESS_KEY_ID}"
  secret_key = "${var.AWS_SECRET_ACCESS_KEY}"
}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

data "aws_route53_zone" "primary" {
  name         = "kantaros.net."
}

data "aws_vpc" "main" {
  default = true
}

resource "aws_security_group" "allow_application_ports" {
  name        = "application_allow_some"
  description = "alow some inbound traffic"
  vpc_id      = "${data.aws_vpc.main.id}"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "application" {
  ami           = "${data.aws_ami.ubuntu.id}"
  instance_type = "t2.micro"
  key_name = "Jenkins"
  vpc_security_group_ids = ["${aws_security_group.application_allow_ports.id}"]

  tags = {
    Name = "APP"
  }
}

resource "aws_eip" "application_eip" {
  instance = "${aws_instance.application.id}"
  vpc      = true
}

resource "aws_route53_record" "application_dns" {
  zone_id = "${data.aws_route53_zone.primary.zone_id}"
  name    = "${env.APPLICATION_SERVER_ADDRESS}"
  type    = "A"
  ttl     = "300"
  records = ["${aws_eip.application_eip.public_ip}"]
}
