variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Prefix for all resource names"
  type        = string
  default     = "joel-hello"
}

variable "ec2_instance_type" {
  description = "EC2 instance type for the FastAPI server"
  type        = string
  default     = "t2.micro"
}

variable "tags" {
  description = "Tags applied to all resources"
  type        = map(string)
  default = {
    Project     = "hello-world"
    Environment = "dev"
    ManagedBy   = "terraform"
  }
}
