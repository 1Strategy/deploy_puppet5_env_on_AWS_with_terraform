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
  default     = "https://yum.puppet.com/puppet5/puppet5-release-el-7.noarch.rpm"
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
  default     = "t2.medium"
  description = "The instance type of the puppet node instance."
}

variable "aws_route53_zone_name" {
  type        = "string"
  default     = "private"
  description = "Name of the route53 zone."
}

variable "puppet_master_name" {
  type        = "string"
  default     = "puppet.master"
  description = "Name of the route53 zone."
}

variable "node_count" {
  type        = "string"
  default     = "1"
  description = "The number of puppet nodes you want to launch."
}

variable "asg_min" {
  type        = "string"
  default     = "1"
  description = "Minimum number of nodes in the Auto-Scaling Group"
}

variable "asg_max" {
  type        = "string"
  default     = "1"
  description = "Minimum number of nodes in the Auto-Scaling Group"
}

variable "r10k_repository" {
  type        = "string"
  description = "URL of the r10k control repository"
}
