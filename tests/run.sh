#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

unset AWS_PROFILE AWS_DEFAULT_PROFILE
export AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID:-testing}"
export AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY:-testing}"
export AWS_EC2_METADATA_DISABLED=true

echo "==> terraform fmt -check -recursive"
terraform fmt -check -recursive

echo "==> terraform validate (module root)"
terraform init -backend=false -input=false -upgrade >/dev/null
terraform validate

for example in examples/minimal examples/main examples/completed; do
  echo "==> terraform validate ($example)"
  (cd "$example" && terraform init -backend=false -input=false -upgrade >/dev/null && terraform validate)
done

echo "==> terraform init (tests/secrets_patterns)"
(cd tests/secrets_patterns && terraform init -backend=false -input=false >/dev/null)

echo "==> terraform validate (tests/secrets_patterns)"
(cd tests/secrets_patterns && terraform validate)

echo "==> terraform test (secrets_patterns.tftest.hcl — all secret patterns)"
terraform init -backend=false -input=false -upgrade >/dev/null
terraform test

echo "All validations and secret pattern tests passed."
