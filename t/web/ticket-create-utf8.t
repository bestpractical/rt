#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 8;
use RT::Test;

use Encode;

my $str_ru_test = "\x{442}\x{435}\x{441}\x{442}";
my $oct_ru_test = Encode::encode_utf8( $str_ru_test );
my $str_ru_autoreply = "\x{410}\x{432}\x{442}\x{43e}\x{43e}\x{442}\x{432}\x{435}\x{442}";
my $oct_ru_autoreply = Encode::encode_utf8( $str_ru_autoreply );
my $str_ru_support = "\x{43f}\x{43e}\x{434}\x{434}\x{435}\x{440}\x{436}\x{43a}\x{430}";
my $oct_ru_support = Encode::encode_utf8( $str_ru_support );

my $q = RT::Test->load_or_create_queue( Name => 'Regression' );
ok $q && $q->id, 'loaded or created queue';

RT::Test->set_rights(
    Principal => 'Everyone',
    Right => ['CreateTicket', 'ShowTicket', 'SeeQueue', 'ReplyToTicket', 'ModifyTicket'],
);

my ($baseurl, $m) = RT::Test->started_ok;
ok $m->login, 'logged in';

# create a ticket with a subject only
{
    ok $m->goto_create_ticket( $q ), "go to create ticket";
    $m->form_number(3);
    $m->field( Subject => $oct_ru_test );
    $m->submit;

    $m->content_like( 
        qr{<td\s+class="message-header-value"[^>]*>\s*\Q$oct_ru_test\E\s*</td>}i,
        'header on the page'
    );
}

# create a ticket with a subject and content
{
    ok $m->goto_create_ticket( $q ), "go to create ticket";
    $m->form_number(3);
    $m->field( Subject => $oct_ru_test );
    $m->field( Content => $oct_ru_support );
    $m->submit;

    $m->content_like( 
        qr{<td\s+class="message-header-value"[^>]*>\s*\Q$oct_ru_test\E\s*</td>}i,
        'header on the page'
    );
    $m->content_like( 
        qr{\Q$oct_ru_support\E}i,
        'content on the page'
    );
}
