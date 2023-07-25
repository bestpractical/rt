use strict;
use warnings;

# Set ExternalStorage in config file to run rt-externalize-attachments
use RT::Test tests => undef, config => <<'EOF';
my $storage_path = File::Spec->catdir(RT->Config->Get('LogDir'), 'attachments');
use File::Path 'mkpath';
mkpath($storage_path);
Set(%ExternalStorage,
    Type => 'Disk',
    Path => $storage_path,
);
Set($ExternalStorageCutoffSize, 20*1024);
EOF

RT::Config->Set('ShredderStoragePath', RT::Test->temp_directory . '');

# Disable ExternalStorage for old tests
my %storage_config = RT->Config->Get( 'ExternalStorage' );
RT->Config->Set( 'ExternalStorage' );
RT->Config->PostLoadCheck;

my ( $baseurl, $agent ) = RT::Test->started_ok;

diag("Test server running at $baseurl");

$agent->login('root' => 'password');

my $ticket_id;
# Ticket created in block to avoid scope error on destroy
{
    my $ticket = RT::Test->create_ticket( Subject => 'test shredder', Queue => 1, );
    ok( $ticket->Id, "created new ticket" );

    $ticket_id = $ticket->id;
}

{
    $agent->get_ok($baseurl . '/Admin/Tools/Shredder/');
    $agent->submit_form_ok({
        form_id     => 'shredder-search-form',
        fields      => { Plugin => 'Tickets'},
    }, "Select Tickets shredder plugin");

    $agent->submit_form_ok({
        form_id     => 'shredder-search-form',
        fields      => {
            'Tickets:query'  => 'id=' . $ticket_id,
        },
        button => 'Search',
    }, "Search for ticket object");
    $agent->content_lacks('Wipeout Including External Storage', 'No External Storage button' );

    $agent->submit_form_ok({
        form_id     => 'shredder-search-form',
        fields      => {
            'WipeoutObject'     => 'RT::Ticket-example.com-' . $ticket_id,
        },
        button => 'Wipeout',
    }, "Select and destroy ticket object");
    $agent->text_contains('objects were successfuly removed', 'Found success message' );

    my $ticket = RT::Ticket->new(RT->SystemUser);
    my ($ret, $msg) = $ticket->Load($ticket_id);

    ok !$ret, 'Ticket successfully shredded';
}

# Shred RT::User
{
    my $user = RT::Test->load_or_create_user( EmailAddress => 'test@example.com' );

    my $id = $user->id;
    ok $id;

    $agent->get_ok($baseurl . '/Admin/Tools/Shredder/');
    $agent->submit_form_ok({
        form_id     => 'shredder-search-form',
        fields      => { Plugin => 'Users'},
    }, "Select Users shredder plugin");

    $agent->submit_form_ok({
        form_id     => 'shredder-search-form',
        fields      => {
            'Users:email'  => 'test@example.com',
            'Users:status' => 'Enabled',
        },
        button => 'Search',
    }, "Search for user");
    $agent->content_lacks('Wipeout Including External Storage', 'No External Storage button' );

    $agent->submit_form_ok({
        form_id     => 'shredder-search-form',
        fields      => {
            'WipeoutObject'     => 'RT::User-test@example.com',
        },
        button => 'Wipeout',
    }, "Select and destroy searched user");
    $agent->text_contains('objects were successfuly removed', 'Found success message' );

    my ($ret, $msg) = $user->Load($id);
    ok !$ret, 'User successfully shredded';
}

# Shred RT::Ticket with external storage
RT::Test->stop_server;
use Digest::SHA 'sha256_hex';
RT->Config->Set( 'ExternalStorage', %storage_config, );
RT->Config->PostLoadCheck;

my $image_mime = MIME::Entity->build(
    Type    => 'text/plain',
    Subject => 'Test external storage',
    Data    => <<END,
This is a test
END
);

my $image_path    = RT::Test::get_relocatable_file( 'owls.jpg', '..', 'data' );
my $image_content = RT::Test->file_content($image_path);
my $image_sha     = sha256_hex($image_content);

