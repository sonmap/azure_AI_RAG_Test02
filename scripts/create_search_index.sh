#!/usr/bin/env bash
set -euo pipefail

SEARCH_ENDPOINT="$1"
RESOURCE_GROUP="$2"
SEARCH_SERVICE_NAME="$3"
INDEX_NAME="$4"
PAYLOAD_FILE="$5"
API_VERSION="2025-09-01"

if ! command -v az >/dev/null 2>&1; then
  echo "ERROR: Azure CLI 'az' is required." >&2
  exit 1
fi

if ! command -v curl >/dev/null 2>&1; then
  echo "ERROR: curl is required." >&2
  exit 1
fi

echo "Fetching Azure AI Search admin key for ${SEARCH_SERVICE_NAME}..."
ADMIN_KEY=$(az search admin-key show \
  --resource-group "${RESOURCE_GROUP}" \
  --service-name "${SEARCH_SERVICE_NAME}" \
  --query primaryKey \
  -o tsv)

if [[ -z "${ADMIN_KEY}" ]]; then
  echo "ERROR: failed to get Search admin key." >&2
  exit 1
fi

TMP_RESPONSE=$(mktemp)

# Azure AI Search supports create through POST /indexes. Some API versions also support
# create-or-update semantics through PUT /indexes/{indexName}. We try PUT first for
# idempotent Terraform re-apply, then fall back to POST for first-time creation.
echo "Creating/updating Azure AI Search index with PUT: ${INDEX_NAME}"
HTTP_CODE=$(curl -sS -o "${TMP_RESPONSE}" -w "%{http_code}" -X PUT \
  "${SEARCH_ENDPOINT}/indexes/${INDEX_NAME}?api-version=${API_VERSION}" \
  -H "Content-Type: application/json" \
  -H "api-key: ${ADMIN_KEY}" \
  --data-binary @"${PAYLOAD_FILE}" || true)

if [[ "${HTTP_CODE}" =~ ^2 ]]; then
  cat "${TMP_RESPONSE}"
  echo
  echo "Done: ${INDEX_NAME}"
  rm -f "${TMP_RESPONSE}"
  exit 0
fi

if [[ "${HTTP_CODE}" == "404" || "${HTTP_CODE}" == "405" ]]; then
  echo "PUT returned ${HTTP_CODE}. Falling back to POST /indexes..."
  HTTP_CODE=$(curl -sS -o "${TMP_RESPONSE}" -w "%{http_code}" -X POST \
    "${SEARCH_ENDPOINT}/indexes?api-version=${API_VERSION}" \
    -H "Content-Type: application/json" \
    -H "api-key: ${ADMIN_KEY}" \
    --data-binary @"${PAYLOAD_FILE}" || true)
fi

cat "${TMP_RESPONSE}"
echo

if [[ ! "${HTTP_CODE}" =~ ^2 ]]; then
  echo "ERROR: failed to create/update index. HTTP ${HTTP_CODE}" >&2
  rm -f "${TMP_RESPONSE}"
  exit 1
fi

rm -f "${TMP_RESPONSE}"
echo "Done: ${INDEX_NAME}"
