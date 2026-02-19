#!/usr/bin/perl
# value-domain-dns-cert-register
# vd-dcr.pl <value-domain-api-key> <root-domain> [ttl]
#
# [ttl]はオプションなので省いてもよい
# 120未満を指定した場合、120として解釈、無指定の場合はAPIから来た値を割り当てるが
# APIから来た値が120未満の場合、120を割り当てる
# これはValue-Domain APIの仕様上、120未満を指定すると、3600が割り当てられるため
# 最短の120を割り当てるようにしている

use strict;
use warnings;
use JSON::PP;
use FindBin qw($Bin);
require "$Bin/vd-dns-util.pl";

my ($apikey, $root_domain, $ttl) = @ARGV;

unless ($apikey && $root_domain) {
    die "Usage: $0 <apikey> <root-domain> [ttl]\n";
}

# _acme-challenge用のドメイン文字列を生成する
# 引数:
#   $root_domain   : ルートドメイン
#   $target_domain : 対象ドメイン
# 戻り値:
#   サブドメインがあれば "_acme-challenge.<subdomain>"、なければ "_acme-challenge"
sub create_acme_domain {
    my ($root_domain, $target_domain) = @_;
    if ($target_domain =~ /^(.+)\.\Q$root_domain\E$/) {
        return "_acme-challenge.$1";
    }
    return "_acme-challenge";
}

# ValueDomainAPIからレコードを取得
my ($get_body, $get_code) = request_get_records($apikey, $root_domain);

print "=== SOURCE DATA ===\n";
print "$get_body\n";

if ($get_code != 200) {
    print STDERR "CODE:$get_code\tDNSレコードの取得に失敗しました。\n";
    print STDERR "$get_body\n";
    exit 10;
}

my $get_json       = decode_json($get_body);
my $source_records = $get_json->{results}{records};
my $source_ttl     = $get_json->{results}{ttl};
my $source_ns_type = $get_json->{results}{ns_type};

my $certbot_domain     = $ENV{CERTBOT_DOMAIN}     or die "CERTBOT_DOMAIN is not set\n";
my $certbot_validation = $ENV{CERTBOT_VALIDATION} or die "CERTBOT_VALIDATION is not set\n";

my $acme_domain = create_acme_domain($root_domain, $certbot_domain);

# Certbotの情報でレコードを追加または置換
my $exists_record = find_first_record($source_records, "txt $acme_domain");
my $new_record    = qq(txt $acme_domain "$certbot_validation");
my $new_records;

if ($exists_record eq '') {
    $new_records = append_record($source_records, $new_record);
} else {
    $new_records = replace_record($source_records, "txt $acme_domain", $new_record);
}

# ValueDomainAPIにあるTTLのバグ対応
my $adjusted_ttl = adjust_ttl($source_ttl + 0);

my $json = encode_json({
    ns_type => $source_ns_type,
    records => $new_records,
    ttl     => $adjusted_ttl,
});

# ValueDomainAPIにレコードの更新要求を出す
my ($update_body, $update_code) = request_update_records($apikey, $root_domain, $json);

if ($update_code != 200) {
    print STDERR "CODE:$update_code\tDNSレコードの更新に失敗しました。\n";
    print STDERR "$update_body\n";
    exit 11;
}

print "=== UPDATED DATA ===\n";
print "$update_body\n";
