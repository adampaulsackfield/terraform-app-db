provider "aws" {
  region="us-east-1"
}

# Create our VPC
resource "aws_vpc" "adamsackfield-application-deployment" {
  cidr_block = "10.8.0.0/16"

  tags = {
    Name = "adamsackfield-application-deployment-vpc"
  }
}

resource "aws_internet_gateway" "adamsackfield-ig" {
  vpc_id = "${aws_vpc.adamsackfield-application-deployment.id}"

  tags = {
    Name = "adamsackfield-ig"
  }
}

resource "aws_route_table" "adamsackfield-rt" {
  vpc_id = "${aws_vpc.adamsackfield-application-deployment.id}"
  
  route {
    cidr_block = "0.0.0.0/0" # Anywhere - access the internet from inside the network
    gateway_id = "${aws_internet_gateway.adamsackfield-ig.id}"
  }
}

module "db-tier" {
  name           = "adamsackfield-database"
  source         = "./modules/db-tier"
  vpc_id         = "${aws_vpc.adamsackfield-application-deployment.id}"
  route_table_id = "${aws_vpc.adamsackfield-application-deployment.main_route_table_id}"
  cidr_block              = "10.8.1.0/24"
  user_data               = templatefile("./scripts/database_user_data.sh", {})
  ami_id                  = "ami-0a6bcbc3dec6aeb5a"
  map_public_ip_on_launch = false

  ingress = [
    {
      from_port = 27017
      to_port = 27017
      protocol = "tcp"
      cidr_blocks = "${module.application-tier.subnet_cidr_block}"
    }
  ]
}

module "application-tier" {
  name                    = "adamsackfield-app"
  source                  = "./modules/application-tier"
  vpc_id                  = "${aws_vpc.adamsackfield-application-deployment.id}"
  route_table_id          = "${aws_route_table.adamsackfield-rt.id}"
  cidr_block              = "10.8.0.0/24"
  user_data               = templatefile("./scripts/app_user_data.sh", { mongodb_ip=module.db-tier.private_ip })
  ami_id                  = "ami-0aadcd8576538f786"
  map_public_ip_on_launch = true

  ingress = [
    {
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      cidr_blocks = "0.0.0.0/0"
    },
    {
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = "51.14.230.62/32"
    },
    {
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = "54.197.131.165/32"
    }
  ]
}