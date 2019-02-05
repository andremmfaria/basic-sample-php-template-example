provider "aws" {
  region = "us-east-1"
}

/*
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

resource "aws_instance" "web" {
  ami           = "${data.aws_ami.ubuntu.id}"
  instance_type = "t2.micro"

  tags = {
    Name = "HelloWorld"
  }
}
*/

data "aws_route53_zone" "primary" {
  name         = "kantaros.net."
}

data "aws_vpc" "main" {
  default = true
}

resource "aws_security_group" "allow_ports" {
  name        = "allow_some"
  description = "alow some inbound traffic"
  vpc_id      = "${data.aws_vpc.main.id}"

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 8081
    to_port     = 8081
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 9000
    to_port     = 9000
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

resource "aws_instance" "jenkins" {
  ami           = "ami-09027a8175c03b7fe"
  instance_type = "t2.medium"
  vpc_security_group_ids = ["${aws_security_group.allow_ports.id}"]

  tags = {
    Name = "Jenkins"
  }
}

resource "aws_eip" "jenkins_eip" {
  instance = "${aws_instance.jenkins.id}"
  vpc      = true
}

resource "aws_route53_record" "jenkins_dns" {
  zone_id = "${data.aws_route53_zone.primary.zone_id}"
  name    = "jenkins.kantaros.net"
  type    = "A"
  ttl     = "300"
  records = ["${aws_eip.jenkins_eip.public_ip}"]
}

resource "aws_instance" "nexus" {
  ami           = "ami-060c0f2bf286ccd33"
  instance_type = "t2.micro"
  vpc_security_group_ids = ["${aws_security_group.allow_ports.id}"]

  tags = {
    Name = "Nexus"
  }
}

resource "aws_eip" "nexus_eip" {
  instance = "${aws_instance.nexus.id}"
  vpc      = true
}

resource "aws_route53_record" "nexus_dns" {
  zone_id = "${data.aws_route53_zone.primary.zone_id}"
  name    = "nexus.kantaros.net"
  type    = "A"
  ttl     = "300"
  records = ["${aws_eip.nexus_eip.public_ip}"]
}

resource "aws_instance" "sonar" {
  ami           = "ami-049cfb03fef34ec2d"
  instance_type = "t2.small"
  vpc_security_group_ids = ["${aws_security_group.allow_ports.id}"]

  tags = {
    Name = "Sonar"
  }
}

resource "aws_eip" "sonar_eip" {
  instance = "${aws_instance.sonar.id}"
  vpc      = true
}

resource "aws_route53_record" "sonar_dns" {
  zone_id = "${data.aws_route53_zone.primary.zone_id}"
  name    = "sonar.kantaros.net"
  type    = "A"
  ttl     = "300"
  records = ["${aws_eip.sonar_eip.public_ip}"]
}
