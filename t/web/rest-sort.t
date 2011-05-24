#!/usr/bin/env perl
use strict;
use warnings;
use RT::Test tests => 22;

my ($baseurl, $m) = RT::Test->started_ok;

RT::Test->create_tickets(
    { },
    { Subject => 'uno'  },
    { Subject => 'dos'  },
    { Subject => 'tres' },
);

ok($m->login, 'logged in');

sorted_tickets_ok('Subject',  ['2: dos', '3: tres', '1: uno']);
sorted_tickets_ok('+Subject', ['2: dos', '3: tres', '1: uno']);
sorted_tickets_ok('-Subject', ['1: uno', '3: tres', '2: dos']);

sorted_tickets_ok('id',  ['1: uno',  '2: dos', '3: tres']);
sorted_tickets_ok('+id', ['1: uno',  '2: dos', '3: tres']);
sorted_tickets_ok('-id', ['3: tres', '2: dos', '1: uno']);

undef $m;

sub sorted_tickets_ok {
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    my $order    = shift;
    my $expected = shift;

    my $query = 'id > 0';

    my $uri = URI->new("$baseurl/REST/1.0/search/ticket");
    $uri->query_form(
        query   => $query,
        orderby => $order,
    );
    $m->get_ok($uri);

    my @lines = split /\n/, $m->content;
    shift @lines; # header
    shift @lines; # empty line

    is_deeply(\@lines, $expected, "sorted results by '$order'");
}

__END__

$m->post("$baseurl/REST/1.0/ticket/new", [
    format  => 'l',
]);

my $text = $m->content;
my @lines = $text =~ m{.*}g;
shift @lines; # header

# CFs aren't in the default ticket form
push @lines, "CF-fu()n:k/: maximum"; # old style
push @lines, "CF.{severity}: explosive"; # new style

$text = join "\n", @lines;

ok($text =~ s/Subject:\s*$/Subject: REST interface/m, "successfully replaced subject");

$m->post("$baseurl/REST/1.0/ticket/edit", [
    content => $text,
], Content_Type => 'form-data');

my ($id) = $m->content =~ /Ticket (\d+) created/;
ok($id, "got ticket #$id");

my $ticket = RT::Ticket->new(RT->SystemUser);
$ticket->Load($id);
is($ticket->Id, $id, "loaded the REST-created ticket");
is($ticket->Subject, "REST interface", "subject successfully set");
is($ticket->FirstCustomFieldValue("fu()n:k/"), "maximum", "CF successfully set");

$m->post("$baseurl/REST/1.0/search/ticket", [
    query   => "id=$id",
    fields  => "Subject,CF-fu()n:k/,CF.{severity},Status",
]);

# the fields are interpreted server-side a hash (why?), so we can't depend
# on order
for ("id: ticket/1",
     "Subject: REST interface",
     "CF.{fu()n:k/}: maximum",
     "CF.{severity}: explosive",
     "Status: new") {
        $m->content_contains($_);
}

