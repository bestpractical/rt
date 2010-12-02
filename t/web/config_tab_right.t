#!/usr/bin/perl -w
use strict;
use warnings;

use RT::Test nodata => 1, tests => 10;

my ($uname, $upass, $user) = ('tester', 'tester');
{
    $user = RT::User->new(RT->SystemUser);
    my ($status, $msg) = $user->Create(
        Name => $uname,
        Password => $upass,
        Disabled => 0,
        Privileged => 1,
    );
    ok($status, 'created a user');
}

my ($baseurl, $m) = RT::Test->started_ok;
ok $m->login($uname, $upass), "logged in";

{
    $m->content_lacks('Configuration', 'no configuration tab');
    $m->get('/Admin/');
    is $m->status, 403, 'no access to /Admin/';
}

RT::Test->set_rights(
    { Principal => $user->PrincipalObj,
      Right => [qw(ShowConfigTab)],
    },
);

{
    $m->get('/');
    $m->content_contains('Configuration', 'configuration tab is there');

    $m->follow_link_ok({text => 'Configuration'});
    is $m->status, 200, 'user has access to /Admin/';
}

