#!/usr/bin/perl
#
# 実行方法:
#   perl test_vd-dns-util.pl
#   或いは、実行権限を与えたうえで
#   ./test_vd-dns-util.pl
#
# Test::More はPerlコアモジュールのため追加インストール不要
#

use strict;
use warnings;
use Test::More;
use FindBin qw($Bin);

require "$Bin/vd-dns-util.pl";

# HTTP::Tiny::request をモックするヘルパー
# 引数: $body=レスポンスボディ, $code=HTTPステータスコード
# 戻り値: コードブロック内でモックを有効にするための無名subを返す
sub make_mock_response {
    my ($body, $code) = @_;
    return sub { return { status => $code, content => $body } };
}

# ========================================
# adjust_ttl()のテスト
# ========================================
is(adjust_ttl(119), 120, 'adjust_ttl: TTLが120未満なら120を返す');
is(adjust_ttl(120), 120, 'adjust_ttl: TTLが120ならそのまま120を返す');
is(adjust_ttl(0),   120, 'adjust_ttl: TTLが0なら120を返す');
is(adjust_ttl(1),   120, 'adjust_ttl: TTLが1なら120を返す');
is(adjust_ttl(121), 121, 'adjust_ttl: TTLが121ならそのまま121を返す');

# ========================================
# find_first_record()のテスト
# ========================================
{
    my $records = "a www 192.168.1.1\na mail 192.168.1.2\ncname ftp www.example.com.";
    is(
        find_first_record($records, 'a www'),
        'a www 192.168.1.1',
        'find_first_record: 一致するレコードがあればその行を返す',
    );
}
{
    my $records = "a www 192.168.1.1\na www2 192.168.1.3\ncname ftp www.example.com.";
    is(
        find_first_record($records, 'a www2'),
        'a www2 192.168.1.3',
        'find_first_record: 先頭一致で検索する',
    );
}
{
    my $records = "a www 192.168.1.1\na mail 192.168.1.2\ncname ftp www.example.com.";
    is(
        find_first_record($records, 'txt _acme'),
        '',
        'find_first_record: 一致するレコードがなければ空文字を返す',
    );
}
{
    my $records = '';
    is(
        find_first_record($records, 'a www'),
        '',
        'find_first_record: 空のレコードなら空文字を返す',
    );
}
{
    my $records = "a www 192.168.1.1\na www 192.168.1.2\ncname ftp www.example.com.";
    is(
        find_first_record($records, 'a www'),
        'a www 192.168.1.1',
        'find_first_record: 複数一致する場合は一番先頭の一件を返す',
    );
}
{
    my $records = "a www 192.168.1.1\ntxt _acme-challenge abc123\na mail 10.0.0.1";
    is(
        find_first_record($records, 'txt _acme-challenge'),
        'txt _acme-challenge abc123',
        'find_first_record: txtレコードの検索',
    );
}

# ========================================
# append_record()のテスト
# ========================================
{
    my $records = 'a www 192.168.1.1';
    is(
        append_record($records, 'a mail 192.168.1.2'),
        "a www 192.168.1.1\na mail 192.168.1.2",
        'append_record: レコードを末尾に追加できる',
    );
}
{
    my $records = "a www 192.168.1.1\na mail 192.168.1.2";
    is(
        append_record($records, 'cname ftp www.example.com.'),
        "a www 192.168.1.1\na mail 192.168.1.2\ncname ftp www.example.com.",
        'append_record: 複数行あるレコードに追加できる',
    );
}
{
    my $records = 'a www 192.168.1.1';
    is(
        append_record($records, 'txt _acme-challenge "abcdef12345"'),
        "a www 192.168.1.1\ntxt _acme-challenge \"abcdef12345\"",
        'append_record: txtレコードを追加できる',
    );
}

# ========================================
# replace_record()のテスト
# ========================================
{
    my $records = "a www 192.168.1.1\na mail 192.168.1.2";
    is(
        replace_record($records, 'a mail', 'a mail 10.0.0.1'),
        "a www 192.168.1.1\na mail 10.0.0.1",
        'replace_record: 既存レコードを置換できる',
    );
}
{
    my $records = "a www 192.168.1.1\na mail 192.168.1.2";
    is(
        replace_record($records, 'cname ftp', 'cname ftp www.example.com.'),
        "a www 192.168.1.1\na mail 192.168.1.2",
        'replace_record: 置換対象が見つからなければ元のまま',
    );
}
{
    my $records = "a www 192.168.1.1\ntxt _acme-challenge oldvalue";
    is(
        replace_record($records, 'txt _acme-challenge', 'txt _acme-challenge newvalue'),
        "a www 192.168.1.1\ntxt _acme-challenge newvalue",
        'replace_record: txtレコードの値を更新できる',
    );
}

