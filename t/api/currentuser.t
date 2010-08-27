
use strict;
use warnings;
use RT;
use RT::Test noinitialdata => 1, tests => 8;


{

ok (require RT::CurrentUser);


}

{

ok (my $cu = RT::CurrentUser->new('root'));
ok (my $lh = $cu->LanguageHandle('en-us'));
isnt ($lh, undef, '$lh is defined');
ok ($lh->isa('Locale::Maketext'));
is ($cu->loc('TEST_STRING'), "Concrete Mixer", "Localized TEST_STRING into English");
SKIP: {
    skip "French localization is not enabled", 2
        unless grep $_ && $_ =~ /^(\*|fr)$/, RT->Config->Get('LexiconLanguages');
    ok ($lh = $cu->LanguageHandle('fr'));
    is ($cu->loc('before'), "avant", "Localized TEST_STRING into French");
}


}

