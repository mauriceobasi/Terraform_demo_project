provider "aws" {
  region = "us-east-1"
}

# Create VPC
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
}

# Public Subnets for NAT Gateway
resource "aws_subnet" "public_prod" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"
  map_public_ip_on_launch = true
}

resource "aws_subnet" "public_dev" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-east-1b"
  map_public_ip_on_launch = true
}

# Private Subnets
resource "aws_subnet" "private_prod" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "us-east-1a"
}

resource "aws_subnet" "private_dev" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.4.0/24"
  availability_zone = "us-east-1b"
}

# Internet Gateway
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id
}

# NAT Gateways for Prod and Dev
resource "aws_eip" "nat_prod" {}
resource "aws_nat_gateway" "prod" {
  allocation_id = aws_eip.nat_prod.id
  subnet_id     = aws_subnet.public_prod.id
}

resource "aws_eip" "nat_dev" {}
resource "aws_nat_gateway" "dev" {
  allocation_id = aws_eip.nat_dev.id
  subnet_id     = aws_subnet.public_dev.id
}

# Route Tables
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
}

resource "aws_route_table" "private_prod" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.prod.id
  }
}

resource "aws_route_table" "private_dev" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.dev.id
  }
}


# Security Group for Prod
resource "aws_security_group" "prod" {
  name        = "prod-sg"
  description = "Security group for Prod instances"
  vpc_id      = aws_vpc.main.id

  ingress {
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
}

# Security Group for Dev
resource "aws_security_group" "dev" {
  name        = "dev-sg"
  description = "Security group for Dev instances"
  vpc_id      = aws_vpc.main.id

  ingress {
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
}

# Security Groups for RDS Instances
resource "aws_security_group" "rds_prod" {
  name        = "rds-prod-sg"
  description = "Security group for Prod RDS instances"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "rds_dev" {
  name        = "rds-dev-sg"
  description = "Security group for Dev RDS instances"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


# ALB for Prod
resource "aws_lb" "prod" {
  name               = "prod-alb"
  internal           = false
  load_balancer_type = "application"
   subnets            = [
    aws_subnet.public_prod.id,
    aws_subnet.public_dev.id  # Add a second public subnet here
  ]
}

# ALB for Dev
resource "aws_lb" "dev" {
  name               = "dev-alb"
  internal           = false
  load_balancer_type = "application"
     subnets            = [
    aws_subnet.public_prod.id,
    aws_subnet.public_dev.id  # Add a second public subnet here
  ]
}

# Auto Scaling Group for Prod
resource "aws_autoscaling_group" "prod" {
  vpc_zone_identifier = [aws_subnet.private_prod.id]
  desired_capacity    = 1
  max_size            = 2
  min_size            = 1

  launch_configuration = aws_launch_configuration.prod.id

  tag {
    key                 = "Name"
    value               = "prod-ec2"
    propagate_at_launch = true
  }
}

# Launch Configuration for Prod
resource "aws_launch_configuration" "prod" {
  name          = "prod-launch-config"
  image_id      = "ami-0ebfd941bbafe70c6"  # Replace with a valid AMI ID
  instance_type = "t2.micro"
  key_name      = "assignment" # Ensure you have this key created in AWS

  lifecycle {
    create_before_destroy = true
  }

  root_block_device {
    volume_type = "gp2"
    volume_size = 20
  }

  security_groups = [aws_security_group.prod.id]
}

# Launch Configuration for Dev
resource "aws_launch_configuration" "dev" {
  name          = "dev-launch-config"
  image_id      = "ami-0ebfd941bbafe70c6"  # Replace with a valid AMI ID
  instance_type = "t2.micro"
  key_name      = "assignment" # Ensure you have this key created in AWS

  lifecycle {
    create_before_destroy = true
  }

  root_block_device {
    volume_type = "gp2"
    volume_size = 20
  }

  security_groups = [aws_security_group.dev.id]
}


# Auto Scaling Group for Dev
resource "aws_autoscaling_group" "dev" {
  vpc_zone_identifier = [aws_subnet.private_dev.id]
  desired_capacity    = 1
  max_size            = 2
  min_size            = 1

  launch_configuration = aws_launch_configuration.dev.id

  tag {
    key                 = "Name"
    value               = "dev-ec2"
    propagate_at_launch = true
  }
}

# DB Subnet Group for Prod
resource "aws_db_subnet_group" "prod" {
  name       = "prod-db-subnet-group"
  subnet_ids = [aws_subnet.private_prod.id, aws_subnet.private_dev.id]
  
  tags = {
    Name = "prod-db-subnet-group"
  }
}

# DB Subnet Group for Dev
resource "aws_db_subnet_group" "dev" {
  name       = "dev-db-subnet-group"
  subnet_ids = [aws_subnet.private_prod.id, aws_subnet.private_dev.id]
  
  tags = {
    Name = "dev-db-subnet-group"
  }
}

# RDS for Prod
resource "aws_db_instance" "prod" {
  identifier             = "proddb"  
  allocated_storage      = 20
  instance_class         = "db.t3.micro"  # Updated instance type
  engine                 = "postgres"
  engine_version         = "16.3"
  db_name                = "proddb"
  username               = "masteruser"
  password               = "8aU!k9Xl2b#NpZ4e"
  skip_final_snapshot    = true
  publicly_accessible    = false
  vpc_security_group_ids = [aws_security_group.rds_prod.id]
  db_subnet_group_name   = aws_db_subnet_group.prod.name
}


# RDS for Dev
resource "aws_db_instance" "dev" {
  identifier            = "devdb"  
  allocated_storage      = 20
  instance_class         = "db.t3.micro"
  engine                 = "postgres"
  db_name                = "devdb"
  username               = "masteruser"
  password               = "8aU!k9Xl2b#NpZ4e"
  skip_final_snapshot    = true
  publicly_accessible    = false
  vpc_security_group_ids = [aws_security_group.rds_dev.id]
  db_subnet_group_name   = aws_db_subnet_group.dev.name
}


# Parameter Group for Redis 7
resource "aws_elasticache_parameter_group" "prod" {
  name   = "prod-redis7-param-group"
  family = "redis7"
}

resource "aws_elasticache_parameter_group" "dev" {
  name   = "dev-redis7-param-group"
  family = "redis7"
}

# ElastiCache for Prod
resource "aws_elasticache_cluster" "prod" {
  cluster_id           = "prod-cache"
  engine               = "redis"
  engine_version       = "7.0"                     # Specify Redis version
  node_type            = "cache.t2.micro"
  num_cache_nodes      = 1
  parameter_group_name = aws_elasticache_parameter_group.prod.name  # Use Redis 7 parameter group
}

# ElastiCache for Dev
resource "aws_elasticache_cluster" "dev" {
  cluster_id           = "dev-cache"
  engine               = "redis"
  engine_version       = "7.0"                     # Specify Redis version
  node_type            = "cache.t2.micro"
  num_cache_nodes      = 1
  parameter_group_name = aws_elasticache_parameter_group.dev.name  # Use Redis 7 parameter group
}


resource "aws_cloudfront_distribution" "static" {
  origin {
    domain_name = aws_s3_bucket.static.bucket_regional_domain_name
    origin_id   = "S3-Static"
  }

  enabled             = true
  default_root_object = "index.html"
  price_class         = "PriceClass_100"

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  default_cache_behavior {
    target_origin_id       = "S3-Static"
    viewer_protocol_policy = "redirect-to-https"

    allowed_methods = ["GET", "HEAD"]
    cached_methods  = ["GET", "HEAD"]

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    min_ttl     = 0
    default_ttl = 3600
    max_ttl     = 86400
  }
}


# S3 Bucket for Static Content
resource "aws_s3_bucket" "static" {
  bucket = "my-static-content-bucket-111-test-product"
}

