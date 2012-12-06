use strict;
use warnings;
use RT::Interface::REST;

use RT::Test tests => 25;

my ( $baseurl, $m ) = RT::Test->started_ok;
for my $queue_name (qw/foo bar/) {

    my $queue = RT::Test->load_or_create_queue( Name => $queue_name );
    ok( $queue, "created queue $queue_name" );
    my $cf = RT::Test->load_or_create_custom_field(
        Name  => 'test',
        Type  => 'Freeform',
        Queue => $queue_name,
    );
    ok( $cf->id, "created cf test for queue $queue_name " . $cf->id );

    $m->post(
        "$baseurl/REST/1.0/ticket/new",
        [
            user   => 'root',
            pass   => 'password',
            format => 'l',
        ]
    );

    my $text = $m->content;
    my @lines = $text =~ m{.*}g;
    shift @lines;    # header

    # cfs aren't in the default ticket form
    push @lines, "CF.{test}: baz";

    $text = join "\n", @lines;

    ok( $text =~ s/Subject:\s*$/Subject: test cf/m,
        "successfully replaced subject" );
    ok( $text =~ s/Queue: General\s*$/Queue: $queue_name/m,
        "successfully replaced Queue" );

    $m->post(
        "$baseurl/REST/1.0/ticket/edit",
        [
            user => 'root',
            pass => 'password',
            content => $text,
        ],
        Content_Type => 'form-data'
    );

    my ($id) = $m->content =~ /Ticket (\d+) created/;
    ok( $id, "got ticket #$id" );

    my $ticket = RT::Ticket->new( RT->SystemUser );
    $ticket->Load($id);
    is( $ticket->id,      $id,       "loaded the REST-created ticket" );
    is( $ticket->Subject, "test cf", "subject successfully set" );
    is( $ticket->Queue, $queue->id, "queue successfully set" );
    is( $ticket->FirstCustomFieldValue("test"), "baz", "cf successfully set" );

    $m->post(
        "$baseurl/REST/1.0/ticket/show",
        [
            user   => 'root',
            pass   => 'password',
            format => 'l',
            id     => "ticket/$id",
        ]
    );
    $text = $m->content;
    like( $text, qr/^CF\.\{test\}: baz\s*$/m, 'cf value in rest show' );

    $text =~ s{.*}{}; # remove header
    $text =~ s!CF\.\{test\}: baz!CF.{test}: newbaz!;
    $m->post(
        "$baseurl/REST/1.0/ticket/edit",
        [
            user => 'root',
            pass => 'password',
            content => $text,
        ],
        Content_Type => 'form-data'
    );
    $m->content =~ /Ticket ($id) updated/;
    is( $ticket->FirstCustomFieldValue("test"), "newbaz", "cf successfully updated" );
}

