#!/usr/bin/perl
use strict;
use warnings;
use HTTP::Tiny;

my $API_BASE_URL = 'https://api.value-domain.com/v1/domains';

# Value-DomainのDNS APIに指定ドメインのDNSレコード設定の問い合わせを行い
# 当該ドメインのDNSレコード設定を取得する
# 引数:
#   $apikey      : Value-DomainのAPIトークン
#   $root_domain : ルートドメイン
# 戻り値: ($body, $code) のリスト
#   $body : レスポンスボディ（JSON文字列）
#   $code : HTTPステータスコード
sub request_get_records {
    my ($apikey, $root_domain) = @_;
    my $http = HTTP::Tiny->new;
    my $url  = "$API_BASE_URL/$root_domain/dns";
    my $resp = $http->request('GET', $url, {
        headers => { 'Authorization' => "Bearer $apikey" },
    });
    return ($resp->{content}, $resp->{status});
}

# Value-DomainのDNSレコードのレコードを検索し
# 一致した先頭一件を取得する
# 引数:
#   $records : DNSレコード本文（複数行文字列）
#   $subject : 検索文字列（先頭一致）
# 戻り値:
#   一致したレコード行。なければ空文字
sub find_first_record {
    my ($records, $subject) = @_;
    for my $line (split /\n/, $records) {
        return $line if $line =~ /^\Q$subject\E/;
    }
    return '';
}

# Value-DomainのDNSレコードデータ（records）にレコードを追加する
# 引数:
#   $records : DNSレコード本文（複数行文字列）
#   $record  : 追加するレコード行
# 戻り値:
#   末尾に$recordを追加したレコード
sub append_record {
    my ($records, $record) = @_;
    return "$records\n$record";
}

# Value-DomainのDNSレコードデータ（records）にあるレコードを置換する
# 引数:
#   $records     : DNSレコード本文（複数行文字列）
#   $subject     : 検索文字列（先頭一致）
#   $replacement : 置換するレコード行
# 戻り値:
#   $subjectにマッチした行を$replacementで置換したレコード
sub replace_record {
    my ($records, $subject, $replacement) = @_;
    my @lines = split /\n/, $records;
    for my $line (@lines) {
        $line = $replacement if $line =~ /^\Q$subject\E/;
    }
    return join "\n", @lines;
}

# ttlが120未満であれば120に補正し、そうでなければそのままを返す
# これはValue-Domain APIの仕様上、120未満を指定すると、3600が割り当てられるため
# 最短の120を割り当てるようにするための補助関数である
# 引数:
#   $ttl : ttl
# 戻り値:
#   $ttlが120未満なら120、そうでなければ$ttl
sub adjust_ttl {
    my ($ttl) = @_;
    return $ttl < 120 ? 120 : $ttl;
}

# Value-DomainのDNS APIに指定ドメインのDNSレコードの更新要求を投げ
# 更新要求の結果を取得する
# 引数:
#   $apikey      : Value-DomainのAPIトークン
#   $root_domain : ルートドメイン
#   $json        : 更新データのJSON文字列
# 戻り値: ($body, $code) のリスト
#   $body : レスポンスボディ（JSON文字列）
#   $code : HTTPステータスコード
sub request_update_records {
    my ($apikey, $root_domain, $json) = @_;
    my $http = HTTP::Tiny->new;
    my $url  = "$API_BASE_URL/$root_domain/dns";
    my $resp = $http->request('PUT', $url, {
        headers => {
            'Authorization' => "Bearer $apikey",
            'Content-Type'  => 'application/json',
        },
        content => $json,
    });
    return ($resp->{content}, $resp->{status});
}

1;