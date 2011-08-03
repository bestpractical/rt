use strict;
use warnings;

use RT::Test nodata => 1, tests => 12;

use RT::Interface::Email;

# normal use case, regexp set to rtname
RT->Config->Set( rtname => "site" );
RT->Config->Set( EmailSubjectTagRegex => qr/site/ );
RT->Config->Set( rtname => undef );
is(RT::Interface::Email::ParseTicketId("[site #123] test"), 123);
is(RT::Interface::Email::ParseTicketId("[othersite #123] test"), undef);

# oops usecase, where the regexp is scragged
RT->Config->Set( rtname => "site" );
RT->Config->Set( EmailSubjectTagRegex => undef );
is(RT::Interface::Email::ParseTicketId("[site #123] test"), 123);
is(RT::Interface::Email::ParseTicketId("[othersite #123] test"), undef);

# set to a simple regexp. NOTE: we no longer match "site"
RT->Config->Set( rtname => "site");
RT->Config->Set( EmailSubjectTagRegex => qr/newsite/);
is(RT::Interface::Email::ParseTicketId("[site #123] test"), undef);
is(RT::Interface::Email::ParseTicketId("[newsite #123] test"), 123);

# set to a more complex regexp
RT->Config->Set( rtname => "site" );
RT->Config->Set( EmailSubjectTagRegex => qr/newsite|site/ );
is(RT::Interface::Email::ParseTicketId("[site #123] test"), 123);
is(RT::Interface::Email::ParseTicketId("[newsite #123] test"), 123);
is(RT::Interface::Email::ParseTicketId("[othersite #123] test"), undef);

# Parens work fine
RT->Config->Set( EmailSubjectTagRegex => qr/(new|)(site)/ );
is(RT::Interface::Email::ParseTicketId("[site #123] test"), 123);
is(RT::Interface::Email::ParseTicketId("[newsite #123] test"), 123);
is(RT::Interface::Email::ParseTicketId("[othersite #123] test"), undef);
