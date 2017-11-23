use strict;
use warnings;

use RT::Test tests => 32;

my ($baseurl, $m) = RT::Test->started_ok;

use constant ImageFile => $RT::StaticPath .'/images/bpslogo.png';
use constant ImageFileContent => RT::Test->file_content(ImageFile);

ok $m->login, 'logged in';

diag "Create a CF";
{
    $m->follow_link( id => 'admin-custom-fields-create');

    # Test form validation
    $m->submit_form(
        form_name => "ModifyCustomField",
        fields => {
            TypeComposite => 'Image-0',
            LookupType => 'RT::Queue-RT::Ticket',
            Name => '',
            Description => 'img',
        },
    );
    $m->text_contains('Invalid value for Name');

    $m->submit_form(
        form_name => "ModifyCustomField",
        fields => {
            TypeComposite => 'Image-0',
            LookupType => 'RT::Queue-RT::Ticket',
            Name => '0',
            Description => 'img',
        },
    );
    $m->text_contains('Invalid value for Name');

    $m->submit_form(
        form_name => "ModifyCustomField",
        fields => {
            TypeComposite => 'Image-0',
            LookupType => 'RT::Queue-RT::Ticket',
            Name => '1',
            Description => 'img',
        },
    );
    $m->text_contains('Invalid value for Name');

    # The real submission
    $m->submit_form(
        form_name => "ModifyCustomField",
        fields => {
            TypeComposite => 'Image-0',
            LookupType => 'RT::Queue-RT::Ticket',
            Name => 'img',
            Description => 'img',
            EntryHint => 'Upload multiple images',
        },
    );
    $m->text_contains('Object created');

    # Validation on update
    $m->form_name("ModifyCustomField");
    $m->set_fields(
        TypeComposite => 'Image-0',
        LookupType => 'RT::Queue-RT::Ticket',
        Name => '',
        Description => 'img',
    );
    $m->click('Update');
    $m->text_contains('Illegal value for Name');
    $m->form_name("ModifyCustomField");
    $m->set_fields(
        TypeComposite => 'Image-0',
        LookupType => 'RT::Queue-RT::Ticket',
        Name => '0',
        Description => 'img',
    );
    $m->click('Update');
    $m->text_contains('Illegal value for Name');
    $m->form_name("ModifyCustomField");
    $m->set_fields(
        TypeComposite => 'Image-0',
        LookupType => 'RT::Queue-RT::Ticket',
        Name => '1',
        Description => 'img',
    );
    $m->click('Update');
    $m->text_contains('Illegal value for Name');
}

diag "apply the CF to General queue";
my ( $cf, $cfid, $tid );
{
    $m->title_is(q/Editing CustomField img/, 'admin-cf created');
    $m->follow_link( id => 'admin-queues');
    $m->follow_link( text => 'General' );
    $m->title_is(q/Configuration for queue General/, 'admin-queue: general');
    $m->follow_link( id => 'page-custom-fields-tickets');
    $m->title_is(q/Custom Fields for queue General/, 'admin-queue: general cfid');
    $m->form_name('EditCustomFields');

    # Sort by numeric IDs in names
    my @names = sort grep defined,
        $m->current_form->find_input('AddCustomField')->possible_values;
    $cf = pop(@names);
    $cf =~ /(\d+)$/ or die "Hey this is impossible dude";
    $cfid = $1;
    $m->tick( AddCustomField => $cf => 1 ); # Associate the new CF with this queue
    $m->tick( AddCustomField => $_  => 0 ) for @names; # ...and not any other. ;-)
    $m->click('UpdateCFs');

    $m->content_contains("Added custom field img to General", 'TCF added to the queue' );
}

my $tester = RT::Test->load_or_create_user( Name => 'tester', Password => '123456' );
RT::Test->set_rights(
    { Principal => $tester->PrincipalObj,
      Right => [qw(SeeQueue ShowTicket CreateTicket)],
    },
);
ok $m->login( $tester->Name, 123456, logout => 1), 'logged in';

