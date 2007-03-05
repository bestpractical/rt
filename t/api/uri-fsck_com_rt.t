
use Test::More qw/no_plan/;
use RT;
RT::LoadConfig();
RT::Init();

{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;
#line 64 lib/RT/URI/fsck_com_rt.pm

use_ok("RT::URI::fsck_com_rt");
my $uri = RT::URI::fsck_com_rt->new($RT::SystemUser);

ok(ref($uri));

ok (UNIVERSAL::isa($uri,RT::URI::fsck_com_rt), "It's an RT::URI::fsck_com_rt");

ok ($uri->isa('RT::URI::base'), "It's an RT::URI::base");
ok ($uri->isa('RT::Base'), "It's an RT::Base");

is ($uri->LocalURIPrefix , 'fsck.com-rt://'.RT->Config->Get('Organization'));


    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}

{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;
#line 115 lib/RT/URI/fsck_com_rt.pm

my $ticket = RT::Ticket->new($RT::SystemUser);
$ticket->Load(1);
my $uri = RT::URI::fsck_com_rt->new($ticket->CurrentUser);
is($uri->LocalURIPrefix. "/ticket/1" , $uri->URIForObject($ticket));


    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}

1;
