provider "aws" {
  region = var.region
}

resource "local_file" "ssh_key" {
    content  = var.ssh_pem
    filename = "${path.module}/<filename>.pem"
    file_permission = "400"
}

// Terraform Tags & labels module
module "labels" {
  source = "./labels"

  name        = var.name
  environment = var.environment
  label_order = ["name", "environment"]
  owner       = var.owner
  repository  = var.repository
}

resource "aws_security_group" "allow_ssh" {
  name        = "allow_SSH"
  description = "Allow ssh inbound traffic"
  vpc_id      = var.vpc

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = merge(
    module.labels.tags
  )
}

resource "aws_instance" "interview_instance" {
  ami             = var.ami
  instance_type   = "t2.micro"
  key_name        = var.aws_keypair
  security_groups = [aws_security_group.allow_ssh.name]
  
  provisioner "local-exec" {
    command = "sleep 50 && chmod 600 ./${var.aws_keypair}.pem && ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -u ubuntu -i '${self.public_ip},' --private-key ./${var.aws_keypair}.pem ./main.yml --extra-vars 'time_out=${var.server_timeout}'"
  }

  depends_on = [
    local_file.ssh_key,
  ]

  tags = merge(
    module.labels.tags
  )
}
