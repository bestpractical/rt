#!/usr/bin/env perl
use strict;
use warnings;
use RT::Interface::REST;

use RT::Test tests => 22;

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

# Create ticket 2 for testing ticket links
for (2 .. 3) {
    $m->post("$baseurl/REST/1.0/ticket/edit", [
        user    => 'root',
        pass    => 'password',
        content => $text,
    ], Content_Type => 'form-data');

    $m->post(
        "$baseurl/REST/1.0/ticket/1/links",
        [
            user    => 'root',
            pass    => 'password',
        ],
        Content_Type => 'form-data',
    );

    my $link_data = form_parse($m->content);

    push @{$link_data->[0]->[1]}, 'DependsOn';
    vpush($link_data->[0]->[2], 'DependsOn', $_);

    $m->post(
        "$baseurl/REST/1.0/ticket/1/links",
        [
            user    => 'root',
            pass    => 'password',
            content => form_compose($link_data),
        ],
        Content_Type => 'form-data',
    );

}

# See what links get reported for ticket 1.
$m->post(
    "$baseurl/REST/1.0/ticket/1/links/show",
    [
        user    => 'root',
        pass    => 'password',
    ],
    Content_Type => 'form-data',
);

# Verify that the link was added correctly.
my $content = form_parse($m->content);
my $depends_on = vsplit($content->[0]->[2]->{DependsOn});
@$depends_on = sort @$depends_on;
like(
    $depends_on->[0], qr{/ticket/2$},
    "Check ticket link.",
) or diag("'content' obtained:\n", $m->content);

like(
    $depends_on->[1], qr{/ticket/3$},
    "Check ticket link.",
) or diag("'content' obtained:\n", $m->content);

$m->post(
    "$baseurl/REST/1.0/ticket/2/links/show",
    [
        user    => 'root',
        pass    => 'password',
    ],
    Content_Type => 'form-data',
);
my ($link) = $m->content =~ m|DependedOnBy:.*ticket/(\d+)|;
is($link, 1, "Check ticket link.") or diag("'content' obtained:\n", $m->content);

$m->post(
    "$baseurl/REST/1.0/ticket/3/links/show",
    [
        user    => 'root',
        pass    => 'password',
    ],
    Content_Type => 'form-data',
);
($link) = $m->content =~ m|DependedOnBy:.*ticket/(\d+)|;
is($link, 1, "Check ticket link.") or diag("'content' obtained:\n", $m->content);
