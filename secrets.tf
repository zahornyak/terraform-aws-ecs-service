locals {
  secret_name_prefix_by_container = {
    for k, v in var.container_definitions : k => (
      var.secret_name_prefix != null ? var.secret_name_prefix : "/${var.environment}/${var.service_name}/${lookup(v, "container_name", k)}/"
    )
  }

  sm_env_file_by_container = {
    for container_key, def in var.container_definitions :
    container_key => def.secrets_manager_env_file
    if try(def.secrets_manager_env_file, null) != null
  }

  sm_env_file_params = {
    for container_key, path in local.sm_env_file_by_container : container_key => {
      for line in compact([
        for raw_line in split("\n", file(path)) :
        trimspace(raw_line)
        if trimspace(raw_line) != "" && !startswith(trimspace(raw_line), "#")
      ]) :
      trimspace(split("=", line)[0]) => trimspace(join("=", slice(split("=", line), 1, length(split("=", line)))))
      if length(split("=", line)) >= 2
    }
  }

  sm_secret_cfg = {
    for container_key, def in var.container_definitions : container_key => lookup(def, "secrets_manager_secrets", {})
  }

  sm_create_params = {
    for container_key, def in var.container_definitions : container_key => merge(
      try(local.sm_env_file_params[container_key], {}),
      {
        for env_name, cfg in lookup(def, "secrets_manager_secrets", {}) :
        env_name => cfg.value
        if try(cfg.value, null) != null && try(cfg.managed, true) && try(cfg.secret_arn, try(cfg.arn, null)) == null
      }
    )
    if length(merge(
      try(local.sm_env_file_params[container_key], {}),
      {
        for env_name, cfg in lookup(def, "secrets_manager_secrets", {}) :
        env_name => cfg.value
        if try(cfg.value, null) != null && try(cfg.managed, true) && try(cfg.secret_arn, try(cfg.arn, null)) == null
      }
    )) > 0
  }

  sm_create_flat = merge([
    for container_key, params in local.sm_create_params : {
      for env_name, value in params :
      "${container_key}/${env_name}" => {
        container_key = container_key
        env_name      = env_name
        value         = value
        secret_name   = "${local.secret_name_prefix_by_container[container_key]}${env_name}"
        manage_value  = try(local.sm_secret_cfg[container_key][env_name].manage_value, true)
      }
    }
  ]...)

  sm_create_flat_value_managed = {
    for k, v in local.sm_create_flat : k => v if v.manage_value
  }

  sm_create_flat_value_unmanaged = {
    for k, v in local.sm_create_flat : k => v if !v.manage_value
  }

  sm_ref_flat = merge([
    for container_key, def in var.container_definitions : {
      for env_name, cfg in lookup(def, "secrets_manager_secrets", {}) :
      "${container_key}/${env_name}" => {
        container_key  = container_key
        env_name       = env_name
        secret_arn     = try(cfg.secret_arn, try(cfg.arn, null))
        secret_name    = try(cfg.secret_name, null)
        json_key       = try(cfg.json_key, null)
        lookup_by_name = try(cfg.secret_arn, try(cfg.arn, null)) == null && try(cfg.secret_name, null) != null
      }
      if try(cfg.secret_arn, try(cfg.arn, null)) != null || (
        try(cfg.managed, true) == false && try(cfg.secret_name, null) != null
      )
    }
  ]...)

  sm_ref_by_name_flat = {
    for k, v in local.sm_ref_flat : k => v if v.lookup_by_name
  }

  sm_json_by_container = {
    for container_key, def in var.container_definitions :
    container_key => def.secrets_manager_json
    if try(def.secrets_manager_json, null) != null
  }

  sm_json_env_file_by_container = {
    for container_key, def in var.container_definitions :
    container_key => def.secrets_manager_json_env_file
    if try(def.secrets_manager_json_env_file, null) != null
  }

  sm_json_env_file_params = {
    for container_key, path in local.sm_json_env_file_by_container : container_key => {
      for line in compact([
        for raw_line in split("\n", file(path)) :
        trimspace(raw_line)
        if trimspace(raw_line) != "" && !startswith(trimspace(raw_line), "#")
      ]) :
      trimspace(split("=", line)[0]) => trimspace(join("=", slice(split("=", line), 1, length(split("=", line)))))
      if length(split("=", line)) >= 2
    }
  }

  sm_json_values_by_container = {
    for container_key, cfg in local.sm_json_by_container : container_key => merge(
      try(local.sm_json_env_file_params[container_key], {}),
      try(cfg.values, {})
    )
  }

  sm_json_ecs_flat = merge([
    for container_key, cfg in local.sm_json_by_container : {
      for env_name in distinct(concat(
        keys(lookup(local.sm_json_values_by_container, container_key, {})),
        try(cfg.keys, [])
      )) :
      "${container_key}/${env_name}" => {
        container_key = container_key
        env_name      = env_name
        json_key      = coalesce(try(cfg.map[env_name], null), env_name)
      }
    }
  ]...)

  sm_json_managed_by_container = {
    for container_key, cfg in local.sm_json_by_container :
    container_key => cfg
    if try(cfg.managed, true) != false
  }

  sm_json_ref_by_name = {
    for container_key, cfg in local.sm_json_by_container :
    container_key => cfg
    if try(cfg.managed, true) == false && try(cfg.secret_arn, try(cfg.arn, null)) == null && try(cfg.secret_name, null) != null
  }

  sm_json_ref_by_default_name = {
    for container_key, cfg in local.sm_json_by_container :
    container_key => cfg
    if try(cfg.managed, true) == false && try(cfg.secret_arn, try(cfg.arn, null)) == null && try(cfg.secret_name, null) == null
  }
}

