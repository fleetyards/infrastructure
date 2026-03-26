#!/usr/bin/env bash
set -euo pipefail

# Import existing DNSimple DNS records into Terraform state.
# Usage: ./scripts/import-dns-records.sh
#
# Requires:
#   - DNSIMPLE_TOKEN and DNSIMPLE_ACCOUNT_ID env vars (or TF_VAR_ prefixed)
#   - terraform workspace already selected
#   - jq installed

TOKEN="${DNSIMPLE_TOKEN:-}"
ACCOUNT="${DNSIMPLE_ACCOUNT:-}"

if [ -z "$TOKEN" ] || [ -z "$ACCOUNT" ]; then
  echo "Error: DNSIMPLE_TOKEN and DNSIMPLE_ACCOUNT must be set"
  exit 1
fi

WORKSPACE=$(terraform workspace show)

case "$WORKSPACE" in
  stage)
    DOMAINS=("fleetyards.dev")
    SHORT_DOMAINS=("fltyrd.dev")
    ;;
  live)
    DOMAINS=("fleetyards.net")
    SHORT_DOMAINS=("fltyrd.net")
    ;;
  *)
    echo "No domains configured for workspace '$WORKSPACE'"
    exit 0
    ;;
esac

SUBDOMAINS=("" "www" "api" "admin" "docs")

import_records() {
  local domain=$1
  shift
  local names=("$@")

  echo "Fetching records for $domain..."
  local records
  records=$(curl -s -H "Authorization: Bearer $TOKEN" \
    "https://api.dnsimple.com/v2/$ACCOUNT/zones/$domain/records?per_page=100")

  for name in "${names[@]}"; do
    local key="${domain}/${name}"
    local resource="dnsimple_zone_record.web[\"${key}\"]"
    local display_name="${name:-@}"

    local record_id
    record_id=$(echo "$records" | jq -r \
      --arg name "$name" \
      '.data[] | select(.type == "A" and .name == $name) | .id' | head -1)

    if [ -n "$record_id" ]; then
      echo "  Importing ${display_name}.${domain} (record ID: $record_id)"
      terraform import "$resource" "${domain}_${record_id}" || true
    else
      echo "  No existing A record for ${display_name}.${domain} — will be created on apply"
    fi
  done
}

for DOMAIN in "${DOMAINS[@]}"; do
  import_records "$DOMAIN" "${SUBDOMAINS[@]}"
done

for DOMAIN in "${SHORT_DOMAINS[@]}"; do
  import_records "$DOMAIN" ""
done

echo "Done. Run 'terraform plan' to verify."
