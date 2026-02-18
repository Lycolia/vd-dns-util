#!/usr/bin/env bats

#
# 実行方法:
#   bats test_vd-dns-util.bats
#   或いは、実行権限を与えたうえで
#   ./test_vd-dns-util.bats
# batsがなければインストール:
#   sudo apt install bats
#

# ========================================
# テスト共通セットアップ
# ========================================
setup() {
    # テスト対象スクリプトの読み込み
    source "$BATS_TEST_DIRNAME/vd-dns-util.sh"

    # curl モック用の一時ディレクトリ
    MOCK_BIN_DIR="$(mktemp -d)"
    # モック curl を PATH の先頭に入れる
    export ORIGINAL_PATH="$PATH"
    export PATH="$MOCK_BIN_DIR:$PATH"
}

teardown() {
    export PATH="$ORIGINAL_PATH"
    rm -rf "$MOCK_BIN_DIR"
}

# curl のモックを作成するヘルパー
# 引数: $1=出力するボディ $2=出力するHTTPステータスコード
create_curl_mock() {
    local mock_body="$1"
    local mock_code=$2
    cat > "$MOCK_BIN_DIR/curl" <<SCRIPT
#!/bin/bash
# -w '\n%{http_code}' の代わりに固定値を返す
echo '$mock_body'
echo $mock_code
SCRIPT
    chmod +x "$MOCK_BIN_DIR/curl"
}

# ========================================
# adjust_ttl()のテスト
# ========================================
@test "adjust_ttl: TTLが120未満なら120を返す" {
    result=$(adjust_ttl 119)
    [ "$result" = "120" ]
}

@test "adjust_ttl: TTLが120ならそのまま120を返す" {
    result=$(adjust_ttl 120)
    [ "$result" = "120" ]
}

@test "adjust_ttl: TTLが0なら120を返す" {
    result=$(adjust_ttl 0)
    [ "$result" = "120" ]
}

@test "adjust_ttl: TTLが1なら120を返す" {
    result=$(adjust_ttl 1)
    [ "$result" = "120" ]
}

@test "adjust_ttl: TTLが121ならそのまま121を返す" {
    result=$(adjust_ttl 121)
    [ "$result" = "121" ]
}

# ========================================
# find_first_record()のテスト
# ========================================
@test "find_first_record: 一致するレコードがあればその行を返す" {
    local records=$'a www 192.168.1.1\na mail 192.168.1.2\ncname ftp www.example.com.'
    result=$(find_first_record "$records" "a www")
    [ "$result" = "a www 192.168.1.1" ]
}

@test "find_first_record: 先頭一致で検索する" {
    local records=$'a www 192.168.1.1\na www2 192.168.1.3\ncname ftp www.example.com.'
    result=$(find_first_record "$records" "a www2")
    [ "$result" = "a www2 192.168.1.3" ]
}

@test "find_first_record: 一致するレコードがなければ空文字を返す" {
    local records=$'a www 192.168.1.1\na mail 192.168.1.2\ncname ftp www.example.com.'
    result=$(find_first_record "$records" "txt _acme")
    [ "$result" = "" ]
}

@test "find_first_record: 空のレコードなら空文字を返す" {
    local records=''
    result=$(find_first_record "$records" "a www")
    [ "$result" = "" ]
}

@test "find_first_record: 複数一致する場合は一番先頭の一件を返す" {
    local records=$'a www 192.168.1.1\na www 192.168.1.2\ncname ftp www.example.com.'
    result=$(find_first_record "$records" "a www")
    [ "$result" = "a www 192.168.1.1" ]
}

@test "find_first_record: txtレコードの検索" {
    local records=$'a www 192.168.1.1\ntxt _acme-challenge abc123\na mail 10.0.0.1'
    result=$(find_first_record "$records" "txt _acme-challenge")
    [ "$result" = "txt _acme-challenge abc123" ]
}

# ========================================
# append_record()のテスト
# ========================================
@test "append_record: レコードを末尾に追加できる" {
    local records='a www 192.168.1.1'
    local new_record="a mail 192.168.1.2"
    result=$(append_record "$records" "$new_record")
    [ "$result" = $'a www 192.168.1.1\na mail 192.168.1.2' ]
}

@test "append_record: 複数行あるレコードに追加できる" {
    local records=$'a www 192.168.1.1\na mail 192.168.1.2'
    local new_record="cname ftp www.example.com."
    result=$(append_record "$records" "$new_record")
    [ "$result" = $'a www 192.168.1.1\na mail 192.168.1.2\ncname ftp www.example.com.' ]
}

@test "append_record: txtレコードを追加できる" {
    local records='a www 192.168.1.1'
    local new_record="txt _acme-challenge \"abcdef12345\""
    result=$(append_record "$records" "$new_record")
    [ "$result" = $'a www 192.168.1.1\ntxt _acme-challenge "abcdef12345"' ]
}