data "aws_secretsmanager_secret" "ref_by_name" {
  for_each = local.sm_ref_by_name_flat

  name = each.value.secret_name
}

data "aws_secretsmanager_secret" "json_ref_by_name" {
  for_each = merge(local.sm_json_ref_by_name, local.sm_json_ref_by_default_name)

  name = coalesce(
    try(each.value.secret_name, null),
    "${local.secret_name_prefix_by_container[each.key]}env"
  )
}

locals {
  sm_ref_secret_arn = {
    for k, v in local.sm_ref_flat :
    k => v.lookup_by_name ? data.aws_secretsmanager_secret.ref_by_name[k].arn : v.secret_arn
  }

  sm_ref_value_from = {
    for k, v in local.sm_ref_flat :
    k => v.json_key != null && v.json_key != "" ? "${local.sm_ref_secret_arn[k]}:${v.json_key}::" : local.sm_ref_secret_arn[k]
  }

  ssm_secrets_by_container = {
    for container_key, mod in module.env_variables : container_key => [
      for env_name, arn in mod.parameters_arns : {
        name      = env_name
        valueFrom = arn
      }
    ]
  }

  sm_created_secrets_by_container = {
    for container_key in keys(var.container_definitions) : container_key => [
      for flat_key, meta in local.sm_create_flat : {
        name      = meta.env_name
        valueFrom = aws_secretsmanager_secret.container_env[flat_key].arn
      } if meta.container_key == container_key
    ]
  }

  sm_refs_by_container = {
    for container_key in keys(var.container_definitions) : container_key => [
      for flat_key, meta in local.sm_ref_flat : {
        name      = meta.env_name
        valueFrom = local.sm_ref_value_from[flat_key]
      } if meta.container_key == container_key
    ]
  }

  sm_json_secret_arn = {
    for container_key, cfg in local.sm_json_by_container :
    container_key => try(cfg.managed, true) != false ? aws_secretsmanager_secret.container_json[container_key].arn : (
      try(cfg.secret_arn, try(cfg.arn, null)) != null ? try(cfg.secret_arn, try(cfg.arn, null)) : data.aws_secretsmanager_secret.json_ref_by_name[container_key].arn
    )
  }

  sm_json_secrets_by_container = {
    for container_key in keys(var.container_definitions) : container_key => [
      for flat_key, meta in local.sm_json_ecs_flat : {
        name      = meta.env_name
        valueFrom = "${local.sm_json_secret_arn[meta.container_key]}:${meta.json_key}::"
      } if meta.container_key == container_key
    ]
  }

  merged_container_secrets = {
    for container_key, def in var.container_definitions : container_key => concat(
      lookup(local.ssm_secrets_by_container, container_key, []),
      lookup(local.sm_created_secrets_by_container, container_key, []),
      lookup(local.sm_refs_by_container, container_key, []),
      lookup(local.sm_json_secrets_by_container, container_key, []),
      coalesce(lookup(def, "secrets", null), [])
    )
  }

  uses_ssm_secrets = length([
    for k, v in var.container_definitions : k
    if try(v.ssm_secrets, null) != null || try(v.ssm_env_file, null) != null
  ]) > 0

  uses_sm_secrets = length([
    for k, v in var.container_definitions : k
    if try(v.secrets_manager_secrets, null) != null || try(v.secrets_manager_env_file, null) != null || try(v.secrets_manager_json, null) != null || try(v.secrets_manager_json_env_file, null) != null
  ]) > 0

  # Secret names use path-style prefixes (often leading "/"). IAM ARNs must match that
  # (e.g. secret:/dev/app/env-XXXX), not a trimmed form without the slash.
  sm_iam_prefix_wildcards = distinct([
    for container_key, def in var.container_definitions :
    "arn:aws:secretsmanager:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:secret:${local.secret_name_prefix_by_container[container_key]}*"
    if try(def.secrets_manager_secrets, null) != null || try(def.secrets_manager_env_file, null) != null || try(def.secrets_manager_json, null) != null || try(def.secrets_manager_json_env_file, null) != null
  ])

  sm_iam_ref_arns = distinct(concat(
    [for k, v in local.sm_ref_secret_arn : v],
    [for k, v in local.sm_json_secret_arn : v if try(local.sm_json_by_container[k].managed, true) == false]
  ))

  sm_iam_created_secret_arns = concat(
    [for k, v in aws_secretsmanager_secret.container_env : v.arn],
    [for k, v in aws_secretsmanager_secret.container_json : v.arn]
  )

  sm_iam_secret_resources = distinct(concat(
    local.sm_iam_prefix_wildcards,
    local.sm_iam_ref_arns,
    local.sm_iam_created_secret_arns
  ))

  secrets_manager_created_arns = {
    for flat_key, meta in local.sm_create_flat :
    flat_key => aws_secretsmanager_secret.container_env[flat_key].arn
  }

  secrets_manager_json_secret_arns = {
    for container_key, cfg in local.sm_json_by_container :
    container_key => local.sm_json_secret_arn[container_key]
  }
}

