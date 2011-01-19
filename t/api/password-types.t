#!/usr/bin/perl -w
use strict;
use warnings;

use RT::Test;
use Digest::MD5;

my $default = "sha512";

my $root = RT::User->new(RT->SystemUser);
$root->Load("root");

# Salted SHA-512 (default)
my $old = $root->__Value("Password");
like($old, qr/^\!$default\!/, "Stored as salted $default");
ok($root->IsPassword("password"));
is($root->__Value("Password"), $old, "Unchanged after password check");

# Crypt
$root->_Set( Field => "Password", Value => crypt("something", "salt"));
ok($root->IsPassword("something"), "crypt()ed password works");
like($root->__Value("Password"), qr/^\!$default\!/, "And is now upgraded to salted $default");

# MD5, hex
$root->_Set( Field => "Password", Value => Digest::MD5::md5_hex("changed"));
ok($root->IsPassword("changed"), "Unsalted MD5 hex works");
like($root->__Value("Password"), qr/^\!$default\!/, "And is now upgraded to salted $default");

# MD5, base64
$root->_Set( Field => "Password", Value => Digest::MD5::md5_base64("new"));
ok($root->IsPassword("new"), "Unsalted MD5 base64 works");
like($root->__Value("Password"), qr/^\!$default\!/, "And is now upgraded to salted $default");

# Salted truncated SHA-256
my $trunc = MIME::Base64::encode_base64(
    "salt" . substr(Digest::SHA::sha256("salt".Digest::MD5::md5("secret")),0,26),
    ""
);
$root->_Set( Field => "Password", Value => $trunc);
ok($root->IsPassword("secret"), "Unsalted MD5 base64 works");
like($root->__Value("Password"), qr/^\!$default\!/, "And is now upgraded to salted $default");
