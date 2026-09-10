#!/usr/bin/env bash
# Creates (or reuses) the Trendy Toys Mystery Box products, prices, and
# Payment Links in Stripe, then prints a STRIPE_LINKS block ready to paste
# into js/main.js.
#
# Idempotent: safe to re-run. Products use fixed IDs, prices use fixed
# lookup_keys, and each price's metadata carries the payment_link URL created
# for it, so a second run reuses everything instead of creating duplicates.
# If a plan's amount has changed since the last run, the old price and its
# payment link are archived and a new one is created and transferred onto
# the same lookup_key.
#
# Requires the Stripe CLI, authenticated (`stripe login`), and jq.
# Runs against test mode by default. Pass --live to create real, chargeable
# products/prices/links in your live Stripe account.

set -euo pipefail

LIVE_FLAG=()
if [[ "${1:-}" == "--live" ]]; then
  LIVE_FLAG=(--live)
  echo "Running against LIVE Stripe account. Ctrl-C now to abort." >&2
  read -r -p "Type 'live' to continue: " confirm
  [[ "$confirm" == "live" ]] || { echo "Aborted." >&2; exit 1; }
fi

CURRENCY="usd"

# Aborts with the API error message if $1 is a Stripe error JSON response.
check_error() {
  local response="$1" context="$2"
  local message
  message=$(echo "$response" | jq -r '.error.message // empty')
  if [[ -n "$message" ]]; then
    echo "Stripe error while $context: $message" >&2
    exit 1
  fi
}

# Reuses the product if $product_id already exists, otherwise creates it.
ensure_product() {
  local product_id="$1" name="$2"

  local existing
  existing=$(stripe products retrieve "$product_id" "${LIVE_FLAG[@]}" 2>/dev/null)
  if [[ -z "$(echo "$existing" | jq -r '.error.code // empty')" ]]; then
    if [[ "$(echo "$existing" | jq -r '.active')" == "false" ]]; then
      local reactivated
      reactivated=$(stripe products update "$product_id" --active=true --confirm "${LIVE_FLAG[@]}" 2>/dev/null)
      check_error "$reactivated" "reactivating product $product_id"
      echo "  product $product_id existed but was inactive, reactivated" >&2
      return
    fi
    echo "  product $product_id already exists, reusing" >&2
    return
  fi

  local result
  result=$(stripe products create \
    --id "$product_id" \
    --name "$name" \
    --confirm "${LIVE_FLAG[@]}" \
    2>/dev/null)
  check_error "$result" "creating product $product_id"
  echo "  created product $product_id" >&2
}

# Deactivates the payment link stashed in a price's metadata, if any.
deactivate_payment_link_for_price() {
  local price_id="$1"

  local url
  url=$(stripe prices retrieve "$price_id" "${LIVE_FLAG[@]}" 2>/dev/null | jq -r '.metadata.payment_link_url // empty')
  [[ -z "$url" ]] && return

  local link_id
  link_id=$(stripe payment_links list --active=true --limit 100 "${LIVE_FLAG[@]}" 2>/dev/null \
    | jq -r --arg url "$url" '.data[] | select(.url == $url) | .id' | head -n1)
  [[ -z "$link_id" ]] && return

  stripe payment_links update "$link_id" --active=false --confirm "${LIVE_FLAG[@]}" > /dev/null
  echo "  deactivated old payment link $link_id" >&2
}

