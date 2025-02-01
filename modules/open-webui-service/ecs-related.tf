# ECS Cluster, Fargate Task Def, Service and etc

# ECS Cluster
resource "aws_ecs_cluster" "open_webui" {
  name = "${var.prefix}-ecs"
  configuration {
    execute_command_configuration {
      logging = "DEFAULT"
    }
  }

  service_connect_defaults {
    namespace = aws_service_discovery_http_namespace.open_webui.arn
  }

  setting {
    name  = "containerInsights"
    value = "disabled"
  }
}

resource "aws_service_discovery_http_namespace" "open_webui" {
  name        = var.prefix
  description = "open-webui"
}

resource "aws_ecs_cluster_capacity_providers" "open_webui" {
  cluster_name       = aws_ecs_cluster.open_webui.name
  capacity_providers = ["FARGATE", "FARGATE_SPOT"]
}

# ECS Task execuction role
resource "aws_iam_role" "open_webui_iamr" {
  name               = "${var.prefix}-iamr"
  assume_role_policy = data.aws_iam_policy_document.open_webui_ecs_iamr_assume.json
}

data "aws_iam_policy_document" "open_webui_ecs_iamr_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "open_webui_ecs_iam_policy" {
  for_each   = toset(local.ecs_iamr_policies)
  role       = aws_iam_role.open_webui_iamr.name
  policy_arn = each.value
}

# Fargate task def
resource "aws_ecs_task_definition" "open_webui" {
  family             = "${var.prefix}-task-def"
  cpu                = var.open_webui_task_cpu
  memory             = var.open_webui_task_mem
  execution_role_arn = aws_iam_role.open_webui_iamr.arn
  # task_role_arn      = "TBC"
  network_mode = "awsvpc"
  runtime_platform {
    cpu_architecture        = local.open_webui.arch
    operating_system_family = local.open_webui.os
  }
  requires_compatibilities = ["FARGATE"]

  container_definitions = jsonencode([
    {
      "name" : "${var.prefix}-ctn",
      "image" : var.open_webui_image_url,
      "cpu" : 0,
      "portMappings" : [
        {
          "name" : "${var.prefix}-ctn-${var.open_webui_port}-tcp",
          "containerPort" : var.open_webui_port,
          "hostPort" : var.open_webui_port,
          "protocol" : "tcp",
          "appProtocol" : "http"
        }
      ],
      "essential" : true,
      "environment" : [
        {
          "name" : "OPEN_WEBUI_PORT",
          "value" : tostring(var.open_webui_port)
        },
        {
          "name" : "OLLAMA_BASE_URL",
          "value" : var.llm_service_endpoint
        }
      ],
      "environmentFiles" : [],
      "mountPoints" : [
        {
          "sourceVolume" : "${var.prefix}-vol",
          "containerPath" : local.open_webui.data_dir,
          "readOnly" : false
        }
      ],
      "volumesFrom" : [],
      "ulimits" : [],
      "logConfiguration" : {
        "logDriver" : "awslogs",
        "options" : {
          "awslogs-group" : "/ecs/${var.prefix}",
          "awslogs-region" : var.region,
          "awslogs-stream-prefix" : "ecs"
        },
        "secretOptions" : []
      },
      "systemControls" : []
    },
    {
      "name" : "aws-otel-collector",
      "image" : "public.ecr.aws/aws-observability/aws-otel-collector:v0.41.2",
      "cpu" : 0,
      "portMappings" : [],
      "essential" : true,
      "command" : [
        "--config=/etc/ecs/ecs-cloudwatch.yaml"
      ],
      "environment" : [],
      "mountPoints" : [],
      "volumesFrom" : [],
      "logConfiguration" : {
        "logDriver" : "awslogs",
        "options" : {
          "awslogs-group" : "/ecs/ecs-${var.prefix}-aws-otel-sidecar-collector",
          "awslogs-region" : var.region,
          "awslogs-stream-prefix" : "ecs"
        },
        "secretOptions" : []
      },
      "systemControls" : []
    }
  ])

  volume {
    name = "${var.prefix}-vol"
    efs_volume_configuration {
      file_system_id = aws_efs_file_system.open_webui.id
      root_directory = "/"
    }
  }
}

# CW Log group for ECS task
resource "aws_cloudwatch_log_group" "open_webui" {
  name              = "/ecs/${var.prefix}"
  retention_in_days = 365
  skip_destroy      = false
}

resource "aws_cloudwatch_log_group" "open_webui_otel_sidecar" {
  name              = "/ecs/ecs-${var.prefix}-aws-otel-sidecar-collector"
  retention_in_days = 365
  skip_destroy      = false
}

# ECS Service
resource "aws_ecs_service" "open_webui" {
  name                               = "${var.prefix}-svc"
  cluster                            = aws_ecs_cluster.open_webui.id
  task_definition                    = aws_ecs_task_definition.open_webui.arn
  desired_count                      = var.open_webui_task_count
  launch_type                        = "FARGATE"
  platform_version                   = "LATEST"
  deployment_maximum_percent         = 200
  deployment_minimum_healthy_percent = 100
  enable_ecs_managed_tags            = true
  wait_for_steady_state              = false

  deployment_circuit_breaker {
    rollback = true
    enable   = true
  }

  deployment_controller {
    type = "ECS"
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.ow_http.arn
    container_name   = "${var.prefix}-ctn"
    container_port   = var.open_webui_port
  }

  network_configuration {
    subnets          = var.ecs_subnet_ids
    security_groups  = [aws_security_group.open_webui_sg.id]
    assign_public_ip = false
  }

  service_connect_configuration {
    enabled = false
  }
}

# SG for ECS Service Tasks for Open WebUI
resource "aws_security_group" "open_webui_sg" {
  name        = "${var.prefix}-ecs-sg"
  description = "Security group for open webui ecs service"
  vpc_id      = var.vpc_id
}

resource "aws_vpc_security_group_egress_rule" "open_webui_egress_1" {
  security_group_id = aws_security_group.open_webui_sg.id
  description       = "Allow all tcp outbound"
  from_port         = 0
  to_port           = 65535
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "open_webui_egress_2" {
  security_group_id = aws_security_group.open_webui_sg.id
  description       = "Traffic to NFS port to EFS within VPC"
  from_port         = 2049
  to_port           = 2049
  ip_protocol       = "tcp"
  cidr_ipv4         = var.vpc_cidr_block
}

resource "aws_vpc_security_group_ingress_rule" "open_webui_ingress_1" {
  security_group_id = aws_security_group.open_webui_sg.id
  description       = "Traffic over port (for open webui) from VPC"
  from_port         = var.open_webui_port
  to_port           = var.open_webui_port
  ip_protocol       = "tcp"
  cidr_ipv4         = var.vpc_cidr_block
}
