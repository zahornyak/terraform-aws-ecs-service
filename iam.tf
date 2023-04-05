module "ecs_task_execution_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-role"
  version = "~> 4.4"

  trusted_role_services = [
    "ecs-tasks.amazonaws.com"
  ]

  create_role = true

  role_name         = "${var.environment}-${var.service_name}EcsTaskExecutionRole"
  role_requires_mfa = false


  custom_role_policy_arns = [
    "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy",
  ]
}

module "ecs_task_policy" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-policy"
  version = "~> 4.4"

  name = "${var.environment}-${var.service_name}EcsTaskPolicy"

  policy = data.aws_iam_policy_document.ecs_task_policy.json
}


data "aws_iam_policy_document" "ecs_task_policy" {
  statement {
    actions = [
      "ssmmessages:CreateControlChannel",
      "ssmmessages:CreateDataChannel",
      "ssmmessages:OpenControlChannel",
      "ssmmessages:OpenDataChannel"
    ]
    resources = ["*"]
  }
  #  statement {
  #    actions = [
  #      "appmesh:*"
  #    ]
  #    resources = ["*"]
  #  }
}


module "ecs_task_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-role"
  version = "~> 4.4"

  trusted_role_services = [
    "ecs-tasks.amazonaws.com"
  ]

  create_role = true

  role_name         = "${var.environment}-${var.service_name}EcsTaskRole"
  role_requires_mfa = false


  custom_role_policy_arns = concat([
    module.ecs_task_policy.arn,
    "arn:aws:iam::aws:policy/AWSAppMeshEnvoyAccess"
  ], var.task_role_policy_arns)

}
