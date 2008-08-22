#!/usr/bin/env perl
use strict;
use warnings;
use Test::More tests => 16;
use RT::Test;

my ($baseurl, $m) = RT::Test->started_ok;

for my $name ("severity", "fu()n:k/") {
    my $cf = RT::Test->load_or_create_custom_field(
        name  => $name,
        type  => 'Freeform',
        queue => 'General',
    );
    ok($cf->id, "created a CustomField");
    is($cf->name, $name, "correct CF name");
}

my $queue = RT::Test->load_or_create_queue(name => 'General');
ok($queue->id, "loaded the General queue");

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
], content_type => 'form-data');

my ($id) = $m->content =~ /Ticket (\d+) created/;
ok($id, "got ticket #$id");

my $ticket = RT::Model::Ticket->new(current_user => RT->system_user);
$ticket->load($id);
is($ticket->id, $id, "loaded the REST-created ticket");
is($ticket->subject, "REST interface", "subject successfully set");
is($ticket->first_custom_field_value("fu()n:k/"), "maximum", "CF successfully set");

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

