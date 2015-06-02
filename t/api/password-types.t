use strict;
use warnings;

use RT::Test;
use Digest::MD5;

my $default = "bcrypt";

my $root = RT::User->new(RT->SystemUser);
$root->Load("root");

# bcrypt (default)
my $old = $root->__Value("Password");
like($old, qr/^\!$default\!/, "Stored as salted $default");
ok($root->IsPassword("password"));
is($root->__Value("Password"), $old, "Unchanged after password check");

# bcrypt (smaller number of rounds)
my $rounds = RT->Config->Get("BcryptCost");
my $salt = Crypt::Eksblowfish::Bcrypt::en_base64("a"x16);
$root->_Set( Field => "Password", Value => RT::User->_GeneratePassword_bcrypt("smaller", 6, $salt) );
like($root->__Value("Password"), qr/^\!$default\!06\!/, "Stored with a smaller number of rounds");
ok($root->IsPassword("smaller"), "Smaller number of bcrypt rounds works");
like($root->__Value("Password"), qr/^\!$default\!$rounds\!/, "And is now upgraded to $rounds rounds");

# Salted SHA-512, one round
$root->_Set( Field => "Password", Value => RT::User->_GeneratePassword_sha512("other", "salt") );
ok($root->IsPassword("other"), "SHA-512 password works");
like($root->__Value("Password"), qr/^\!$default\!/, "And is now upgraded to salted $default");

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

# Non-ASCII salted truncated SHA-256
my $non_ascii_trunc = MIME::Base64::encode_base64(
    "salt" . substr(Digest::SHA::sha256("salt".Digest::MD5::md5("áěšý")),0,26),
    ""
);
$root->_Set( Field => "Password", Value => $non_ascii_trunc);
ok($root->IsPassword(Encode::decode("UTF-8", "áěšý")), "Unsalted MD5 base64 works");
like($root->__Value("Password"), qr/^\!$default\!/, "And is now upgraded to salted $default");