# ========================================
# request_get_records()のテスト
# ========================================
{
    no warnings 'redefine';
    local *HTTP::Tiny::request = make_mock_response(
        '{"results":{"records":"a www 192.168.1.1"}}', 200
    );

    my ($body, $code) = request_get_records('test-api-key', 'example.com');
    is($code, 200, 'request_get_records: 正常系 - 200でレコードが返る');
    like($body, qr/records/, 'request_get_records: 正常系 - ボディにrecordsが含まれる');
}
{
    no warnings 'redefine';
    local *HTTP::Tiny::request = make_mock_response('{"error":"Unauthorized"}', 401);

    my ($body, $code) = request_get_records('invalid-key', 'example.com');
    is($code, 401, 'request_get_records: 異常系 - 401認証エラー');
}
{
    no warnings 'redefine';
    local *HTTP::Tiny::request = make_mock_response('{"error":"Not Found"}', 404);

    my ($body, $code) = request_get_records('test-api-key', 'nonexistent.com');
    is($code, 404, 'request_get_records: 異常系 - 404ドメイン未検出');
}

# リクエスト内容の検証テスト
{
    my ($captured_url, $captured_auth);
    no warnings 'redefine';
    local *HTTP::Tiny::request = sub {
        my (undef, $method, $url, $opts) = @_;
        $captured_url  = $url;
        $captured_auth = $opts->{headers}{'Authorization'};
        return { status => 200, content => '{"results":{}}' };
    };

    request_get_records('my-secret-token', 'example.jp');
    like($captured_url,  qr|example\.jp/dns|,          'request_get_records: 正しいURLが渡される');
    like($captured_auth, qr/Bearer my-secret-token/,   'request_get_records: 正しいAuthorizationヘッダーが渡される');
}

# ========================================
# request_update_records()のテスト
# ========================================
{
    no warnings 'redefine';
    local *HTTP::Tiny::request = make_mock_response('{"results":{"status":"ok"}}', 200);

    my $json = '{"dns_records":"a www 192.168.1.1\n"}';
    my ($body, $code) = request_update_records('test-api-key', 'example.com', $json);
    is($code, 200, 'request_update_records: 正常系 - 200で更新成功');
    like($body, qr/ok/, 'request_update_records: 正常系 - ボディにokが含まれる');
}
{
    no warnings 'redefine';
    local *HTTP::Tiny::request = make_mock_response('{"error":"Unauthorized"}', 401);

    my ($body, $code) = request_update_records('bad-key', 'example.com', '{}');
    is($code, 401, 'request_update_records: 異常系 - 401認証エラー');
}
{
    no warnings 'redefine';
    local *HTTP::Tiny::request = make_mock_response('{"error":"Bad Request"}', 400);

    my ($body, $code) = request_update_records('test-api-key', 'example.com', 'invalid-json');
    is($code, 400, 'request_update_records: 異常系 - 400不正リクエスト');
}

# リクエスト内容の検証テスト
{
    my ($captured_method, $captured_ct, $captured_auth);
    no warnings 'redefine';
    local *HTTP::Tiny::request = sub {
        my (undef, $method, $url, $opts) = @_;
        $captured_method = $method;
        $captured_ct     = $opts->{headers}{'Content-Type'};
        $captured_auth   = $opts->{headers}{'Authorization'};
        return { status => 200, content => '{"results":{}}' };
    };

    request_update_records('my-secret-token', 'example.jp', '{"records":"test"}');
    is($captured_method, 'PUT',                        'request_update_records: PUTメソッドが渡される');
    like($captured_ct,   qr|application/json|,         'request_update_records: Content-Typeが渡される');
    like($captured_auth, qr/Bearer my-secret-token/,   'request_update_records: 正しいAuthorizationヘッダーが渡される');
}

done_testing();