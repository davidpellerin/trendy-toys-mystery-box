#!/usr/bin/env bash
# Tears down everything scripts/setup-stripe.sh created: deactivates the
# ttmb-* payment links, prices, and products. Stripe doesn't allow deleting
# products/prices that have ever had a price/payment link, so "torn down"
# means archived (active: false), not deleted — safe to leave archived
# objects behind.
#
# Idempotent: safe to re-run, skips anything already inactive or missing.
#
# Requires the Stripe CLI, authenticated (`stripe login`), and jq.
# Runs against test mode by default. Pass --live to archive real objects in
# your live Stripe account.

set -euo pipefail

LIVE_FLAG=()
if [[ "${1:-}" == "--live" ]]; then
  LIVE_FLAG=(--live)
  echo "Running against LIVE Stripe account. Ctrl-C now to abort." >&2
  read -r -p "Type 'live' to continue: " confirm
  [[ "$confirm" == "live" ]] || { echo "Aborted." >&2; exit 1; }
fi

PRODUCT_IDS=(ttmb-quarterly ttmb-semiannual ttmb-annual)

deactivate_payment_link_for_price() {
  local price_id="$1"

  local url
  url=$(stripe prices retrieve "$price_id" "${LIVE_FLAG[@]}" 2>/dev/null | jq -r '.metadata.payment_link_url // empty')
  if [[ -z "$url" ]]; then
    echo "  no payment link on record for $price_id, skipping" >&2
    return
  fi

  local link_id
  link_id=$(stripe payment_links list --active=true --limit 100 "${LIVE_FLAG[@]}" 2>/dev/null \
    | jq -r --arg url "$url" '.data[] | select(.url == $url) | .id' | head -n1)

  if [[ -z "$link_id" ]]; then
    echo "  payment link already inactive or gone ($url)" >&2
    return
  fi

  stripe payment_links update "$link_id" --active=false --confirm "${LIVE_FLAG[@]}" > /dev/null
  echo "  deactivated payment link $link_id" >&2
}

deactivate_price() {
  local lookup_key="$1"

  local price_id
  price_id=$(stripe prices list --lookup-keys "$lookup_key" --limit 1 --active=true "${LIVE_FLAG[@]}" 2>/dev/null | jq -r '.data[0].id // empty')
  if [[ -z "$price_id" ]]; then
    echo "  price $lookup_key already inactive or gone" >&2
    return
  fi

  deactivate_payment_link_for_price "$price_id"

  stripe prices update "$price_id" --active=false --confirm "${LIVE_FLAG[@]}" > /dev/null
  echo "  deactivated price $lookup_key ($price_id)" >&2
}

deactivate_product() {
  local product_id="$1"

  local existing
  existing=$(stripe products retrieve "$product_id" "${LIVE_FLAG[@]}" 2>/dev/null)
  if [[ -n "$(echo "$existing" | jq -r '.error.code // empty')" ]]; then
    echo "  product $product_id doesn't exist, skipping" >&2
    return
  fi
  if [[ "$(echo "$existing" | jq -r '.active')" == "false" ]]; then
    echo "  product $product_id already inactive" >&2
    return
  fi

  stripe products update "$product_id" --active=false --confirm "${LIVE_FLAG[@]}" > /dev/null
  echo "  deactivated product $product_id" >&2
}

echo "Tearing down Trendy Toys Mystery Box Stripe objects..." >&2
echo >&2

for product_id in "${PRODUCT_IDS[@]}"; do
  echo "$product_id:" >&2
  deactivate_price "${product_id}-price"
  deactivate_product "$product_id"
done

echo >&2
echo "Done. All ttmb-* products, prices, and payment links are archived." >&2
