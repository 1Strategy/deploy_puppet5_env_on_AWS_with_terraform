##################################################################################
# VARIABLES
##################################################################################

variable "aws_access_key" {
  type        = "string"
  description = "Access key of the aws user."
}

variable "aws_secret_key" {
  type        = "string"
  description = "Secret access key of the aws user."
}

variable "puppet_repository" {
  type        = "string"
  description = "The puppet repository of open source Puppet 5-compatible software packages."
}

variable "vpc_id" {
  type        = "string"
  description = "Create puppet nodes in this AWS VPC."
}

variable "vpc_subnet_id" {
  type        = "string"
  description = "Puppet nodes will be placed into this subnet."
}

variable "ec2_keypair" {
  type        = "string"
  description = "Access puppet nodes via SSH with this AWS EC2 keypair name."
}

variable "instance_type" {
  type        = "string"
  description = "The instance type of the puppet node instance."
}

variable "s3_bucket_configurations" {
  type        = "string"
  description = "S3 bucket which is used to store puppet configurations."
}

variable "ebs_disk_size" {
  type        = "string"
  description = "Size of the puppet master ebs volume."
}

variable "aws_route53_zone_name" {
  type        = "string"
  default     = "private"
  description = "Name of the route53 zone."
}

variable "puppet_master_name" {
  type        = "string"
  description = "Name of the route53 zone."
}

variable "node_count" {
  type        = "string"
  description = "The number of puppet nodes you want to launch."
}

variable "asg_min" {
  type        = "string"
  description = "Minimum number of nodes in the Auto-Scaling Group"
}

variable "asg_max" {
  type        = "string"
  description = "Minimum number of nodes in the Auto-Scaling Group"
}
