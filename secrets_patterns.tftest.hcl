# Plan-level tests for Secrets Manager / SSM container secret patterns.

run "secrets_patterns_plan" {
  command = plan

  module {
    source = "./tests/secrets_patterns"
  }

  override_data {
    target = module.ecs.data.aws_vpc.this
    values = {
      id         = "vpc-0secretspatterns"
      cidr_block = "10.0.0.0/16"
    }
  }

  override_data {
    target = module.ecs.data.aws_caller_identity.current
    values = {
      account_id = "123456789012"
      arn        = "arn:aws:iam::123456789012:root"
    }
  }

  override_data {
    target = module.ecs.data.aws_region.current
    values = {
      name = "us-east-1"
    }
  }

  override_data {
    target = module.ecs.module.ecs_task_execution_role.data.aws_caller_identity.current[0]
    values = {
      account_id = "123456789012"
      arn        = "arn:aws:iam::123456789012:root"
    }
  }

  override_data {
    target = module.ecs.module.ecs_task_role.data.aws_caller_identity.current[0]
    values = {
      account_id = "123456789012"
      arn        = "arn:aws:iam::123456789012:root"
    }
  }

  override_data {
    target = module.ecs.data.aws_iam_policy_document.ecs_task_exec_policy
    values = {
      json = jsonencode({
        Version = "2012-10-17"
        Statement = [
          {
            Effect   = "Allow"
            Action   = ["ssm:GetParameters", "secretsmanager:GetSecretValue"]
            Resource = "*"
          },
        ]
      })
    }
  }

  override_data {
    target = module.ecs.data.aws_iam_policy_document.ecs_task_policy
    values = {
      json = jsonencode({
        Version = "2012-10-17"
        Statement = [
          {
            Effect   = "Allow"
            Action   = ["ssmmessages:CreateControlChannel"]
            Resource = "*"
          },
        ]
      })
    }
  }

  override_data {
    target = module.ecs.module.ecs_task_execution_role.data.aws_iam_policy_document.this[0]
    values = {
      json = jsonencode({
        Version = "2012-10-17"
        Statement = [
          {
            Effect = "Allow"
            Principal = {
              Service = "ecs-tasks.amazonaws.com"
            }
            Action = "sts:AssumeRole"
          },
        ]
      })
    }
  }

  override_data {
    target = module.ecs.module.ecs_task_role.data.aws_iam_policy_document.this[0]
    values = {
      json = jsonencode({
        Version = "2012-10-17"
        Statement = [
          {
            Effect = "Allow"
            Principal = {
              Service = "ecs-tasks.amazonaws.com"
            }
            Action = "sts:AssumeRole"
          },
        ]
      })
    }
  }

  override_data {
    target = module.ecs.data.aws_secretsmanager_secret.ref_by_name["per_key_ref_name/MANUAL"]
    values = {
      arn = "arn:aws:secretsmanager:us-east-1:123456789012:secret:test/secrets-patterns/per-key-ref-name/MANUAL-AbCdEf"
    }
  }

  override_data {
    target = module.ecs.data.aws_secretsmanager_secret.json_ref_by_name["json_ref_name"]
    values = {
      arn = "arn:aws:secretsmanager:us-east-1:123456789012:secret:test/secrets-patterns/json-ref-name/env-AbCdEf"
    }
  }

  assert {
    condition     = length(module.ecs.secrets_manager_created_arns) >= 5
    error_message = "expected multiple module-created per-key secret ARNs"
  }

  assert {
    condition     = contains(keys(module.ecs.secrets_manager_json_secret_arns), "json_create")
    error_message = "json_create container should expose JSON secret ARN output"
  }

  assert {
    condition     = contains(keys(module.ecs.secrets_manager_created_arns), "per_key_create/DEBUG")
    error_message = "per_key_create should create DEBUG secret"
  }

  assert {
    condition     = contains(keys(module.ecs.secrets_manager_created_arns), "per_key_unlock/LOCKED")
    error_message = "per_key_unlock should create LOCKED secret"
  }

  assert {
    condition     = contains(keys(module.ecs.secrets_manager_created_arns), "per_key_file/FILE_VAR")
    error_message = "per_key_file should create secret from env file"
  }

  assert {
    condition     = contains(keys(module.ecs.secrets_manager_created_arns), "ssm_plus_sm/FROM_SM")
    error_message = "ssm_plus_sm should create SM secret alongside SSM"
  }

  assert {
    condition     = length(keys(module.ecs.secrets_manager_json_secret_arns)) >= 4
    error_message = "expected multiple JSON secrets (create, unlock, file, managed)"
  }

  assert {
    condition     = contains(keys(module.ecs.secrets_manager_json_secret_arns), "json_ref_arn")
    error_message = "json_ref_arn should resolve external JSON secret ARN"
  }

  assert {
    condition     = contains(keys(module.ecs.secrets_manager_json_secret_arns), "json_ref_name")
    error_message = "json_ref_name should resolve JSON secret by name"
  }
}
