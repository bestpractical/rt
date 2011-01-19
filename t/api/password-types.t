#!/usr/bin/perl -w
use strict;
use warnings;

use RT::Test;
use Digest::MD5;

my $root = RT::User->new(RT->SystemUser);
$root->Load("root");

# Salted truncated SHA-256
my $old = $root->__Value("Password");
is(length($old), 40, "Stored as truncated salted SHA-256");
ok($root->IsPassword("password"));
is($root->__Value("Password"), $old, "Unchanged after password check");

# Crypt
$root->_Set( Field => "Password", Value => crypt("something", "salt"));
ok($root->IsPassword("something"), "crypt()ed password works");
is(length($root->__Value("Password")), 40, "And is now upgraded to truncated salted SHA-256");

# MD5, hex
$root->_Set( Field => "Password", Value => Digest::MD5::md5_hex("changed"));
ok($root->IsPassword("changed"), "Unsalted MD5 hex works");
is(length($root->__Value("Password")), 40, "And is now upgraded to truncated salted SHA-256");

# MD5, base64
$root->_Set( Field => "Password", Value => Digest::MD5::md5_base64("new"));
ok($root->IsPassword("new"), "Unsalted MD5 base64 works");
is(length($root->__Value("Password")), 40, "And is now upgraded to truncated salted SHA-256");