resource "aws_secretsmanager_secret" "container_env" {
  for_each = local.sm_create_flat

  name = each.value.secret_name
}

resource "aws_secretsmanager_secret_version" "container_env" {
  for_each = local.sm_create_flat_value_managed

  secret_id     = aws_secretsmanager_secret.container_env[each.key].id
  secret_string = each.value.value
}

resource "aws_secretsmanager_secret_version" "container_env_unlocked_value" {
  for_each = local.sm_create_flat_value_unmanaged

  secret_id     = aws_secretsmanager_secret.container_env[each.key].id
  secret_string = each.value.value

  lifecycle {
    ignore_changes = [secret_string]
  }
}

resource "aws_secretsmanager_secret" "container_json" {
  for_each = local.sm_json_managed_by_container

  name = coalesce(
    try(each.value.secret_name, null),
    "${local.secret_name_prefix_by_container[each.key]}env"
  )
}

resource "aws_secretsmanager_secret_version" "container_json" {
  for_each = {
    for container_key, cfg in local.sm_json_managed_by_container :
    container_key => cfg
    if length(lookup(local.sm_json_values_by_container, container_key, {})) > 0 && try(cfg.manage_value, true)
  }

  secret_id = aws_secretsmanager_secret.container_json[each.key].id
  secret_string = jsonencode({
    for env_name, val in local.sm_json_values_by_container[each.key] :
    coalesce(try(each.value.map[env_name], null), env_name) => val
  })
}

resource "aws_secretsmanager_secret_version" "container_json_unlocked_value" {
  for_each = {
    for container_key, cfg in local.sm_json_managed_by_container :
    container_key => cfg
    if length(lookup(local.sm_json_values_by_container, container_key, {})) > 0 && !try(cfg.manage_value, true)
  }

  secret_id = aws_secretsmanager_secret.container_json[each.key].id
  secret_string = jsonencode({
    for env_name, val in local.sm_json_values_by_container[each.key] :
    coalesce(try(each.value.map[env_name], null), env_name) => val
  })

  lifecycle {
    ignore_changes = [secret_string]
  }
}
