provider "aws" {
  region = "ap-south-1"
  profile = "aditya"
}

resource "tls_private_key" "taskkey" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "local_file" "private_key" {
  content  = tls_private_key.taskkey.private_key_pem
  filename = "terrafromtaskkey.pem"
}

resource "aws_key_pair" "taskkey" {
  key_name   = "taskkey"
  public_key = "${tls_private_key.taskkey.public_key_openssh}"
}

resource "aws_security_group" "allow_http" {
  name        = "allow_http"
  description = "Allow HTTP inbound traffic"
  vpc_id      = "vpc-f6f6eb9e"

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
 ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
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
    Name = "allow_http"
  }
}

resource "aws_instance" "tf_instance" {
  ami           = "ami-0447a12f28fddb066"
  instance_type = "t2.micro"
  key_name      = "${aws_key_pair.taskkey.key_name}"
  security_groups = [ "allow_http" ] 


  connection {
   type = "ssh"
   user = "ec2-user"
   private_key = tls_private_key.taskkey.private_key_pem
   host = aws_instance.tf_instance.public_ip
  }


  provisioner "remote-exec" {
    inline = [
      "sudo yum install httpd  php git -y",
      "sudo systemctl restart httpd",
      "sudo systemctl enable httpd"
      ]
  }
  
  tags = {
    Name = "tf_instance"
  }
}

resource "aws_ebs_volume" "my_ebs" {
  availability_zone = aws_instance.tf_instance.availability_zone
  size              = 1

  tags = {
    Name = "my-ebs"
  }
}

resource "aws_volume_attachment" "ebs_att" {
  device_name = "/dev/sdh"
  volume_id   = "${aws_ebs_volume.my_ebs.id}"
  instance_id = "${aws_instance.tf_instance.id}"
  force_detach = true
}


resource "null_resource" "mounting"  {

 depends_on = [
    aws_volume_attachment.ebs_att
  ]

 connection {
   type = "ssh"
   user = "ec2-user"
   private_key = tls_private_key.taskkey.private_key_pem
   host = aws_instance.tf_instance.public_ip
  } 


 provisioner "remote-exec" {
    inline = [
      "sudo mkfs.ext4  /dev/xvdh",
      "sudo mount /dev/xvdh   /var/www/html",
      "sudo rm -rf /var/www/html/*",
      "sudo git clone https://github.com/aditya-xclusive/multicloud.git/index.html   /var/www/html/"
      ]
  }
}


resource "aws_s3_bucket" "terraformtaskbucket123" {
  bucket = "terraformtaskbucket123"
  acl    = "public-read"
  force_destroy = true

  tags = {
    Name        = "terraformtaskbucket123" 
  }
}

resource "aws_s3_bucket_object" "s3image" {
  depends_on = [
    aws_s3_bucket.terraformtaskbucket123
  ]

  bucket = "terraformtaskbucket123"
  key    = "taskimage.jpg"
  source = "C:/Users/ADITYA/Downloads/taskimage.jpg"
  acl    = "public-read"
}

 resource "aws_cloudfront_distribution" "s3distribution"  {
  depends_on = [
    aws_s3_bucket_object.s3image
  ]
  origin {
    domain_name = "${aws_s3_bucket.terraformtaskbucket123.bucket_regional_domain_name}"
    origin_id   = "${aws_s3_bucket.terraformtaskbucket123.id}"
 }
 enabled             = true
 is_ipv6_enabled     = true

 default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "${aws_s3_bucket.terraformtaskbucket123.id}"

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }
  
    viewer_protocol_policy = "allow-all"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
    
  }
    restrictions {
       geo_restriction {
         restriction_type = "none"
       }
    }  
    viewer_certificate {
        cloudfront_default_certificate = true
      }
}
 resource "null_resource" "localexec"  {
    depends_on = [
        aws_cloudfront_distribution.s3distribution,
    ]
	provisioner "local-exec" {
	    command = "start chrome  ${aws_instance.tf_instance.public_ip}"
  	}
	
}

