# an example instance in the private subnet
resource "aws_instance" "private_instance" {
  ami                    = data.aws_ami.amazon_linux_2.id
  instance_type          = "t3.small"
  iam_instance_profile   = aws_iam_instance_profile.private_instance.name
  subnet_id              = module.vpc.public_subnets[0]
  vpc_security_group_ids = [aws_security_group.private_instance.id]
  key_name               = "lefteris-laptop"

  tags = {
    Name = "bastion"
  }

  user_data = <<EOF
#!/bin/bash
yum update -y
amazon-linux-extras install docker
service docker start
usermod -a -G docker ec2-user
systemctl enable docker
sudo docker run -d --restart=unless-stopped -p 8080:80 -p 8443:443 rancher/rancher
EOF
}

resource "aws_security_group" "private_instance" {
  name        = "example-terraform-aws-nat-instance"
  description = "expose http service"
  vpc_id      = module.vpc.vpc_id
  ingress {
    protocol        = "tcp"
    from_port       = 80
    to_port         = 80
    security_groups = [module.nat.sg_id]
  }
  ingress {
    protocol        = "tcp"
    from_port       = 8080
    to_port         = 8080
    cidr_blocks = ["0.0.0.0/0"]
  } 
  ingress {
    protocol        = "tcp"
    from_port       = 22
    to_port         = 22
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    protocol        = "tcp"
    from_port       = 8443
    to_port         = 8443
    security_groups = [module.nat.sg_id]
    cidr_blocks = ["0.0.0.0/0"]
  } 
  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# AMI of the latest Amazon Linux 2 
data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  filter {
    name   = "block-device-mapping.volume-type"
    values = ["gp2"]
  }
}

# enable SSM access
resource "aws_iam_instance_profile" "private_instance" {
  role = aws_iam_role.private_instance.name
}

resource "aws_iam_role" "private_instance" {
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "ssm" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  role       = aws_iam_role.private_instance.name
}

output "private_instance_id" {
  value = aws_instance.private_instance.id
}
