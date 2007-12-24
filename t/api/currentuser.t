
use strict;
use warnings;
use RT::Test;
use Test::More;
plan tests => 4;
use RT;

ok( require RT::CurrentUser );

ok( my $cu = RT::CurrentUser->new('root') );
is( _('TEST_STRING'), "Concrete Mixer",
    "Localized TEST_STRING into English" );
SKIP: {
    skip "French localization is not enabled", 2
        unless grep $_ && $_ =~ /^(\*|fr)$/,
        RT->Config->Get('LexiconLanguages');

    Jifty::I18N->get_handle('FR-fr');
    is( _('Before'), "Avant", "Localized TEST_STRING into French" );
}

1;
