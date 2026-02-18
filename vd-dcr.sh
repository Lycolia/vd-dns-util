#!/bin/bash

# value-domain-dns-cert-register
# vddcr.sh <value-domain-api-key> <root-domain> <optional:ttl>
# <optional:ttl>はオプションなので省いてもよい
# 120未満を指定した場合、120として解釈、無指定の場合はAPIから来た値を割り当てるが
# APIから来た値が120未満の場合、120を割り当てる
# これはValue-Domain APIの仕様上、120未満を指定すると、3600が割り当てられるため
# 最短の120を割り当てるようにしている

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/vd-dns-util.sh"

apikey=$1
root_domain=$2
ttl=$3

create_acme_domain() {
  local root_domain="$1"
  local target_domain="$2"

  # rootDomain をエスケープ（正規表現用に . を \. に変換）
  local escaped_root_domain
  escaped_root_domain=$(echo "$root_domain" | sed 's/\./\\./g; s/\*/\\*/g')

  # サブドメイン抽出
  local sub_domain
  sub_domain=$(echo "$target_domain" | sed -n "s/^\(.\+\)\.${escaped_root_domain}$/\1/p")

  if [ -z "$sub_domain" ]; then
    # サブドメインなし
    echo "_acme-challenge"
  else
    # サブドメインあり
    echo "_acme-challenge.${sub_domain}"
  fi
}

# ValueDomainAPIからレコードを取得
get_result=$(request_get_records "$apikey" "$root_domain")

echo "=== INPUT ==="
echo "$get_result"

get_respcode=$(echo -E "$get_result" | tail -1)
get_respbody=$(echo -E "$get_result" | head -1)
if [[ $get_respcode -ne 200 ]]; then
  echo -e "CODE:$get_respcode\tDNSレコードの取得に失敗しました。"
  echo "$get_respbody"
  exit 10
fi

source_records=$(echo -E "$get_respbody" | jq -r '.results.records')
source_ttl=$(echo -E "$get_respbody" | jq -r '.results.ttl')
source_ns_type=$(echo -E "$get_respbody" | jq -r '.results.ns_type')

acme_domain=$(create_acme_domain "$root_domain" "$CERTBOT_DOMAIN")

# Certbotの情報でレコードを置換
exists_record=$(find_first_record "$source_records" "txt $acme_domain")

new_record="txt $acme_domain \"$CERTBOT_VALIDATION\""
new_records=''

if [[ -z "$exists_record" ]]; then
  new_records=$(append_record "$source_records" "$new_record")
else
  new_records=$(replace_record "$source_records" "txt $acme_domain" "$new_record")
fi

# ValueDomainAPIにあるTTLのバグ対応
adjusted_ttl=$(adjust_ttl $source_ttl)

json=$(
  echo "$new_records" \
    | jq -Rs \
      --arg ns_type "$source_ns_type" \
      --argjson ttl "$adjusted_ttl" \
      '{"ns_type": $ns_type, "records": ., "ttl": $ttl}'
)
# ValueDomainAPIにレコードの更新要求を出す
update_result=$(request_update_records "$apikey" "$root_domain" "$json")

update_respcode=$(echo -E "$update_result" | tail -1)
update_respbody=$(echo -E "$update_result" | head -1)
if [[ $update_respcode -ne 200 ]]; then
  echo -e "CODE:$update_respcode\tDNSレコードの更新に失敗しました。"
  echo "$update_respbody"
  exit 11
fi

echo "=== OUTPUT ==="
echo "$update_respbody"
