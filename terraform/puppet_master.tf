#  Copyright 2018 1Strategy, LLC

#    Licensed under the Apache License, Version 2.0 (the "License");
#    you may not use this file except in compliance with the License.
#    You may obtain a copy of the License at

#        http://www.apache.org/licenses/LICENSE-2.0

#    Unless required by applicable law or agreed to in writing, software
#    distributed under the License is distributed on an "AS IS" BASIS,
#    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#    See the License for the specific language governing permissions and
#    limitations under the License.

##################################################################################
# PROVIDERS
##################################################################################

provider "aws" {
  access_key = "${var.aws_access_key}"
  secret_key = "${var.aws_secret_key}"
  region     = "us-west-2"
}

##################################################################################
# DATA
##################################################################################

# Amazon Machine Image - Amazon Linux AMI #

data "aws_ami" "amazon_linux_ami" {
  owners      = ["amazon"]
  most_recent = true

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-2017.12.0.20180328.1-x86_64-gp2"]
  }
}

# Master node user data template #

data "template_file" "master_userdata" {
  template = "${file("./master_userdata.tpl")}"

  vars {
    master_hostname = "${var.puppet_master_name}.${var.aws_route53_zone_name}"
    puppet_repo     = "${var.puppet_repository}"
    hosted_zone_id  = "${aws_route53_zone.puppet_zone.zone_id}"
    efs_id          = "${aws_efs_file_system.master_node_efs.id}"
    r10k_repo       = "${var.r10k_repository}"
  }
}

##################################################################################
# RESOURSES
##################################################################################

# IAM - Master Instance Profile #

resource "aws_iam_role" "puppet-master-host-role" {
  name = "puppet-master-host-role"

  assume_role_policy = <<POLICY
{
    "Version": "2012-10-17",
    "Statement": [
      {
        "Action": "sts:AssumeRole",
        "Principal": {
          "Service": "ec2.amazonaws.com"
        },
        "Effect": "Allow",
        "Sid": ""
      }
    ]
}
POLICY
}

resource "aws_iam_policy" "puppet-master-host-policy" {
  name        = "puppet-master-host-policy"
  path        = "/"
  description = "Policy to allow puppet master node to update DNS records."

  policy = <<POLICY
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "route53:AssociateVPCWithHostedZone",
                "route53:ChangeResourceRecordSets",
                "route53:ChangeTagsForResource",
                "route53:CreateHealthCheck",
                "route53:CreateHostedZone",
                "route53:ListHostedZones"
            ],
            "Resource": [
                "*"
            ]
        }
    ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "puppet_master_policy_to_role" {
  role       = "${aws_iam_role.puppet-master-host-role.name}"
  policy_arn = "${aws_iam_policy.puppet-master-host-policy.arn}"
}

resource "aws_iam_instance_profile" "puppet_master_instance_profile" {
  name = "puppet_master_instance_profile"
  role = "${aws_iam_role.puppet-master-host-role.id}"
}

# Security Group - Master Node #
resource "aws_security_group" "puppet_master_security_group" {
  vpc_id = "${var.vpc_id}"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8140
    to_port     = 8140
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Security Group - EFS #
resource "aws_security_group" "efs_security_group" {
  vpc_id = "${var.vpc_id}"

  ingress {
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Puppet Master - ASG - Launch Configuration #
resource "aws_launch_configuration" "puppet_master" {
  name_prefix                 = "puppet-master-"
  associate_public_ip_address = true
  enable_monitoring           = false

  image_id             = "${data.aws_ami.amazon_linux_ami.id}"
  instance_type        = "${var.instance_type}"
  key_name             = "${var.ec2_keypair}"
  security_groups      = ["${aws_security_group.puppet_master_security_group.id}"]
  iam_instance_profile = "${aws_iam_instance_profile.puppet_master_instance_profile.id}"
  user_data            = "${data.template_file.master_userdata.rendered}"

  lifecycle {
    create_before_destroy = true
  }
}

# Puppet Master - ASG #
resource "aws_autoscaling_group" "puppet_master_asg" {
  name_prefix          = "puppet-master"
  launch_configuration = "${aws_launch_configuration.puppet_master.name}"
  min_size             = "${var.asg_min}"
  max_size             = "${var.asg_max}"
  vpc_zone_identifier  = ["${var.vpc_subnet_id}"]

  tags = [
    {
      key                 = "Name"
      value               = "Puppet Master Server"
      propagate_at_launch = true
    },
    {
      key                 = "master_hostname"
      value               = "${var.puppet_master_name}.${var.aws_route53_zone_name}"
      propagate_at_launch = true
    },
  ]

  lifecycle {
    create_before_destroy = true
  }

  depends_on = ["aws_efs_mount_target.efs_mount_target"]
}

# EFS #
resource "aws_efs_file_system" "master_node_efs" {
  creation_token = "master_node_efs"

  tags {
    Name = "master_node_efs"
  }
}

# EFS Mount Target#
resource "aws_efs_mount_target" "efs_mount_target" {
  file_system_id  = "${aws_efs_file_system.master_node_efs.id}"
  subnet_id       = "${var.vpc_subnet_id}"
  security_groups = ["${aws_security_group.efs_security_group.id}"]
}

# Route53 #
resource "aws_route53_zone" "puppet_zone" {
  name   = "${var.aws_route53_zone_name}"
  vpc_id = "${var.vpc_id}"
}
