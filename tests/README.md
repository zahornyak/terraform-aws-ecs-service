# Module tests

## Secrets Manager / SSM patterns

[`secrets_patterns/main.tf`](secrets_patterns/main.tf) exercises every supported wiring in one module call:

| Container | Pattern |
| --- | --- |
| `per_key_create` | `secrets_manager_secrets` + `value` |
| `per_key_unlock` | `manage_value = false` |
| `per_key_file` | `secrets_manager_env_file` + inline override |
| `per_key_ref_json` | `secret_arn` + `json_key` |
| `per_key_ref_whole` | `secret_arn` only |
| `per_key_ref_name` | `managed = false` + `secret_name` |
| `json_create` | `secrets_manager_json.values` |
| `json_unlock` | JSON `values` + `keys` + `manage_value = false` |
| `json_file` | `secrets_manager_json_env_file` |
| `json_ref_arn` | JSON `managed = false` + `secret_arn` |
| `json_ref_name` | JSON `managed = false` + `secret_name` + `map` |
| `ssm_plus_sm` | SSM + SM on one container |
| `raw_passthrough` | Module secrets + raw `secrets` list |

Run everything (fmt, validate examples, pattern plan test):

```bash
./tests/run.sh
```

Plan tests use [`secrets_patterns.tftest.hcl`](../secrets_patterns.tftest.hcl) at the repo root with `override_data` (no AWS account required).

Optional helpers (not run by `run.sh`):

- [`verify_container_definitions.py`](verify_container_definitions.py) — JSON task definition checks
- [`verify_secrets_plan.py`](verify_secrets_plan.py) — plan JSON resource checks
