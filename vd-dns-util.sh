#!/bin/bash

# Value-DomainのDNS APIに指定ドメインのDNSレコード設定の問い合わせを行い
# 当該ドメインのDNSレコード設定を取得する
# 引数
#   $1：Value-DomainのAPIトークン
#   $2：ルートドメイン
# 標準出力
#   一行目：HTTPステータスコード
#   二行目：レスポンスボディ（DNSレコード設定）
request_get_records() {
    local apikey=$1
    local root_domain=$2
    resp=$(curl -s -H "Authorization: Bearer $apikey" "https://api.value-domain.com/v1/domains/$root_domain/dns" -w '\n%{http_code}')

    # curlの出力が$body\n$codeで、出力順も同じなので、意味はないが、分かりやすくするために明示的にやっている
    body=$(echo "$resp" | head -1)
    code=$(echo "$resp" | tail -1)

    echo "$body"
    echo $code
}

# Value-DomainのDNSレコードのレコードを検索し
# 一致した先頭一件を取得する
# 引数
#   $1：Value-DomainのDNSレコード
#   $2：検索文字列（先頭一致）
# 標準出力
#   一行目：検索結果の先頭一件。レコードがあればそれを、なければ空文字
find_first_record() {
    local records=$1
    local subject=$2

    find_record=$(echo "$records" | grep "^$subject" | head -1)

    echo "$find_record"
}

# Value-DomainのDNSレコードデータ（records）にレコードを追加する
# 引数
#   $1：DNSレコード本文
#   $2：追加レコード
# 標準出力
#   一行目：処理結果のレコード
append_record() {
    local records=$1
    local record=$2

    # $'\n'と書くことでコード中で実際に改行せずとも、改行した扱いにできる
    new_records=$(echo -n "$records"$'\n'"$record")

    echo "$new_records"
}

# Value-DomainのDNSレコードデータ（records）にあるレコードを置換する
# 引数
#   $1：DNSレコード本文
#   $2：検索文字列（先頭一致）
#   $3：置換するレコード
# 標準出力
#   一行目：処理結果のレコード
replace_record() {
    local records=$1
    local subject=$2
    local replacement=$3

    escaped_replacement=$(echo "$replacement" | sed 's/[&/\\]/\\&/g')
    new_records=$(echo "$records" | sed -E "s/^$subject.+/$escaped_replacement/")

    echo "$new_records"
}

# ttlが120未満であれば120に補正し、そうでなければそのままを返す
# 引数
#   $1：ttl
# 標準出力
#   一行目：処理したttl
adjust_ttl() {
    local ttl=$1

    if [[ $ttl -lt 120 ]]; then
        echo 120
    else
        echo $ttl
    fi
}

# Value-DomainのDNS APIに指定ドメインのDNSレコードの更新要求を投げ
# 更新要求の結果を取得する
# 引数
#   $1：Value-DomainのAPIトークン
#   $2：ルートドメイン
#   $3：更新データのJSON
# 標準出力
#   一行目：HTTPステータスコード
#   二行目：レスポンスボディ
request_update_records() {
    local apikey=$1
    local root_domain=$2
    local json=$3

    resp=$(curl -s -X PUT -H "Authorization: Bearer $apikey" -H "Content-Type: application/json" "https://api.value-domain.com/v1/domains/$root_domain/dns" -d "$json" -w '\n%{http_code}')

    # curlの出力が$body\n$codeで、出力順も同じなので、意味はないが、分かりやすくするために明示的にやっている
    body=$(echo "$resp" | head -1)
    code=$(echo "$resp" | tail -1)

    echo "$body"
    echo $code
}