diag "check that we have no the CF on the create"
    ." ticket page when user has no SeeCustomField right";
{
    $m->submit_form(
        form_name => "CreateTicketInQueue",
        fields => { Queue => 'General' },
    );
    $m->content_lacks('Upload multiple images', 'has no upload image field');

    my $form = $m->form_name("TicketCreate");
    my $upload_field = "Object-RT::Ticket--CustomField-$cfid-Upload"; 
    ok !$form->find_input( $upload_field ), 'no form field on the page';

    $m->submit_form(
        form_name => "TicketCreate",
        fields => { Subject => 'test' },
    );
    $m->content_like(qr/Ticket \d+ created/, "a ticket is created succesfully");

    $m->content_lacks('img:', 'has no img field on the page');
    $m->follow_link( text => 'Custom Fields');
    $m->content_lacks('Upload multiple images', 'has no upload image field');
}

RT::Test->set_rights(
    { Principal => $tester->PrincipalObj,
      Right => [qw(SeeQueue ShowTicket CreateTicket SeeCustomField)],
    },
);

diag "check that we have no the CF on the create"
    ." ticket page when user has no ModifyCustomField right";
{
    $m->submit_form(
        form_name => "CreateTicketInQueue",
        fields => { Queue => 'General' },
    );
    $m->content_lacks('Upload multiple images', 'has no upload image field');

    my $form = $m->form_name("TicketCreate");
    my $upload_field = "Object-RT::Ticket--CustomField-$cfid-Upload";
    ok !$form->find_input( $upload_field ), 'no form field on the page';

    $m->submit_form(
        form_name => "TicketCreate",
        fields => { Subject => 'test' },
    );
    $tid = $1 if $m->content =~ /Ticket (\d+) created/i;
    ok $tid, "a ticket is created succesfully";

    $m->follow_link( id => 'page-basics');
    $m->content_lacks('Upload multiple images', 'has no upload image field');
    $form = $m->form_name('TicketModify');
    $upload_field = "Object-RT::Ticket-$tid-CustomField-$cfid-Upload";
    ok !$form->find_input( $upload_field ), 'no form field on the page';
}

RT::Test->set_rights(
    { Principal => $tester->PrincipalObj,
      Right => [qw(SeeQueue ShowTicket CreateTicket SeeCustomField ModifyCustomField)],
    },
);

diag "create a ticket with an image";
{
    $m->submit_form(
        form_name => "CreateTicketInQueue",
        fields => { Queue => 'General' },
    );
    $m->content_contains('Upload multiple images', 'has a upload image field');

    $cf =~ /(\d+)$/ or die "Hey this is impossible dude";
    my $upload_field = "Object-RT::Ticket--CustomField-$1-Upload";

    $m->submit_form(
        form_name => "TicketCreate",
        fields => {
            $upload_field => ImageFile,
            Subject => 'testing img cf creation',
        },
    );

    $m->content_like(qr/Ticket \d+ created/, "a ticket is created succesfully");

    $tid = $1 if $m->content =~ /Ticket (\d+) created/;

    $m->title_like(qr/testing img cf creation/, "its title is the Subject");

    $m->follow_link( text => 'bpslogo.png' );
    $m->content_is(ImageFileContent, "it links to the uploaded image");
}

$m->get( $m->rt_base_url );
$m->follow_link( id => 'search-tickets-new');
$m->title_is(q/Query Builder/, 'Query building');
$m->submit_form(
    form_name => "BuildQuery",
    fields => {
        idOp => '=',
        ValueOfid => $tid,
        ValueOfQueue => 'General',
        QueueOp => '=',
    },
    button => 'AddClause',
);

$m->form_name('BuildQuery');

my $col = ($m->current_form->find_input('SelectDisplayColumns'))[-1];
$col->value( ($col->possible_values)[-1] );

$m->click('AddCol');

$m->form_name('BuildQuery');
$m->click('DoSearch');

$m->follow_link( text_regex => qr/bpslogo\.png/ );
$m->content_is(ImageFileContent, "it links to the uploaded image");

__END__
[FC] Bulk Update does not have custom fields.
