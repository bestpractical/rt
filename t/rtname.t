#!/usr/bin/perl
use strict;
use warnings;
use RT::Test; use Test::More tests => 9;


use RT::Interface::Email;

# normal use case, regexp set to rtname
RT->Config->set( rtname => "site" );
RT->Config->set( EmailSubjectTagRegex => qr/site/ );
RT->Config->set( rtname => undef );
is(RT::Interface::Email::ParseTicketId("[site #123] test"), 123);
is(RT::Interface::Email::ParseTicketId("[othersite #123] test"), undef);

# oops usecase, where the regexp is scragged
RT->Config->set( rtname => "site" );
RT->Config->set( EmailSubjectTagRegex => undef );
is(RT::Interface::Email::ParseTicketId("[site #123] test"), 123);
is(RT::Interface::Email::ParseTicketId("[othersite #123] test"), undef);

# set to a simple regexp. NOTE: we no longer match "site"
RT->Config->set( rtname => "site");
RT->Config->set( EmailSubjectTagRegex => qr/newsite/);
is(RT::Interface::Email::ParseTicketId("[site #123] test"), undef);
is(RT::Interface::Email::ParseTicketId("[newsite #123] test"), 123);

# set to a more complex regexp
RT->Config->set( rtname => "site" );
RT->Config->set( EmailSubjectTagRegex => qr/newsite|site/ );
is(RT::Interface::Email::ParseTicketId("[site #123] test"), 123);
is(RT::Interface::Email::ParseTicketId("[newsite #123] test"), 123);
is(RT::Interface::Email::ParseTicketId("[othersite #123] test"), undef);

