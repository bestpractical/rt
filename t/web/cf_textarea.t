use strict;
use warnings;

use RT::Test tests => 'no_declare';

my $content = join ' ', ('The quick brown fox jumps over the lazy dog.') x 5;
$content = join "\n\n", $content, $content, $content;

my ($base, $m) = RT::Test->started_ok;

$m->login;

my $ticket = RT::Test->create_ticket(
    Queue   => 1,
    Subject => 'a test ticket',
);
ok $ticket && $ticket->id, "Created ticket";

my $EditUrl = "/Ticket/Modify.html?id=" . $ticket->id;

my $cfs = {
    area => {
        type => 'Text',
        name => 'TheTextarea',
    },
    text => {
        type => 'FreeformSingle',
        name => 'TheControlField',
    },
    zero => {
        type => 'FreeformSingle',
        name => 'Zero',
    },
};

while ( my( $label, $data ) = each %$cfs ) {
    my $cf = $data->{obj} = RT::Test->load_or_create_custom_field(
        Name        => $data->{name},
        Type        => $data->{type},
        Queue       => 0,
        LookupType  => 'RT::Queue-RT::Ticket',
    );
    ok $cf && $cf->id, "Created $data->{type} CF";

    # get cf input field name
    $data->{input} = RT::Interface::Web::GetCustomFieldInputName(
        Object      => $ticket,
        CustomField => $cf,
    );
}

# open ticket "Basics" page
$m->get_ok($EditUrl, "Fetched $EditUrl");
$m->content_contains($_->{name} . ':') for ( values %$cfs );

$m->submit_form_ok({
    with_fields => {
        $cfs->{area}{input}            => $content,
        $cfs->{area}{input} . '-Magic' => "1",
        $cfs->{text}{input}            => 'value a',
        $cfs->{text}{input} . '-Magic' => "1",
        $cfs->{zero}{input}            => '0',
        $cfs->{zero}{input} . '-Magic' => "1",
    },
}, 'submitted form to initially set CFs');
$m->content_contains('<li>TheControlField value a added</li>');
$m->content_contains("<li>TheTextarea $content added</li>", 'content found');
$m->content_contains("<li>Zero 0 added</li>", 'zero field found');

# http://issues.bestpractical.com/Ticket/Display.html?id=30378
# #30378: RT 4.2.6 - Very long text fields get updated even when they haven't changed
$m->submit_form_ok({
    with_fields => {
        $cfs->{text}{input}            => 'value b',
        $cfs->{text}{input} . '-Magic' => "1",
    },
}, 'submitted form to initially set CFs');
$m->content_contains('<li>TheControlField value a changed to value b</li>');
$m->content_lacks("<li>TheTextarea $content changed to $content</li>", 'textarea wasnt updated');

# http://issues.bestpractical.com/Ticket/Display.html?id=32440
# #32440: Spurious "CF changed from 0 to 0"
$m->content_lacks("<li>Zero 0 changed to 0</li>", "Zero wasn't updated");

done_testing;
