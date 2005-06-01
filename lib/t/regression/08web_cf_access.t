#!/usr/bin/perl -w
use strict;

use Test::More tests => 15;
use RT;
RT::LoadConfig;
RT::Init;
use Test::WWW::Mechanize;

$RT::WebURL ||= 0; # avoid stupid warning
my $BaseURL = $RT::WebURL;
use constant ImageFile => $RT::MasonComponentRoot .'/NoAuth/images/bplogo.gif';
use constant ImageFileContent => do {
    local $/;
    open my $fh, '<', ImageFile or die $!;
    binmode($fh);
    scalar <$fh>;
};

my $m = Test::WWW::Mechanize->new;
isa_ok($m, 'Test::WWW::Mechanize');

$m->get( $BaseURL."?user=root;pass=password" );
$m->content_like(qr/Logout/, 'we did log in');
$m->follow_link( text => 'Configuration' );
$m->title_is(q/RT Administration/, 'admin screen');
$m->follow_link( text => 'Custom Fields' );
$m->title_is(q/Select a Custom Field/, 'admin-cf screen');
$m->follow_link( text => 'New custom field' );
$m->submit_form(
    form_name => "ModifyCustomField",
    fields => {
        TypeComposite => 'Image-0',
        LookupType => 'RT::Queue-RT::Ticket',
        Name => 'img',
        Description => 'img',
    },
);
$m->title_is(q/Created CustomField img/, 'admin-cf created');
$m->follow_link( text => 'Queues' );
$m->title_is(q/Admin queues/, 'admin-queues screen');
$m->follow_link( text => 'General' );
$m->title_is(q/Editing Configuration for queue General/, 'admin-queue: general');
$m->follow_link( text => 'Ticket Custom Fields' );

$m->title_is(q/Edit Custom Fields for General/, 'admin-queue: general tcf');
$m->form_name('EditCustomFields');

# Sort by numeric IDs in names
my @names = map  { $_->[1] }
            sort { $a->[0] <=> $b->[0] }
            map  { /Object-1-CF-(\d+)/ ? [ $1 => $_ ] : () }
            map  $_->name, $m->current_form->inputs;
my $tcf = pop(@names);
$m->field( $tcf => 1 );         # Associate the new CF with this queue
$m->field( $_ => undef ) for @names;    # ...and not any other. ;-)
$m->submit;

$m->content_like( qr/Object created/, 'TCF added to the queue' );

$m->submit_form(
    form_name => "CreateTicketInQueue",
    fields => { Queue => 'General' },
);

$m->content_like(qr/Upload multiple images/, 'has a upload image field');

$tcf =~ /(\d+)$/ or die "Hey this is impossible dude";
my $upload_field = "Object-RT::Ticket--CustomField-$1-Upload";

$m->submit_form(
    form_name => "TicketCreate",
    fields => {
        $upload_field => ImageFile,
        Subject => 'testing img cf creation',
    },
);

$m->content_like(qr/Ticket \d+ created/, "a ticket is created succesfully");

my $id = $1 if $m->content =~ /Ticket (\d+) created/;

$m->title_like(qr/testing img cf creation/, "its title is the Subject");

$m->follow_link( text => 'bplogo.gif' );
$m->content_is(ImageFileContent, "it links to the uploaded image");

$m->get( $BaseURL );

$m->follow_link( text => 'Tickets' );
$m->follow_link( text => 'New Query' );

$m->title_is(q/Query Builder/, 'Query building');
$m->submit_form(
    form_name => "BuildQuery",
    fields => {
        idOp => '=',
        ValueOfid => $id,
        ValueOfQueue => 'General',
    },
    button => 'AddClause',
);

$m->form_name('BuildQuery');

my $col = ($m->current_form->find_input('SelectDisplayColumns'))[-1];
$col->value( ($col->possible_values)[-1] );

$m->click('AddCol');

$m->form_name('BuildQuery');
$m->click('DoSearch');

$m->follow_link( text_regex => qr/bplogo\.gif/ );
$m->content_is(ImageFileContent, "it links to the uploaded image");

__END__
[FC] Bulk Update does not have custom fields.
