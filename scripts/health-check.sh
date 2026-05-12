#!/usr/bin/env bash
set -euo pipefail

HOST="${1:-localhost}"
PORT="${2:-5000}"
URL="http://${HOST}:${PORT}"
MAX_RETRIES=10
RETRY_INTERVAL=5

echo "Health check: ${URL}/health"

for i in $(seq 1 "$MAX_RETRIES"); do
  HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "${URL}/health" || true)

  if [ "$HTTP_STATUS" = "200" ]; then
    echo "PASS (attempt $i)"
    curl -s "${URL}/health" | python3 -m json.tool
    exit 0
  fi

  echo "Attempt $i/$MAX_RETRIES — status $HTTP_STATUS. Retrying in ${RETRY_INTERVAL}s..."
  sleep "$RETRY_INTERVAL"
done

echo "FAIL — health check did not pass after $MAX_RETRIES attempts"
exit 1
