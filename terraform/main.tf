# Configure the AWS provider
provider "aws" {
  region = "ap-south-1" 
}

# Define ECS cluster
resource "aws_ecs_cluster" "my_cluster" {
  name = "my-cluster"  
}

# Define ECS task definition
resource "aws_ecs_task_definition" "my_task" {
  family                   = "my-task" 
  container_definitions    = file("${path.module}/container_definitions.json")
}

resource "aws_vpc" "my_vpc" {
  cidr_block = "10.0.0.0/16"
}

resource "aws_subnet" "subnet1" {
  vpc_id            = aws_vpc.my_vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "ap-south-1a"
}

resource "aws_subnet" "subnet2" {
  vpc_id            = aws_vpc.my_vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "ap-south-1b"
}

resource "aws_security_group" "nodejs_app_sg" {
  name        = "nodejs-app-sg"
  description = "Security group for Node.js app running on port 3000"

  vpc_id = aws_vpc.my_vpc.id 

  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] 
  }

  egress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] 
  }
}

# Define ECS service
resource "aws_ecs_service" "my_service" {
  name            = "my-service"  
  cluster         = aws_ecs_cluster.my_cluster.id
  task_definition = aws_ecs_task_definition.my_task.arn
  desired_count   = 1  
  launch_type     = "FARGATE"  
  network_configuration {
    subnets          = [aws_subnet.subnet1.id, aws_subnet.subnet2.id]  
    security_groups  = [aws_security_group.nodejs_app_sg.id]  
    assign_public_ip = true  
  }
}
