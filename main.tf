provider "aws" {
  region  = "us-east-1"
  profile = "default"
}


resource "aws_instance" "terra" {
  count         = "20"
  ami           = "ami-09e67e426f25ce0d7"
  instance_type = "t2.nano"
  key_name   = "terraform"
}