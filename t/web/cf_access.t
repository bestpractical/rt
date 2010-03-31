#!/usr/bin/perl -w
use strict;

use RT::Test strict => 1, tests => 21, l10n => 1;

$RT::Test::SKIP_REQUEST_WORK_AROUND = 1;

my ($baseurl, $m) = RT::Test->started_ok;

use constant ImageFile => RT->static_path .'/images/bplogo.gif';
use constant ImageFileContent => RT::Test->file_content(ImageFile);

diag "Create a CF" if $ENV{'TEST_VERBOSE'};
my $cf = RT::Model::CustomField->new( current_user => RT->system_user );
my ( $status, $msg ) = $cf->create(
    name        => 'img',
    description => 'img',
    type        => 'Image',
    lookup_type => 'RT::Model::Queue-RT::Model::Ticket',
);
ok( $status, $msg );
my $cfid = $cf->id;

diag "apply the CF to General queue" if $ENV{'TEST_VERBOSE'};
my $queue = RT::Model::Queue->new( current_user => RT->system_user );
( $status, $msg ) = $queue->load( 'General' );
ok( $status, $msg );
( $status, $msg ) = $cf->add_to_object( $queue );
ok( $status, $msg );

my ( $tid );
my $tester = RT::Test->load_or_create_user( name => 'tester', password => '123456' );
RT::Test->set_rights(
    { principal => $tester->principal,
      right => [qw(SeeQueue ShowTicket CreateTicket)],
    },
);
ok $m->login( $tester->name, 123456), 'logged in';

my $cf_moniker = 'edit-ticket-cfs';

diag "check that we have no the CF on the create"
    ." ticket page when user has no SeeCustomField right"
        if $ENV{'TEST_VERBOSE'};
{
    $m->follow_link_ok( url_regex => qr'/ticket/create', text => 'General');

    my $form = $m->form_name("ticket_create");

    ok !$form->find_input( "J:A:F-$cfid-$cf_moniker" ), 'no form field on the page';

    $m->submit_form(
        form_name => "ticket_create",
        fields => { subject => 'test' },
    );
    $m->content_like(qr/Created ticket #\d+/, "a ticket is Created succesfully");

    $m->content_unlike(qr/img:/, 'has no img field on the page');
    $m->follow_link( text => 'Custom Fields');
    $m->content_unlike(qr/Upload multiple images/, 'has no upload image field');
}

RT::Test->set_rights(
    { principal => $tester->principal,
      right => [qw(SeeQueue ShowTicket CreateTicket SeeCustomField)],
    },
);

diag "check that we have no the CF on the create"
    ." ticket page when user has no ModifyCustomField right"
        if $ENV{'TEST_VERBOSE'};
{
    $m->follow_link( url_regex => qr'/ticket/create', text => 'General');
    $m->content_unlike(qr/Upload multiple images/, 'has no upload image field');

    my $form = $m->form_name("ticket_create");
    ok !$form->find_input( "J:A:F-$cfid-$cf_moniker" ), 'no form field on the page';

    $m->submit_form(
        form_name => "ticket_create",
        fields => { subject => 'test' },
    );
    $tid = $1 if $m->content =~ /Created ticket #(\d+)/;
    ok $tid, "a ticket is Created succesfully";

    $m->follow_link( text => 'Custom Fields' );
    $m->content_unlike(qr/Upload multiple images/, 'has no upload image field');
    $form = $m->form_name('ticket_modify');
    ok !$form->find_input( "J:A:F-$cfid-$cf_moniker" ), 'no form field on the page';
}

RT::Test->set_rights(
    { principal => $tester->principal,
      right => [qw(SeeQueue ShowTicket CreateTicket SeeCustomField ModifyCustomField)],
    },
);

diag "create a ticket with an image" if $ENV{'TEST_VERBOSE'};
{
    $m->follow_link( url_regex => qr'/ticket/create', text => 'General');
    TODO: {
        local $TODO = "Multi-upload CFs not available yet";
        $m->content_like(qr/Upload multiple images/, 'has a upload image field');
    }

    $cfid =~ /(\d+)$/ or die "Hey this is impossible dude";
    $m->submit_form(
        form_name => "ticket_create",
        fields => {
            "J:A:F-$1-$cf_moniker" => ImageFile,
            subject => 'testing img cf creation',
        },
    );

    $m->content_like(qr/Created ticket #\d+/, "a ticket is Created succesfully");

    $tid = $1 if $m->content =~ /Created ticket #(\d+)/;

    TODO: {
        local $TODO = "Multi-upload CFs not available yet";
        $m->title_like(qr/testing img cf creation/, "its title is the subject");
    }

    $m->follow_link( text => 'bplogo.gif' );
    TODO: {
        local $TODO = "Multi-upload CFs not available yet";
        $m->content_is(ImageFileContent, "it links to the uploaded image");
    }
}

$m->get( $m->rt_base_url );
$m->follow_link( text => 'Tickets' );
$m->follow_link( text => 'New Query' );

$m->title_is(q/Query Builder/, 'Query building');
$m->submit_form(
    form_name => "build_query",
    fields => {
        id_op => '=',
        value_of_id => $tid,
        value_of_queue => 'General',
    },
    button => 'add_clause',
);

$m->form_name('build_query');

my $col = ($m->current_form->find_input('select_display_columns'))[-1];
$col->value( ($col->possible_values)[-1] );

$m->click('add_col');

$m->form_name('build_query');
$m->click('do_search');

$m->follow_link( text_regex => qr/bplogo\.gif/ );
TODO: {
    local $TODO = "Multi-upload CFs not available yet";
    $m->content_is(ImageFileContent, "it links to the uploaded image");
}

__END__
[FC] Bulk Update does not have custom fields.
