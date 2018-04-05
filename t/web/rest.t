use strict;
use warnings;
use RT::Interface::REST;

use RT::Test tests => undef;

my ($baseurl, $m) = RT::Test->started_ok;

for my $name ("severity", "fu()n:k/") {
    my $cf = RT::Test->load_or_create_custom_field(
        Name  => $name,
        Type  => 'FreeformMultiple',
        Queue => 'General',
    );
    ok($cf->Id, "created a CustomField");
    is($cf->Name, $name, "correct CF name");
}
{
    my $cf = RT::Test->load_or_create_custom_field(
        Name  => 'single',
        Type  => 'FreeformSingle',
        Queue => 'General',
    );
    ok($cf->Id, "created a CustomField");
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
for (2 .. 4) {
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
}

diag "Add one link";

my $link_data = <<'END_LINKS';
id: ticket/1/links
DependsOn: 2
END_LINKS

$m->post(
    "$baseurl/REST/1.0/ticket/1/links",
    [
        user    => 'root',
        pass    => 'password',
        content => $link_data,
    ],
    Content_Type => 'form-data',
);

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
    "Link to ticket 2 added.",
) or diag("'content' obtained:\n", $m->content);

diag "Add two links";

$link_data = <<'END_LINKS';
id: ticket/1/links
DependsOn: 3,4
END_LINKS

$m->post(
    "$baseurl/REST/1.0/ticket/1/links",
    [
        user    => 'root',
        pass    => 'password',
        content => $link_data,
    ],
    Content_Type => 'form-data',
);

# See what links get reported for ticket 1.
$m->post(
    "$baseurl/REST/1.0/ticket/1/links/show",
    [
        user    => 'root',
        pass    => 'password',
    ],
    Content_Type => 'form-data',
);

$content = form_parse($m->content);
$depends_on = vsplit($content->[0]->[2]->{DependsOn});
@$depends_on = sort @$depends_on;

like(
    $depends_on->[0], qr{/ticket/3$},
    "Link to ticket 3 found",
) or diag("'content' obtained:\n", $m->content);

like(
    $depends_on->[1], qr{/ticket/4$},
    "Link to ticket 4 found",
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
is($link, undef, "Link removed from ticket 2") or diag("'content' obtained:\n", $m->content);

$m->post(
    "$baseurl/REST/1.0/ticket/3/links/show",
    [
        user    => 'root',
        pass    => 'password',
    ],
    Content_Type => 'form-data',
);
($link) = $m->content =~ m|DependedOnBy:.*ticket/(\d+)|;
is($link, 1, "Ticket 3 has link to 1.") or diag("'content' obtained:\n", $m->content);

$m->post(
    "$baseurl/REST/1.0/ticket/4/links/show",
    [
        user    => 'root',
        pass    => 'password',
    ],
    Content_Type => 'form-data',
);
($link) = $m->content =~ m|DependedOnBy:.*ticket/(\d+)|;
is($link, 1, "Ticket 4 has link to 1.") or diag("'content' obtained:\n", $m->content);

diag "Test custom fields";
{
    $m->post("$baseurl/REST/1.0/ticket/new", [
        user    => 'root',
        pass    => 'password',
        format  => 'l',
    ]);

    my $text = $m->content;
    my @lines = $text =~ m{.*}g;
    shift @lines; # header
    push @lines, "CF.{severity}: explosive";
    push @lines, "CF.{severity}: very";
    $text = join "\n", @lines;

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
    is_deeply(
        [sort map $_->Content, @{ $ticket->CustomFieldValues("severity")->ItemsArrayRef }],
        ["explosive", "very"],
        "CF successfully set"
    );

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
    $text =~ s/.*?\n\n//;
    $text =~ s/\n\n/\n/;
    $text =~ s{CF\.\{severity\}:.*\n}{}img;
    $text .= "CF.{severity}: explosive, a bit\n";
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

    $ticket->Load($id);
    is_deeply(
        [sort map $_->Content, @{ $ticket->CustomFieldValues("severity")->ItemsArrayRef }],
        ['a bit', 'explosive'],
        "CF successfully set"
    );

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
    $text =~ s{CF\.\{severity\}:.*\n}{}img;
    $text .= "CF.{severity}:\n";
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

    $ticket->Load($id);
    is_deeply(
        [sort map $_->Content, @{ $ticket->CustomFieldValues("severity")->ItemsArrayRef }],
        [],
        "CF successfully set"
    );

    my @txns = map [$_->OldValue, $_->NewValue], grep $_->Type eq 'CustomField',
        @{ $ticket->Transactions->ItemsArrayRef };
    is_deeply(\@txns, [['very', undef], [undef, 'a bit'], ['explosive', undef], ['a bit', undef]]);
}

{
    $m->post("$baseurl/REST/1.0/ticket/new", [
        user    => 'root',
        pass    => 'password',
        format  => 'l',
    ]);

    my $text = $m->content;
    my @lines = $text =~ m{.*}g;
    shift @lines; # header
    push @lines, "CF.{single}: this";
    $text = join "\n", @lines;

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
    is_deeply(
        [sort map $_->Content, @{ $ticket->CustomFieldValues("single")->ItemsArrayRef }],
        ["this"],
        "CF successfully set"
    );

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
    $text =~ s{CF\.\{single\}:.*\n}{}img;
    $text .= "CF.{single}: that\n";
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

    $ticket->Load($id);
    is_deeply(
        [sort map $_->Content, @{ $ticket->CustomFieldValues("single")->ItemsArrayRef }],
        ['that'],
        "CF successfully set"
    );

    my @txns = map [$_->OldValue, $_->NewValue], grep $_->Type eq 'CustomField',
        @{ $ticket->Transactions->ItemsArrayRef };
    is_deeply(\@txns, [['this', 'that']]);
}

done_testing();
