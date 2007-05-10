
use strict;
use warnings;
use Test::More qw/no_plan/;
use RT;
use RT::Test;


{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;

ok (require RT::CurrentUser);


    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}

{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;

ok (my $cu = RT::CurrentUser->new('root'));
ok (my $lh = $cu->LanguageHandle('en-us'));
isnt ($lh, undef, '$lh is defined');
ok ($lh->isa('Locale::Maketext'));
is ($cu->loc('TEST_STRING'), "Concrete Mixer", "Localized TEST_STRING into English");
SKIP: {
    skip "French localization is not enabled", 2
        unless grep $_ && $_ =~ /^(\*|fr)$/, RT->Config->Get('LexiconLanguages');
    ok ($lh = $cu->LanguageHandle('fr'));
    is ($cu->loc('Before'), "Avant", "Localized TEST_STRING into French");
}


    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}

1;
