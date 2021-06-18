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

resource "aws_security_group" "ubuntu" {
  name        = "ubuntu-security-group"
  description = "Allow HTTP, HTTPS and SSH traffic"

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
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
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "terraform"
  }
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

resource "aws_instance" "db_server" {
  key_name      = aws_key_pair.generated_key.key_name
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t2.micro"

  associate_public_ip_address = true

  tags = {
    Name = "db-server-mysql"
  }

  # vpc_security_group_ids = [
  #   aws_security_group.ubuntu.id
  # ]

  # ebs_block_device {
  #   device_name = "/dev/sda1"
  #   volume_type = "gp2"
  #   volume_size = 30
  # }

  connection {
    type = "ssh"
    user = "ubuntu"
    host = self.public_ip
    private_key = tls_private_key.key.private_key_pem
    agent = false
    timeout = "15m"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo amazon-linux-extras enable nginx1.12",
      "sudo yum -y install nginx",
      "sudo systemctl start nginx"
    ]
  }
}

# resource "time_sleep" "wait_30_seconds_db" {
#   create_duration = "30s"
#   depends_on = [aws_instance.db_server]
# }

# resource "null_resource" "upload_mysql" {
#   triggers = {
#     public_ip = aws_instance.db_server.public_ip
#   }

#   provisioner "file" {

#     connection {
#       type = "ssh"
#       user = "ubuntu"
#       private_key = tls_private_key.this.private_key_pem
#       host = aws_instance.db_server.public_ip
#     }

#     source = "/files"
#     destination = "/tmp"

#   }

#   depends_on = [time_sleep.wait_30_seconds_db]

# }

# resource "null_resource" "install_mysql" {
#   # triggers = {
#   #   public_ip = aws_instance.db_server.public_ip
#   # }

#   provisioner "remote-exec" {
    
#     connection {
#       type = "ssh"
#       user = "ubuntu"
#       port = 22
#       private_key = "${file("~/Documents/keys/as02.pem")}"
#       host = aws_instance.db_server.public_ip
#     }

#     inline = [
#       "chmod +x /tmp/bootstrap.sh",
#       "sudo /tmp/bootstrap.sh"
#     ]

#   }

# }

output "ip" {
  value = aws_instance.db_server.public_ip
}