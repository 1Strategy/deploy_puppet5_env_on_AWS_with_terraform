##################################################################################
# DATA
##################################################################################

## Agent node user data template ##
data "template_file" "node_userdata" {
  template = "${file("./node_userdata.tpl")}"

  vars {
    master_hostname = "${var.puppet_master_name}.${var.aws_route53_zone_name}"
    puppet_repo     = "${var.puppet_repository}"
  }
}

##################################################################################
# RESOURCES
##################################################################################

# Security Group #
resource "aws_security_group" "puppet_node_security_group" {
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

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Agent Node - EC2 Instance #
resource "aws_instance" "puppet_agent_node" {
  # ami                         = "${data.aws_ami.amazon_linux_ami.id}"
  ami                         = "ami-223f945a"
  instance_type               = "${var.instance_type}"
  security_groups             = ["${aws_security_group.puppet_node_security_group.id}"]
  subnet_id                   = "${var.vpc_subnet_id}"
  associate_public_ip_address = true
  monitoring                  = false
  key_name                    = "${var.ec2_keypair}"
  user_data                   = "${data.template_file.node_userdata.rendered}"

  tags {
    Name      = "Puppet Agent Node"
    PP_Master = "${var.puppet_master_name}.${var.aws_route53_zone_name}"
  }

  depends_on = ["aws_autoscaling_group.puppet_master_asg"]
  count      = "${var.node_count}"
}
