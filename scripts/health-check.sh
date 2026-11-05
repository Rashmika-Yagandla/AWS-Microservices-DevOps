#!/usr/bin/env bash
set -euo pipefail
BASE_URL="${1:-http://localhost}"
for path in /health /api/users/health /api/products/health /api/orders/health; do
  echo "Checking ${BASE_URL}${path}"
  curl --fail --silent --show-error "${BASE_URL}${path}"
  echo
done
