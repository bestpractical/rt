#!/usr/bin/perl

use strict;
use warnings;

use RT::Test strict => 1, tests => 8, l10n => 1;

use Encode;

my $ru_test = "\x{442}\x{435}\x{441}\x{442}";
my $ru_autoreply = "\x{410}\x{432}\x{442}\x{43e}\x{43e}\x{442}\x{432}\x{435}\x{442}";
my $ru_support = "\x{43f}\x{43e}\x{434}\x{434}\x{435}\x{440}\x{436}\x{43a}\x{430}";

my $q = RT::Test->load_or_create_queue( name => 'Regression' );
ok $q && $q->id, 'loaded or created queue';

RT::Test->set_rights(
    principal => 'Everyone',
    right => ['CreateTicket', 'ShowTicket', 'SeeQueue', 'ReplyToTicket', 'ModifyTicket'],
);

my ($baseurl, $m) = RT::Test->started_ok;
ok $m->login, 'logged in';

# create a ticket with a subject only
{
    ok $m->goto_create_ticket( $q ), "go to create ticket";
    $m->form_number(3);
    $m->field( subject => $ru_test );
    $m->submit;

    $m->content_like( 
        qr{<td\s+class="message-header-value"[^>]*>\s*\Q$ru_test\E\s*</td>}i,
        'header on the page'
    );
}

# create a ticket with a subject and content
{
    ok $m->goto_create_ticket( $q ), "go to create ticket";
    $m->form_number(3);
    $m->field( subject => $ru_test );
    $m->field( content => $ru_support );
    $m->submit;

    my $encoded_ru_test = Encode::encode_utf8( $ru_test );
    my $encoded_ru_support = Encode::encode_utf8( $ru_support );
    $m->content_like( 
        qr{<td\s+class="message-header-value"[^>]*>\s*\Q$encoded_ru_test\E\s*</td>}i,
        'header on the page'
    );
    $m->content_like( 
        qr{\Q$encoded_ru_support\E}i,
        'content on the page'
    );
}
