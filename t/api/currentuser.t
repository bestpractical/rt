
use Test::More qw/no_plan/;
use RT;
RT::LoadConfig();
RT::Init();

{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;
#line 63 lib/RT/CurrentUser.pm

ok (require RT::CurrentUser);


    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}

{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;
#line 202 lib/RT/CurrentUser.pm

ok (my $cu = RT::CurrentUser->new('root'));
ok (my $lh = $cu->LanguageHandle('en-us'));
ok ($lh != undef);
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
