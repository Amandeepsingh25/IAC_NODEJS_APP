# Configure the AWS provider
provider "aws" {
  region = "ap-south-1" 
}

# Define ECS cluster
resource "aws_ecs_cluster" "my_cluster" {
  name = "my-cluster"  
}

# Define IAM role for ECS task execution
resource "aws_iam_role" "my_task_execution_role" {
  name               = "my-task-execution-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect    = "Allow",
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      },
      Action    = "sts:AssumeRole"
    }]
  })
}

# Attach IAM policy to the task execution role
resource "aws_iam_policy_attachment" "ecs_task_execution_policy_attachment" {
  name       = "ecs-task-execution-policy-attachment"
  roles      = [aws_iam_role.my_task_execution_role.name]
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Define IAM policy for ECR permissions
resource "aws_iam_policy" "ecr_policy" {
  name        = "ECRPermissionsForTask"
  description = "Policy for ECR permissions"
  policy      = jsonencode({
    Version   = "2012-10-17",
    Statement = [{
      Effect   = "Allow",
      Action   = [
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage",
        "ecr:DescribeImages",
        "ecr:GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability"
      ],
      Resource = "*"
    }]
  })
}

# Define IAM policy for ECR Image Builder permissions
resource "aws_iam_policy" "ecr_image_builder_policy" {
  name        = "ECRImageBuilderPermissionsForTask"
  description = "Policy for ECR Image Builder permissions"
  policy      = jsonencode({
    Version   = "2012-10-17",
    Statement = [{
      Effect   = "Allow",
      Action   = [
        "imagebuilder:GetComponent",
        "imagebuilder:GetContainerRecipe",
        "ecr:GetAuthorizationToken",
        "ecr:BatchGetImage",
        "ecr:InitiateLayerUpload",
        "ecr:UploadLayerPart",
        "ecr:CompleteLayerUpload",
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:PutImage"
      ],
      Resource = "*"
    }]
  })
}

# Define ECS task definition
resource "aws_ecs_task_definition" "my_task" {
  family                   = "my-task" 
  container_definitions    = jsonencode([
    {
      name            = "my-nodejs-app"
      image           = "211125771099.dkr.ecr.ap-south-1.amazonaws.com/nodejs_app:latest"
      memory          = 512
      cpu             = 512
      essential       = true
      portMappings    = [
        {
          containerPort = 3000
          hostPort      = 3000
          protocol      = "tcp"
        }
      ]
      environment     = [
        {
          name  = "NODE_ENV"
          value = "production"
        }
      ]
    }
  ])
  
  # Specify network mode as "awsvpc" for Fargate launch type
  network_mode = "awsvpc"

  # Specify the execution strategy for the task definition
  # Requires an AWS managed scaling policy for Fargate launch type
  requires_compatibilities = ["FARGATE"]
  cpu = "512"
  memory = "512"
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

# Create Internet Gateway
resource "aws_internet_gateway" "my_gateway" {
  vpc_id = aws_vpc.my_vpc.id
}

# Define Route Table
resource "aws_route_table" "my_route_table" {
  vpc_id = aws_vpc.my_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.my_gateway.id
  }
}

# Associate Route Table with Subnets
resource "aws_route_table_association" "subnet1_association" {
  subnet_id      = aws_subnet.subnet1.id
  route_table_id = aws_route_table.my_route_table.id
}

resource "aws_route_table_association" "subnet2_association" {
  subnet_id      = aws_subnet.subnet2.id
  route_table_id = aws_route_table.my_route_table.id
}

# Define Security Group
resource "aws_security_group" "ecs_security_group" {
  name        = "ecs-security-group"
  description = "Security group for ECS task"

  vpc_id = aws_vpc.my_vpc.id 

  # Inbound rule to allow traffic from the ECR endpoint on port 443
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Inbound rule to allow traffic on port 3000
  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Outbound rule allowing traffic to the ECR endpoint
  egress {
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    cidr_blocks     = ["0.0.0.0/0"]  # Replace with the ECR endpoint IP address or CIDR block
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
    security_groups  = [aws_security_group.ecs_security_group.id]  
    assign_public_ip = true  
  }
}