# ========================================
# replace_record()のテスト
# ========================================
@test "replace_record: 既存レコードを置換できる" {
    local records=$'a www 192.168.1.1\na mail 192.168.1.2'
    local subject="a mail"
    local replacement="a mail 10.0.0.1"
    result=$(replace_record "$records" "$subject" "$replacement")
    [ "$result" = $'a www 192.168.1.1\na mail 10.0.0.1' ]
}

@test "replace_record: 置換対象が見つからなければ元のまま" {
    local records=$'a www 192.168.1.1\na mail 192.168.1.2'
    local subject="cname ftp"
    local replacement="cname ftp www.example.com."
    result=$(replace_record "$records" "$subject" "$replacement")
    [ "$result" = $'a www 192.168.1.1\na mail 192.168.1.2' ]
}

@test "replace_record: txtレコードの値を更新できる" {
    local records=$'a www 192.168.1.1\ntxt _acme-challenge oldvalue'
    local subject="txt _acme-challenge"
    local replacement="txt _acme-challenge newvalue"
    result=$(replace_record "$records" "$subject" "$replacement")
    [ "$result" = $'a www 192.168.1.1\ntxt _acme-challenge newvalue' ]
}

# ========================================
# request_get_records()のテスト
# ========================================
@test "request_get_records: 正常系 - 200でレコードが返る" {
    create_curl_mock '{"results":{"records":"a www 192.168.1.1"}}' 200

    result=$(request_get_records "test-api-key" "example.com")
    body=$(echo "$result" | head -1)
    code=$(echo "$result" | tail -1)

    [ $code -eq 200 ]
    [[ "$body" == *"records"* ]]
}

@test "request_get_records: 異常系 - 401認証エラー" {
    create_curl_mock '{"error":"Unauthorized"}' 401

    result=$(request_get_records "invalid-key" "example.com")
    code=$(echo "$result" | tail -1)

    [ $code -eq 401 ]
}

@test "request_get_records: 異常系 - 404ドメイン未検出" {
    create_curl_mock '{"error":"Not Found"}' 404

    result=$(request_get_records "test-api-key" "nonexistent.com")
    code=$(echo "$result" | tail -1)

    [ $code -eq 404 ]
}

# ========================================
# request_update_records()のテスト
# ========================================
@test "request_update_records: 正常系 - 200で更新成功" {
    create_curl_mock '{"results":{"status":"ok"}}' 200

    local json='{"dns_records":"a www 192.168.1.1\n"}'
    result=$(request_update_records "test-api-key" "example.com" "$json")
    body=$(echo "$result" | head -1)
    code=$(echo "$result" | tail -1)

    [ $code -eq 200 ]
    [[ "$body" == *"ok"* ]]
}

@test "request_update_records: 異常系 - 401認証エラー" {
    create_curl_mock '{"error":"Unauthorized"}' 401

    local json='{"dns_records":"a www 192.168.1.1\n"}'
    result=$(request_update_records "bad-key" "example.com" "$json")
    code=$(echo "$result" | tail -1)

    [ $code -eq 401 ]
}

@test "request_update_records: 異常系 - 400不正リクエスト" {
    create_curl_mock '{"error":"Bad Request"}' 400

    local json='invalid-json'
    result=$(request_update_records "test-api-key" "example.com" "$json")
    code=$(echo "$result" | tail -1)

    [ $code -eq 400 ]
}

# ========================================
# curl()モックへの引数検証テスト
# ========================================
@test "request_get_records: curlに正しいURLとAuthorizationヘッダーが渡される" {
    # 引数をファイルに記録するモック
    cat > "$MOCK_BIN_DIR/curl" <<'SCRIPT'
#!/bin/bash
echo "$@" > /tmp/bats_curl_args
echo '{"results":{}}'
echo '200'
SCRIPT
    chmod +x "$MOCK_BIN_DIR/curl"

    request_get_records "my-secret-token" "example.jp" > /dev/null
    local args
    args=$(cat /tmp/bats_curl_args)

    [[ "$args" == *"Bearer my-secret-token"* ]]
    [[ "$args" == *"example.jp/dns"* ]]
    rm -f /tmp/bats_curl_args
}

@test "request_update_records: curlにPUTメソッドとContent-Typeが渡される" {
    cat > "$MOCK_BIN_DIR/curl" <<'SCRIPT'
#!/bin/bash
echo "$@" > /tmp/bats_curl_args
echo '{"results":{}}'
echo '200'
SCRIPT
    chmod +x "$MOCK_BIN_DIR/curl"

    request_update_records "my-secret-token" "example.jp" '{"records":"test"}' > /dev/null
    local args
    args=$(cat /tmp/bats_curl_args)

    [[ "$args" == *"PUT"* ]]
    [[ "$args" == *"Content-Type: application/json"* ]]
    [[ "$args" == *"Bearer my-secret-token"* ]]
    rm -f /tmp/bats_curl_args
}
