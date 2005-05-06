#!/usr/bin/perl
use strict;
use warnings;
use Test::More qw/no_plan/;

use_ok("RT");

RT::LoadConfig();
RT::Init();

use RT::Interface::Email;

# normal use case, regexp set to rtname
$RT::rtname = "site";
$RT::EmailSubjectTagRegex = qr/$RT::rtname/ ;
$RT::rtname = undef;
is(RT::Interface::Email::ParseTicketId("[site #123] test"), 123);
is(RT::Interface::Email::ParseTicketId("[othersite #123] test"), undef);

# oops usecase, where the regexp is scragged
$RT::rtname = "site";
$RT::EmailSubjectTagRegex = undef;
is(RT::Interface::Email::ParseTicketId("[site #123] test"), 123);
is(RT::Interface::Email::ParseTicketId("[othersite #123] test"), undef);

# set to a simple regexp. NOTE: we no longer match "site"
$RT::rtname = "site";
$RT::EmailSubjectTagRegex = qr/newsite/;
is(RT::Interface::Email::ParseTicketId("[site #123] test"), undef);
is(RT::Interface::Email::ParseTicketId("[newsite #123] test"), 123);

# set to a more complex regexp
$RT::rtname = "site";
$RT::EmailSubjectTagRegex = qr/newsite||site/;
is(RT::Interface::Email::ParseTicketId("[site #123] test"), 123);
is(RT::Interface::Email::ParseTicketId("[newsite #123] test"), 123);
is(RT::Interface::Email::ParseTicketId("[othersite #123] test"), undef);

