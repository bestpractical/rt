#!/usr/bin/perl

use strict;
use warnings;

use RT::Test tests => 16;

use_ok 'RT::Articles';
use_ok 'RT::Classes';
use_ok 'RT::Class';

$RT::SystemUser || die ;# just shut up the warning
$RT::System     || die; # just shut up the warning;


my $root = RT::CurrentUser->new('root');
ok ($root->Id, "Loaded root");
my $cl = RT::Class->new($root);
ok (UNIVERSAL::isa($cl, 'RT::Class'), "the new class is a class");

my ($id, $msg) = $cl->Create(Name => 'Test-'.$$, Description => 'A test class');

ok ($id, $msg);

# no duplicate class names should be allowed
($id, $msg) = $cl->Create(Name => 'Test-'.$$, Description => 'A test class');

ok (!$id, $msg);

#class name should be required

($id, $msg) = $cl->Create(Name => '', Description => 'A test class');

ok (!$id, $msg);



$cl->Load('Test-'.$$);
ok($cl->id, "Loaded the class we want");



# Create a new user. make sure they can't create a class

my $u= RT::User->new($RT::SystemUser);
$u->Create(Name => "RTFMTest".time, Privileged => 1);
ok ($u->Id, "Created a new user");

# Make sure you can't create a group with no acls
$cl = RT::Class->new($u);
ok (UNIVERSAL::isa($cl, 'RT::Class'), "the new class is a class");

($id, $msg) = $cl->Create(Name => 'Test-nobody'.$$, Description => 'A test class');


ok (!$id, $msg. "- Can not create classes as a random new user - " .$u->Id);
$u->PrincipalObj->GrantRight(Right =>'AdminClass', Object => $RT::System);
($id, $msg) = $cl->Create(Name => 'Test-nobody-'.$$, Description => 'A test class');

ok ($id, $msg. "- Can create classes as a random new user after ACL grant");
