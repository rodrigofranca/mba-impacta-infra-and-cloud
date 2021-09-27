terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.27"
    }
  }
  required_version = ">= 0.14.9"
}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}


provider "aws" {
  profile = "default"
  region  = "us-west-2"
}

resource "tls_private_key" "key" {
  algorithm = "RSA"
}

resource "aws_key_pair" "generated_key" {
  key_name   = "ubuntu"
  public_key = tls_private_key.key.public_key_openssh
}

resource "local_file" "key_file" {
 content = tls_private_key.key.private_key_pem
 filename = "ubuntu.pem"
 file_permission = 0400
}

# vpc
resource "aws_vpc" "vpc" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "mysql-vpc"
  }

  # enable_dns_hostnames = true
}

# public subnet
resource "aws_subnet" "public_subnet" {
  depends_on = [
    aws_vpc.vpc,
  ]

  vpc_id     = aws_vpc.vpc.id
  cidr_block = "10.0.0.0/16"

  availability_zone_id = "usw2-az1"

  tags = {
    Name = "mysql-public-subnet"
  }

  map_public_ip_on_launch = true
}

# internet gateway
# resource "aws_internet_gateway" "internet_gateway" {
#   depends_on = [
#     aws_vpc.vpc,
#   ]

#   vpc_id = aws_vpc.vpc.id

#   tags = {
#     Name = "internet-gateway"
#   }
# }

# route table with target as internet gateway
# resource "aws_route_table" "IG_route_table" {
#   depends_on = [
#     aws_vpc.vpc,
#     aws_internet_gateway.internet_gateway,
#   ]

#   vpc_id = aws_vpc.vpc.id

#   route {
#     cidr_block = "0.0.0.0/0"
#     gateway_id = aws_internet_gateway.internet_gateway.id
#   }

#   tags = {
#     Name = "IG-route-table"
#   }
# }

# associate route table to public subnet
# resource "aws_route_table_association" "associate_routetable_to_public_subnet" {
#   depends_on = [
#     aws_subnet.public_subnet,
#     aws_route_table.IG_route_table,
#   ]
#   subnet_id      = aws_subnet.public_subnet.id
#   route_table_id = aws_route_table.IG_route_table.id
# }

# elastic ip
resource "aws_eip" "elastic_ip" {
  vpc      = true
}

# NAT gateway
# resource "aws_nat_gateway" "nat_gateway" {
#   depends_on = [
#     aws_subnet.public_subnet,
#     aws_eip.elastic_ip,
#   ]
#   allocation_id = aws_eip.elastic_ip.id
#   subnet_id     = aws_subnet.public_subnet.id

#   tags = {
#     Name = "nat-gateway"
#   }
# }

resource "aws_security_group" "ubuntu" {

  depends_on = [
    aws_vpc.vpc,
  ]

  name        = "ubuntu-security-group"
  description = "Allow HTTP, HTTPS and SSH traffic"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description     = "database"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "terraform"
  }
}

resource "aws_instance" "db_server" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t2.micro"

  key_name      = aws_key_pair.generated_key.key_name
  associate_public_ip_address = true

  tags = {
    Name = "db-server-mysql"
  }

  vpc_security_group_ids = [aws_security_group.ubuntu.id]
  subnet_id = aws_subnet.public_subnet.id

  provisioner "remote-exec" {
    inline = [
      "sudo apt install -y amazon-linux-extras",
      "sudo amazon-linux-extras enable nginx1.12",
      "sudo apt -y install nginx",
      "sudo systemctl start nginx"
    ]
  }

  provisioner "file" {
    source = "files/"
    destination = "/tmp"
  }

  provisioner "remote-exec" {
    
    inline = [
      "chmod +x /tmp/bootstrap.sh",
      "sudo /tmp/bootstrap.sh"
    ]

  }

  connection {
    type = "ssh"
    user = "ubuntu"
    private_key = tls_private_key.key.private_key_pem
    host = aws_instance.db_server.public_ip
  }

}

output "ip" {
  value = aws_instance.db_server.public_ip
}