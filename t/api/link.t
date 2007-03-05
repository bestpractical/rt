
use Test::More qw/no_plan/;
use RT;
RT::LoadConfig();
RT::Init();

{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;


use RT::Link;
my $link = RT::Link->new($RT::SystemUser);


ok (ref $link);
ok (UNIVERSAL::isa($link, 'RT::Link'));
ok (UNIVERSAL::isa($link, 'RT::Base'));
ok (UNIVERSAL::isa($link, 'RT::Record'));
ok (UNIVERSAL::isa($link, 'DBIx::SearchBuilder::Record'));


    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}

1;
