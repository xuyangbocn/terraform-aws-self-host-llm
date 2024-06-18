# ECS Cluster, Fargate Task Def, Service and etc

# ECS Cluster
resource "aws_ecs_cluster" "open_webui" {
  name = "open-webui"
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
  name        = "open-webui"
  description = "open-webui"
}

resource "aws_ecs_cluster_capacity_providers" "open_webui" {
  cluster_name       = aws_ecs_cluster.open_webui.name
  capacity_providers = ["FARGATE", "FARGATE_SPOT"]
}

# ECS Task execuction role
resource "aws_iam_role" "open_webui_iamr" {
  name               = "${local.open_webui.name}-iamr"
  assume_role_policy = data.aws_iam_policy_document.open_webui_ecs_iamr_assume.json

  tags = local.tags
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
  for_each   = toset(local.ecs_config.open_webui_ecs_iamr_policies)
  role       = aws_iam_role.open_webui_iamr.name
  policy_arn = each.value
}

# Fargate task def
resource "aws_ecs_task_definition" "open_webui" {
  family             = local.open_webui.name
  cpu                = local.ecs_config.open_webui_service.cpu
  memory             = local.ecs_config.open_webui_service.memory
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
      "name" : "ctn-${local.open_webui.name}",
      "image" : local.open_webui.image_url,
      "cpu" : 0,
      "portMappings" : [
        {
          "name" : "ctn-${local.open_webui.name}-${local.open_webui.port}-tcp",
          "containerPort" : local.open_webui.port,
          "hostPort" : local.open_webui.port,
          "protocol" : "tcp",
          "appProtocol" : "http"
        }
      ],
      "essential" : true,
      "environment" : [
        {
          "name" : "OPEN_WEBUI_PORT",
          "value" : tostring(local.open_webui.port)
        },
        {
          "name" : "OLLAMA_BASE_URL",
          "value" : "http://${aws_instance.llm_arm.private_ip}:${local.ollama_port}"
        }
      ],
      "environmentFiles" : [],
      "mountPoints" : [
        {
          "sourceVolume" : "vol-${local.open_webui.name}",
          "containerPath" : local.open_webui.data_dir,
          "readOnly" : false
        }
      ],
      "volumesFrom" : [],
      "ulimits" : [],
      "logConfiguration" : {
        "logDriver" : "awslogs",
        "options" : {
          "awslogs-group" : "/ecs/${local.open_webui.name}",
          "awslogs-region" : var.region,
          "awslogs-stream-prefix" : "ecs"
        },
        "secretOptions" : []
      },
      "systemControls" : []
    },
    {
      "name" : "aws-otel-collector",
      "image" : "public.ecr.aws/aws-observability/aws-otel-collector:v0.39.1",
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
          "awslogs-group" : "/ecs/ecs-aws-otel-sidecar-collector",
          "awslogs-region" : var.region,
          "awslogs-stream-prefix" : "ecs"
        },
        "secretOptions" : []
      },
      "systemControls" : []
    }
  ])

  volume {
    name = "vol-${local.open_webui.name}"
    efs_volume_configuration {
      file_system_id = aws_efs_file_system.open_webui.id
      root_directory = "/"
    }
  }
}

# CW Log group for ECS task
resource "aws_cloudwatch_log_group" "open_webui" {
  name              = "/ecs/${local.open_webui.name}"
  retention_in_days = 365
  skip_destroy      = false
}

resource "aws_cloudwatch_log_group" "open_webui_otel_sidecar" {
  name              = "/ecs/ecs-${local.open_webui.name}-aws-otel-sidecar-collector"
  retention_in_days = 365
  skip_destroy      = false
}

# ECS Service
resource "aws_ecs_service" "open_webui" {
  name                               = "svc-${local.open_webui.name}"
  cluster                            = aws_ecs_cluster.open_webui.id
  task_definition                    = aws_ecs_task_definition.open_webui.arn
  desired_count                      = local.ecs_config.open_webui_service.desired_count
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
    target_group_arn = module.open_webui_alb.target_groups["tg-ow"].arn
    container_name   = "ctn-${local.open_webui.name}"
    container_port   = local.open_webui.port
  }

  network_configuration {
    subnets          = module.vpc.private_subnets
    security_groups  = [aws_security_group.open_webui_sg.id]
    assign_public_ip = false
  }

  service_connect_configuration {
    enabled = false
  }
}

# SG for ECS Service Tasks for Open WebUI
resource "aws_security_group" "open_webui_sg" {
  name        = "open-webui-sg"
  description = "Security group for open webui ecs service"
  vpc_id      = module.vpc.vpc_id
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
  cidr_ipv4         = module.vpc.vpc_cidr_block
}

resource "aws_vpc_security_group_ingress_rule" "open_webui_ingress_1" {
  security_group_id = aws_security_group.open_webui_sg.id
  description       = "Traffic over port (for open webui) from VPC"
  from_port         = local.open_webui.port
  to_port           = local.open_webui.port
  ip_protocol       = "tcp"
  cidr_ipv4         = module.vpc.vpc_cidr_block

}
