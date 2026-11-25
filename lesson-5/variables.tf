variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-west-2"
}

variable "project_name" {
  description = "Project name"
  type        = string
  default     = "lesson-5"
}

variable "bucket_name" {
  description = "Globally unique S3 bucket name"
  type        = string
}
