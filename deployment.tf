# Configure the AWS provider
provider "aws" {
  region = "us-west-2"
}

# Variables
variable "cidr_block" {
  default = "10.0.0.0/16"
}

variable "subnet_cidr_block" {
  default = "10.0.1.0/24"
}

# Create VPC
resource "aws_vpc" "my_vpc" {
  cidr_block = var.cidr_block
}

# Create Subnet
resource "aws_subnet" "my_subnet" {
  vpc_id            = aws_vpc.my_vpc.id
  cidr_block        = var.subnet_cidr_block
  availability_zone = "us-west-2a"  
}

# Create Security Group for allowing SSH
resource "aws_security_group" "allow_ssh" {
  vpc_id = aws_vpc.my_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Create Internet Gateway and Route Table
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.my_vpc.id
}

resource "aws_route_table" "my_route_table" {
  vpc_id = aws_vpc.my_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

# Associate Route Table with Subnet
resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.my_subnet.id
  route_table_id = aws_route_table.my_route_table.id
}

# Create IAM Role and Policy
resource "aws_iam_role" "ec2_dynamodb_access" {
  name = "ec2_dynamodb_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_policy" "dynamodb_policy" {
  name   = "dynamodb_access_policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action   = ["dynamodb:PutItem", "dynamodb:GetItem"]
      Effect   = "Allow"
      Resource = aws_dynamodb_table.pokemon_data.arn  
    }]
  })
}

# Attach the policy to the IAM role
resource "aws_iam_role_policy_attachment" "attach_policy" {
  role       = aws_iam_role.ec2_dynamodb_access.name
  policy_arn = aws_iam_policy.dynamodb_policy.arn
}

# Create IAM instance profile
resource "aws_iam_instance_profile" "my_instance_profile" {
  role = aws_iam_role.ec2_dynamodb_access.name
}

# Create EC2 instance for running Pokémon App
resource "aws_instance" "Pokémon_App" {
  ami                         = "ami-0c55b159cbfafe1f0"
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.my_subnet.id
  vpc_security_group_ids      = [aws_security_group.allow_ssh.id]
  key_name                    = "my-key-pair"
  iam_instance_profile        = aws_iam_instance_profile.my_instance_profile.id
  
  user_data = <<-EOF
  #!/bin/bash
  # Update the system
  sudo yum update -y
  # Install necessary packages
  sudo yum install -y python3 git
  pip3 install boto3 requests

  # Clone the repository from GitHub
  cd /home/ec2-user
  git clone https://github.com/levi-ochana/Pokemon-API-and-DynamoDB.git
  cd Pokemon-API-and-DynamoDB

  # Run the Python script
  python3 game.py
EOF

  tags = {
    Name = "Pokémon_App"
  }
}

# Create DynamoDB Table for storing Pokémon data
resource "aws_dynamodb_table" "pokemon_data" {
  name           = "PokemonData"
  hash_key       = "name"

  attribute {
    name = "name"
    type = "S"  # String type for the name attribute
  }

  tags = {
    Name = "PokemonDataTable"
  }
}