# Reuses the price if one with $lookup_key already exists at the target
# amount, otherwise creates it. If a price exists at $lookup_key but with a
# different amount, archives it (and its payment link) and creates a new
# price, transferring the lookup_key onto it. Echoes the price id to stdout.
ensure_price() {
  local lookup_key="$1" product_id="$2" amount_cents="$3" interval="$4" interval_count="$5"

  local found_json
  found_json=$(stripe prices list --lookup-keys "$lookup_key" --limit 1 "${LIVE_FLAG[@]}" 2>/dev/null | jq -r '.data[0] // empty')
  if [[ -n "$found_json" ]]; then
    local found found_amount found_active
    found=$(echo "$found_json" | jq -r '.id')
    found_amount=$(echo "$found_json" | jq -r '.unit_amount')
    found_active=$(echo "$found_json" | jq -r '.active')

    if [[ "$found_amount" == "$amount_cents" ]]; then
      if [[ "$found_active" == "false" ]]; then
        local reactivated
        reactivated=$(stripe prices update "$found" --active=true --confirm "${LIVE_FLAG[@]}" 2>/dev/null)
        check_error "$reactivated" "reactivating price $lookup_key"
        echo "  price $lookup_key existed but was inactive, reactivated ($found)" >&2
      else
        echo "  price $lookup_key already exists ($found), reusing" >&2
      fi
      echo "$found"
      return
    fi

    echo "  price $lookup_key exists ($found) at \$$(( found_amount / 100 )) but target is \$$(( amount_cents / 100 )), rotating" >&2
    deactivate_payment_link_for_price "$found"
    if [[ "$found_active" == "true" ]]; then
      local archived
      archived=$(stripe prices update "$found" --active=false --confirm "${LIVE_FLAG[@]}" 2>/dev/null)
      check_error "$archived" "archiving old price $lookup_key"
    fi

    local rotate_args=(
      --currency "$CURRENCY"
      --unit-amount "$amount_cents"
      --product "$product_id"
      --lookup-key "$lookup_key"
      --transfer-lookup-key
      --confirm
    )
    if [[ -n "$interval" ]]; then
      rotate_args+=(--recurring.interval "$interval" --recurring.interval-count "$interval_count")
    fi
    local rotate_result
    rotate_result=$(stripe prices create "${rotate_args[@]}" "${LIVE_FLAG[@]}" 2>/dev/null)
    check_error "$rotate_result" "creating rotated price $lookup_key"
    local rotated_price_id
    rotated_price_id=$(echo "$rotate_result" | jq -r '.id')
    echo "  created rotated price $lookup_key ($rotated_price_id)" >&2
    echo "$rotated_price_id"
    return
  fi

  local args=(
    --currency "$CURRENCY"
    --unit-amount "$amount_cents"
    --product "$product_id"
    --lookup-key "$lookup_key"
    --confirm
  )
  if [[ -n "$interval" ]]; then
    args+=(--recurring.interval "$interval" --recurring.interval-count "$interval_count")
  fi

  local result
  result=$(stripe prices create "${args[@]}" "${LIVE_FLAG[@]}" 2>/dev/null)
  check_error "$result" "creating price $lookup_key"
  local price_id
  price_id=$(echo "$result" | jq -r '.id')
  echo "  created price $lookup_key ($price_id)" >&2
  echo "$price_id"
}

# Reuses the payment link stashed in the price's metadata if present,
# otherwise creates one and stashes it. Echoes the URL to stdout.
ensure_payment_link() {
  local price_id="$1"

  local existing_url
  existing_url=$(stripe prices retrieve "$price_id" "${LIVE_FLAG[@]}" 2>/dev/null | jq -r '.metadata.payment_link_url // empty')
  if [[ -n "$existing_url" ]]; then
    local link_row link_id is_active
    link_row=$(stripe payment_links list --limit 100 "${LIVE_FLAG[@]}" 2>/dev/null | jq -r --arg url "$existing_url" '.data[] | select(.url == $url) | "\(.id)|\(.active)"' | head -n1)
    link_id="${link_row%%|*}"
    is_active="${link_row##*|}"
    if [[ "$is_active" == "false" ]]; then
      local reactivated
      reactivated=$(stripe payment_links update "$link_id" --active=true --confirm "${LIVE_FLAG[@]}" 2>/dev/null)
      check_error "$reactivated" "reactivating payment link for $price_id"
      echo "  payment link for $price_id existed but was inactive, reactivated" >&2
    else
      echo "  payment link for $price_id already exists, reusing" >&2
    fi
    echo "$existing_url"
    return
  fi

  local result
  result=$(stripe payment_links create \
    -d "line_items[0][price]=$price_id" \
    -d "line_items[0][quantity]=1" \
    --confirm "${LIVE_FLAG[@]}" \
    2>/dev/null)
  check_error "$result" "creating payment link for $price_id"
  local url
  url=$(echo "$result" | jq -r '.url')

  local update_result
  update_result=$(stripe prices update "$price_id" \
    -d "metadata[payment_link_url]=$url" \
    --confirm "${LIVE_FLAG[@]}" \
    2>/dev/null)
  check_error "$update_result" "stashing payment link url on price $price_id"

  echo "  created payment link for $price_id" >&2
  echo "$url"
}

setup_plan() {
  local key="$1" product_id="$2" name="$3" amount_cents="$4" interval="$5" interval_count="$6"

  echo "$key:" >&2
  ensure_product "$product_id" "$name"
  local price_id
  price_id=$(ensure_price "${product_id}-price" "$product_id" "$amount_cents" "$interval" "$interval_count")
  ensure_payment_link "$price_id"
}

echo "Setting up Stripe products, prices, and payment links..." >&2
echo >&2

QUARTERLY_URL=$(setup_plan  quarterly  ttmb-quarterly  "Trendy Toys Mystery Box — 3 Months"  11700 month 3)
SEMIANNUAL_URL=$(setup_plan semiannual ttmb-semiannual "Trendy Toys Mystery Box — 6 Months"  22200 month 6)
ANNUAL_URL=$(setup_plan     annual     ttmb-annual     "Trendy Toys Mystery Box — 12 Months" 39600 year  1)

echo >&2
echo "Done. Paste this into js/main.js (replacing the existing STRIPE_LINKS block):"
echo
cat <<EOF
var STRIPE_LINKS = {
  quarterly:  '${QUARTERLY_URL}',
  semiannual: '${SEMIANNUAL_URL}',
  annual:     '${ANNUAL_URL}'
};
EOF
