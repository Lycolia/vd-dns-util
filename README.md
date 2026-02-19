# Value-Domain DNS API Utility for Perl

[Value-DomainのDNS API](https://www.value-domain.com/api/doc/domain/#tag/DNS)をPerlから叩くためのユーティリティ関数群。

## 必要なモジュール

すべてPerlコアモジュール（Perl 5.14以降）のため、追加インストール不要。

| モジュール   | 用途                      | コア収録バージョン |
| ------------ | ------------------------- | ------------------ |
| `HTTP::Tiny` | HTTPリクエスト            | Perl 5.14          |
| `JSON::PP`   | JSONのエンコード/デコード | Perl 5.14          |
| `FindBin`    | スクリプトのパス解決      | Perl 5.004         |
| `Test::More` | テスト                    | Perl 5.004         |

## [`./vd-dns-util.pl`] ユーティリティ関数群の本体

`./vd-dcr.pl`にあるように`require`して利用する想定。

```perl
use FindBin qw($Bin);
require "$Bin/vd-dns-util.pl";
```

### 実装関数

#### `request_get_records($apikey, $root_domain)`

Value-DomainのDNS APIに指定ドメインのDNSレコード設定の問い合わせを行い当該ドメインのDNSレコード設定を取得する。

**引数**

| 変数名         | 意味合い                  |
| -------------- | ------------------------- |
| `$apikey`      | Value-DomainのAPIトークン |
| `$root_domain` | ルートドメイン            |

**戻り値**

リストで `($body, $code)` を返す。

| 変数名  | 意味合い                            | 備考 |
| ------- | ----------------------------------- | ---- |
| `$body` | APIのレスポンスボディ(JSON文字列)   |      |
| `$code` | APIのHTTPレスポンスステータスコード |      |

**実装例**

```perl
my ($get_body, $get_code) = request_get_records($apikey, $root_domain);

if ($get_code != 200) {
    print STDERR "CODE:$get_code\tDNSレコードの取得に失敗しました。\n";
    exit 10;
}

use JSON::PP;
my $json         = decode_json($get_body);
my $records      = $json->{results}{records};
my $ttl          = $json->{results}{ttl};
my $ns_type      = $json->{results}{ns_type};
```

#### `find_first_record($records, $subject)`

Value-DomainのDNSレコードのレコードを検索し、一致した先頭一件を取得する。

**引数**

| 変数名     | 意味合い                                | 備考           |
| ---------- | --------------------------------------- | -------------- |
| `$records` | APIのレスポンスにある`.results.records` |                |
| `$subject` | 検索するレコード文字列（先頭一致）      | `txt hoge`など |

**戻り値**

一致したものがあれば、その最初のレコード行。なければ空文字。

**実装例**

```perl
my $exists = find_first_record($records, "txt $certbot_domain");

if ($exists eq '') {
    # レコードがなかった時の処理
} else {
    # レコードがあった時の処理
}
```

#### `append_record($records, $record)`

Value-DomainのDNSレコードデータ（records）にレコードを追加する。

**引数**

| 変数名     | 意味合い                                |
| ---------- | --------------------------------------- |
| `$records` | APIのレスポンスにある`.results.records` |
| `$record`  | 追加するレコード行文字列                |

**戻り値**

`$records`の末尾に`$record`を追加した文字列。

**実装例**

```perl
# $records はDNS APIの .results.records
# $record はDNSレコード一行分
my $new_records = append_record($records, $record);
```

#### `replace_record($records, $subject, $replacement)`

Value-DomainのDNSレコードデータ（records）にあるレコードを置換する。

検索文字列に一致した行のレコードを置換するレコードで置き換える。

**引数**

| 変数名         | 意味合い                                |
| -------------- | --------------------------------------- |
| `$records`     | APIのレスポンスにある`.results.records` |
| `$subject`     | 検索文字列（先頭一致）                  |
| `$replacement` | 置換するレコード行                      |

**戻り値**

`$records`の中にある`$subject`で始まるレコードを`$replacement`で置換した文字列。

**実装例**

```perl
my $new_record  = qq(txt $acme_domain "$certbot_validation");
my $new_records = replace_record($source_records, "txt $acme_domain", $new_record);
```

#### `adjust_ttl($ttl)`

ttlが120未満であれば120に補正し、そうでなければそのままを返す。

これはValue-Domain APIの仕様上、ttlに120未満を指定すると、3600が割り当てられるため、最短の120を割り当てるようにするための補助関数である。

**引数**

| 変数名 | 意味合い  |
| ------ | --------- |
| `$ttl` | ttlの秒数 |

**戻り値**

`$ttl`が120未満なら120、そうでなければ`$ttl`。

**実装例**

```perl
my $source_ttl   = 60;
my $adjusted_ttl = adjust_ttl($source_ttl);  # => 120

my $source_ttl   = 130;
my $adjusted_ttl = adjust_ttl($source_ttl);  # => 130
```

#### `request_update_records($apikey, $root_domain, $json)`

Value-DomainのDNS APIに指定ドメインのDNSレコード更新の要求行い当該ドメインのDNSレコード設定を更新する。

**引数**

| 変数名         | 意味合い                  | 備考                                                              |
| -------------- | ------------------------- | ----------------------------------------------------------------- |
| `$apikey`      | Value-DomainのAPIトークン |                                                                   |
| `$root_domain` | ルートドメイン            |                                                                   |
| `$json`        | 更新データのJSON文字列    | `{"ns_type":"<文字列>","records":"<文字列>","ttl":<数値>}` の形式 |

**戻り値**

リストで `($body, $code)` を返す。

| 変数名  | 意味合い                            |
| ------- | ----------------------------------- |
| `$body` | APIのレスポンスボディ(JSON文字列)   |
| `$code` | APIのHTTPレスポンスステータスコード |

**実装例**

```perl
use JSON::PP;
my $json = encode_json({
    ns_type => $source_ns_type,
    records => $new_records,
    ttl     => $adjusted_ttl,
});

my ($update_body, $update_code) = request_update_records($apikey, $root_domain, $json);

if ($update_code != 200) {
    print STDERR "CODE:$update_code\tDNSレコードの更新に失敗しました。\n";
    exit 11;
}
```

## [`./vd-dcr.pl`] Value-DomainでCertbotのDNS認証を自動化するためのツール

`./vd-dns-util.pl`を利用した実装サンプルでもある。

### 動作確認環境

- Ubuntu 24.04.3 LTS, certbot 2.9.0, Perl 5.38

### 使い方

1. certbotがない場合インストールする
   ```bash
   sudo apt install certbot
   ```
2. 本リポジトリの中身を任意の場所に展開し、適切な実行権限を付与する
   ```bash
   chmod +x /path/to/vd-dcr.pl
   ```
3. 証明書を作るためのコマンドを叩く
   ```bash
   sudo certbot certonly --manual -n \
     --preferred-challenges dns \
     --agree-tos -m <your-email> \
     --manual-auth-hook "/path/to/vd-dcr.pl <value-domain-api-key> <root-domain> <optional:ttl>" \
     -d <target-domain>
   ```
   **記述例**
   ```bash
   sudo certbot certonly --manual -n \
     --preferred-challenges dns \
     --agree-tos -m postmaster@example.com \
     --manual-auth-hook "/path/to/vd-dcr.pl x9FwKp3RmT7vLnYq2sUcBj6hXoDiA8gZeJrN4aMbQV5tWlCy0EdGuHfS1oIxP9wKmR7nTvLjYq3sUcBp6hXoZiD2gJeKr4aMbQkV example.com" \
     -d hoge.example.com
   ```

apt経由でインストールした場合、以降は勝手に自動更新が走るはず。

何故なら、`/etc/cron.d/certbot`や`cat /usr/lib/systemd/system/certbot.service`には定期的な更新処理が記述されており、これらは恐らく`/etc/letsencrypt/renewal/*.conf`を参照して更新しているからだ。

`/etc/letsencrypt/renewal/*.conf`には、過去に実行した証明書更新用の設定が書き込まれており、態々毎回フルパラメーターを指定せずとも動くようになっているものと思われる。

この辺りは`sudo certbot renew --no-random-sleep-on-renew`を実行するとわかる。

### 既知の問題

1. ワイルドカードドメインに対応していない（それっぽいコードは書いているが、未検証）

## ライセンス

MIT
