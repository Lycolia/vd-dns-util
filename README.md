# Value-Domain API Utility for Bash

[Value-DomainのDNS API](https://www.value-domain.com/api/doc/domain/#tag/DNS)を叩くためのユーティリティ関数群。

## 中身

### ./vd-dns-util.sh

ユーティリティ関数群の本体。

`./examples/vddcr.sh`にあるように`source vd-dns-util.sh`して利用する想定。

#### 実装関数

##### request_get_records()

Value-DomainのDNS APIに指定ドメインのDNSレコード設定の問い合わせを行い当該ドメインのDNSレコード設定を取得する。

**引数**

| 順番 | 意味合い                  |
| ---- | ------------------------- |
| `$1` | Value-DomainのAPIトークン |
| `$2` | ルートドメイン            |

**戻り値**

複数行の標準出力をするので、`head`や`tail`で取得して使う。

| 行数 | 意味合い                            | 備考                                                              |
| ---- | ----------------------------------- | ----------------------------------------------------------------- |
| 1    | APIのレスポンスボディ(JSON)         | 一行の文字列で、改行コードは`\\n`としてエスケープされたものが来る |
| 2    | APIのHTTPレスポンスステータスコード |                                                                   |

**実装例**

```bash
get_result=$(request_get_records "$apikey" "$root_domain")

echo "=== INPUT ==="
echo "$get_result"

get_respcode=$(echo -E "$get_result" | tail -1)
if [[ $get_respcode -ne 200 ]]; then
  echo -e "CODE:$get_respcode\tDNSレコードの取得に失敗しました。"
  echo "$update_respbody"
  exit 10
fi
get_respbody=$(echo -E "$get_result" | head -1)

records=$(echo -E "$get_respbody" | jq '.results.records')
ttl=$(echo -E "$get_respbody" | jq -r '.results.ttl')
ns_type=$(echo -E "$get_respbody" | jq '.results.ns_type')
```

##### find_first_record()

Value-DomainのDNSレコードのレコードを検索し、一致した先頭一件を取得する。

**引数**

| 順番 | 意味合い                                | 備考           |
| ---- | --------------------------------------- | -------------- |
| `$1` | APIのレスポンスにある`.results.records` |                |
| `$2` | 検索するレコード文字列（先頭一致）      | `txt hoge`など |

**戻り値**

| 行数 | 意味合い | 備考                                                       |
| ---- | -------- | ---------------------------------------------------------- |
| 1    | 検索結果 | 一致したものがあれば、その最初のレコード行、なければ空文字 |

**実装例**

```bash
exists_record=$(find_first_record "$records" "txt $CERTBOT_DOMAIN")

if [[ -z "$exists_record" ]]; then
  # レコードがなかった時の処理
else
  # レコードがあった時の処理
fi
```

##### append_record()

Value-DomainのDNSレコードデータ（records）にレコードを追加する。

**引数**

| 順番 | 意味合い                                | 備考                                                                                                      |
| ---- | --------------------------------------- | --------------------------------------------------------------------------------------------------------- |
| `$1` | APIのレスポンスにある`.results.records` |                                                                                                           |
| `$2` | 追加するレコード行文字列                | TXTレコードは以下のようにダブルクォートのエスケープが必要<br />`txt hoge \\\"$CERTBOT_VALIDATION\\\"`など |

**戻り値**

| 行数 | 意味合い                         | 備考 |
| ---- | -------------------------------- | ---- |
| 1    | `$1`の末尾に`$2`を結合した文字列 |      |

**実装例**

```bash
# $recordsの中身はDNS APIの.results.records
# $recordの中身はDNSレコード一行分
new_records=$(append_record "$records" "$record")
```

##### replace_record()

Value-DomainのDNSレコードデータ（records）にあるレコードを置換する。

検索文字列に一致した行のレコードを置換するレコードで置き換える。

**引数**

| 順番 | 意味合い                                | 備考                                                                                                      |
| ---- | --------------------------------------- | --------------------------------------------------------------------------------------------------------- |
| `$1` | APIのレスポンスにある`.results.records` |                                                                                                           |
| `$2` | 検索文字列（先頭一致）                  | `txt hoge"`など                                                                                           |
| `$3` | 置換するレコード                        | TXTレコードは以下のようにダブルクォートのエスケープが必要<br />`txt hoge \\\"$CERTBOT_VALIDATION\\\"`など |

**戻り値**

| 行数 | 意味合い                                                 | 備考 |
| ---- | -------------------------------------------------------- | ---- |
| 1    | `$1`の中にある`$2`で始まるレコードを`$3`で置換した文字列 |      |

**実装例**

```bash
new_record="txt $CERTBOT_DOMAIN \\\"$CERTBOT_VALIDATION\\\""
new_records=$(replace_record "$source_records" "txt $CERTBOT_DOMAIN" "$new_record")
```

##### adjust_ttl()

ttlが120未満であれば120に補正し、そうでなければそのままを返す。

Value-DomainのAPIはttl: 120を下限としており、これを下回る場合、3600が設定されて困るので、それを回避するために下限値を出すための処理。

| 順番 | 意味合い  | 備考 |
| ---- | --------- | ---- |
| `$1` | ttlの秒数 |      |

**戻り値**

| 行数 | 意味合い                                 | 備考 |
| ---- | ---------------------------------------- | ---- |
| 1    | `$1`が120未満なら120、そうでなければ`$1` |      |

**実装例**

```bash
source_ttl=60
# この場合120
adjusted_ttl=$(adjust_ttl $source_ttl)

source_ttl=130
# この場合130
adjusted_ttl=$(adjust_ttl $source_ttl)
```

##### request_update_records()

Value-DomainのDNS APIに指定ドメインのDNSレコード更新の要求行い当該ドメインのDNSレコード設定を更新する。

**引数**

| 順番 | 意味合い                  | 備考                                                                           |
| ---- | ------------------------- | ------------------------------------------------------------------------------ |
| `$1` | Value-DomainのAPIトークン |                                                                                |
| `$2` | ルートドメイン            |                                                                                |
| `$3` | 更新データのJSON          | 中身の書式は`"{\"ns_type\":"<文字列>",\"records\":"<文字列>",\"ttl\":<数値>}"` |

**戻り値**

複数行の標準出力をするので、`head`や`tail`で取得して使う。

| 行数 | 意味合い                            | 備考                                                              |
| ---- | ----------------------------------- | ----------------------------------------------------------------- |
| 1    | APIのレスポンスボディ(JSON)         | 一行の文字列で、改行コードは`\\n`としてエスケープされたものが来る |
| 2    | APIのHTTPレスポンスステータスコード |                                                                   |

**実装例**

```bash
json="{\"ns_type\":$source_ns_type,\"records\":$new_records,\"ttl\":$adjusted_ttl}"
# ValueDomainAPIにレコードの更新要求を出す
update_result=$(request_update_records "$apikey" "$root_domain" "$json")

update_respcode=$(echo -E "$update_result" | tail -1)
update_respbody=$(echo -E "$update_result" | head -1)
if [[ $update_respcode -ne 200 ]]; then
  echo -e "CODE:$update_respcode\tDNSレコードの更新に失敗しました。"
  echo "$update_respbody"
  exit 11
fi
```

### ./examples/vddcr.sh

実装サンプルで、中身はValue-DomainでCertbotのDNS認証を自動化するためのツール。

```bash
sudo certbot certonly --manual -n \
  --preferred-challenges dns \
  --agree-tos -m <your-email> \
  --manual-auth-hook "vddcr <value-domain-api-key> <root-domain> <optional:ttl>" \
  -d <target-domain>
```

### test_vd-dns-util.bats

テストファイル。

## テストの実行方法

1. Bash Automated Testing Systemのインストール
   ```bash
   sudo apt install bats
   ```
2. テストファイルの実行
   ```bash
   ./test_vd-dns-util.bats
   ```

## ライセンス

MIT
