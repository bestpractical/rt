
use strict;
use warnings;
use RT::Test; use Test::More; 
plan tests => 8;
use RT;



{

ok (require RT::CurrentUser);


}

{

ok (my $cu = RT::CurrentUser->new('root'));
isnt ($lh, undef, '$lh is defined');
ok ($lh->isa('Locale::Maketext'));
is ($cu->_('TEST_STRING'), "Concrete Mixer", "Localized TEST_STRING into English");
SKIP: {
    skip "French localization is not enabled", 2
        unless grep $_ && $_ =~ /^(\*|fr)$/, RT->Config->Get('LexiconLanguages');
    ok ($lh = $cu->LanguageHandle('fr'));
    is ($cu->_('Before'), "Avant", "Localized TEST_STRING into French");
}


}

1;
