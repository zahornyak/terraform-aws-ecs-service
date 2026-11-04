module "ecs" {
  source = "../.."

  environment     = "test"
  vpc_id          = "vpc-0secretspatterns"
  service_subnets = ["subnet-0secretspatterns"]
  cluster_name    = "test-cluster"
  service_name    = "secrets-patterns"
  service_cpu     = 1024
  service_memory  = 2048
  desired_count   = 1

  container_definitions = {
    per_key_create = {
      container_image = "public.ecr.aws/nginx/nginx:latest"
      container_name  = "per-key-create"
      containerPort   = 8080
      secrets_manager_secrets = {
        DEBUG = { value = "true" }
      }
    }

    per_key_unlock = {
      container_image = "public.ecr.aws/nginx/nginx:latest"
      container_name  = "per-key-unlock"
      containerPort   = 8081
      secrets_manager_secrets = {
        LOCKED = { value = "initial", manage_value = false }
      }
    }

    per_key_file = {
      container_image          = "public.ecr.aws/nginx/nginx:latest"
      container_name           = "per-key-file"
      containerPort            = 8082
      secrets_manager_env_file = "${path.module}/fixtures/per-key.env"
      secrets_manager_secrets = {
        INLINE = { value = "inline-wins" }
      }
    }

    per_key_ref_json = {
      container_image = "public.ecr.aws/nginx/nginx:latest"
      container_name  = "per-key-ref-json"
      containerPort   = 8083
      secrets_manager_secrets = {
        DATABASE_URL = {
          secret_arn = "arn:aws:secretsmanager:us-east-1:123456789012:secret:shared/config-AbCdEf"
          json_key   = "DATABASE_URL"
        }
      }
    }

    per_key_ref_whole = {
      container_image = "public.ecr.aws/nginx/nginx:latest"
      container_name  = "per-key-ref-whole"
      containerPort   = 8084
      secrets_manager_secrets = {
        API_KEY = {
          secret_arn = "arn:aws:secretsmanager:us-east-1:123456789012:secret:whole/api-key-AbCdEf"
        }
      }
    }

    per_key_ref_name = {
      container_image = "public.ecr.aws/nginx/nginx:latest"
      container_name  = "per-key-ref-name"
      containerPort   = 8085
      secrets_manager_secrets = {
        MANUAL = {
          managed     = false
          secret_name = "/test/secrets-patterns/per-key-ref-name/MANUAL"
        }
      }
    }

    json_create = {
      container_image = "public.ecr.aws/nginx/nginx:latest"
      container_name  = "json-create"
      containerPort   = 8086
      secrets_manager_json = {
        values = {
          APP_MODE = "production"
          FEATURE  = "on"
        }
      }
    }

    json_unlock = {
      container_image = "public.ecr.aws/nginx/nginx:latest"
      container_name  = "json-unlock"
      containerPort   = 8087
      secrets_manager_json = {
        values = {
          BOOTSTRAP = "yes"
        }
        keys         = ["MANUAL_JSON_KEY"]
        manage_value = false
      }
    }

    json_file = {
      container_image               = "public.ecr.aws/nginx/nginx:latest"
      container_name                = "json-file"
      containerPort                 = 8088
      secrets_manager_json          = {}
      secrets_manager_json_env_file = "${path.module}/fixtures/json.env"
    }

    json_ref_arn = {
      container_image = "public.ecr.aws/nginx/nginx:latest"
      container_name  = "json-ref-arn"
      containerPort   = 8089
      secrets_manager_json = {
        managed    = false
        secret_arn = "arn:aws:secretsmanager:us-east-1:123456789012:secret:external/json-AbCdEf"
        keys       = ["REF_A", "REF_B"]
      }
    }

    json_ref_name = {
      container_image = "public.ecr.aws/nginx/nginx:latest"
      container_name  = "json-ref-name"
      containerPort   = 8090
      secrets_manager_json = {
        managed     = false
        secret_name = "/test/secrets-patterns/json-ref-name/env"
        keys        = ["FROM_NAME"]
        map = {
          ALIAS_ENV = "actual_json_key"
        }
      }
    }

    ssm_plus_sm = {
      container_image = "public.ecr.aws/nginx/nginx:latest"
      container_name  = "ssm-plus-sm"
      containerPort   = 8091
      ssm_secrets = {
        FROM_SSM = { value = "ssm-value" }
      }
      secrets_manager_secrets = {
        FROM_SM = { value = "sm-value" }
      }
    }

    raw_passthrough = {
      container_image = "public.ecr.aws/nginx/nginx:latest"
      container_name  = "raw-passthrough"
      containerPort   = 8092
      secrets_manager_secrets = {
        TF_SM = { value = "combined" }
      }
      secrets = [
        {
          name      = "RAW"
          valueFrom = "arn:aws:ssm:us-east-1:123456789012:parameter/test/raw"
        }
      ]
    }
  }
}

output "container_definitions" {
  description = "Rendered ECS container definitions from the secrets pattern fixture module."
  value       = module.ecs.container_definitions
}

output "secrets_manager_created_arns" {
  description = "Per-key Secrets Manager ARNs created by the fixture module."
  value       = module.ecs.secrets_manager_created_arns
}

output "secrets_manager_json_secret_arns" {
  description = "Shared JSON Secrets Manager ARNs per container from the fixture module."
  value       = module.ecs.secrets_manager_json_secret_arns
}
