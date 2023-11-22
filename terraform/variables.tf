variable "aws_region" {
  default     = "us-east-1"
  description = "The AWS region name in which the main infrastructure should be deployed."
  type        = string
}

variable "aws_replication_region" {
  default     = "us-west-2"
  description = "The AWS replication region where resources are provisioned for failover."
  type        = string
}

variable "vpc_cidr_index" {
  default = 0
  description = "The number of the second CIDR IP address segment to act as an index for multiple environment support. The default CIDR range is 10.0.0.0/16, so setting this to 1 would initialize the VPC to a CIDR range of 10.1.0.0/16. This is a negotiated stopgap solution to allow for the provisioning of multiple instances of the application in one region and avoid CIDR collisions."
  type = number
}

variable "environment" {
  description = "Name of the provisioned environment for namespacing purposes."
  type = string
}