$image_mime->attach(
    Path     => $image_path,
    Type     => "image/gif",
    Encoding => "base64",
);

( $baseurl, $agent ) = RT::Test->started_ok;
$agent->login( 'root' => 'password' );

diag "Test shredder without external storage included";
{
    my $ticket_id = create_image_ticket();

    $agent->get_ok( $baseurl . '/Admin/Tools/Shredder/' );
    $agent->submit_form_ok(
        {
            form_id => 'shredder-search-form',
            fields  => { Plugin => 'Tickets' },
        },
        "Select Tickets shredder plugin"
    );

    $agent->submit_form_ok(
        {
            form_id => 'shredder-search-form',
            fields  => {
                'Tickets:query' => 'id=' . $ticket_id,
            },
            button => 'Search',
        },
        "Search for ticket object"
    );
    $agent->content_contains( 'Wipeout Including External Storage', 'Found External Storage button' );

    $agent->submit_form_ok(
        {
            form_id => 'shredder-search-form',
            fields  => {
                'WipeoutObject' => 'RT::Ticket-example.com-' . $ticket_id,
            },
            button => 'Wipeout',
        },
        "Select and destroy ticket object"
    );
    $agent->text_contains( 'objects were successfuly removed', 'Found success message' );
    ok( $agent->find_link( text  => 'Download dumpfile' ),                  'Found dumpfile' );
    ok( !$agent->find_link( text => 'Download external storage dumpfile' ), 'No external storage dumpfile' );

    my $ticket = RT::Ticket->new( RT->SystemUser );
    my ($ret) = $ticket->Load($ticket_id);
    ok !$ret, 'Ticket successfully shredded';
    is( RT->System->ExternalStorage->Get($image_sha), $image_content, 'External content is not deleted' );
}

diag "Test shredder with external storage included";
{
    my $ticket_id = create_image_ticket();
    $agent->get_ok( $baseurl . '/Admin/Tools/Shredder/' );
    $agent->submit_form_ok(
        {
            form_id => 'shredder-search-form',
            fields  => { Plugin => 'Tickets' },
        },
        "Select Tickets shredder plugin"
    );

    $agent->submit_form_ok(
        {
            form_id => 'shredder-search-form',
            fields  => {
                'Tickets:query' => 'id=' . $ticket_id,
            },
            button => 'Search',
        },
        "Search for ticket object"
    );
    $agent->content_contains( 'Wipeout Including External Storage', 'No External Storage button' );

    $agent->submit_form_ok(
        {
            form_id => 'shredder-search-form',
            fields  => {
                'WipeoutObject' => 'RT::Ticket-example.com-' . $ticket_id,
            },
            button => 'WipeoutIncludingExternalStorage',
        },
        "Select and destroy ticket object"
    );
    $agent->text_contains( 'objects were successfuly removed', 'Found success message' );

    ok( $agent->find_link( text => 'Download dumpfile' ),                  'Found dumpfile' );
    ok( $agent->find_link( text => 'Download external storage dumpfile' ), 'Found external storage dumpfile' );

    my $ticket = RT::Ticket->new( RT->SystemUser );
    my ($ret) = $ticket->Load($ticket_id);
    ok !$ret, 'Ticket successfully shredded';
    ($ret) = RT->System->ExternalStorage->Get($image_sha);
    ok( !$ret, 'External content is deleted' );
}

sub create_image_ticket {
    my $ticket = RT::Test->create_ticket(
        Subject => 'Test',
        Queue   => 'General',
        MIMEObj => $image_mime,
    );

    ok( RT::Test->run_singleton_command('sbin/rt-externalize-attachments'),
        "Ran rt-externalize-attachments successfully" );

    # reset to re-externalize all later
    ( RT->System->Attributes->Named("ExternalStorage") )[0]->Delete;

    my $attach = RT::Attachment->new( RT->SystemUser );
    $attach->LoadByCols( Filename => 'owls.jpg' );
    ok( $attach->Id, 'Found owls.jpg' );
    is( $attach->_Value('Content'), $image_sha, 'owls.jpg is externalized' );
    return $ticket->Id;
}

done_testing();
