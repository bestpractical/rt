#!/usr/bin/env perl
use strict;
use warnings;
use RT::Test tests => 18;

my ($baseurl, $m) = RT::Test->started_ok;

for my $name ("severity", "fu()n:k/") {
    my $cf = RT::Test->load_or_create_custom_field(
        Name  => $name,
        Type  => 'Freeform',
        Queue => 'General',
    );
    ok($cf->Id, "created a CustomField");
    is($cf->Name, $name, "correct CF name");
}

my $queue = RT::Test->load_or_create_queue(Name => 'General');
ok($queue->Id, "loaded the General queue");

$m->post("$baseurl/REST/1.0/ticket/new", [
    user    => 'root',
    pass    => 'password',
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
    user    => 'root',
    pass    => 'password',

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
    user    => 'root',
    pass    => 'password',
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

