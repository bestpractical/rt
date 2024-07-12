use strict;
use warnings;

use Test::Deep;
use Digest::SHA 'sha256_hex';
use RT::Test::Shredder tests => undef, config => <<'EOF';
my $storage_path = File::Spec->catdir(RT->Config->Get('LogDir'), 'attachments');
use File::Path 'mkpath';
mkpath($storage_path);
Set(%ExternalStorage,
    Type => 'Disk',
    Path => $storage_path,
);
Set($ExternalStorageCutoffSize, 20*1024);
EOF

my $test = "RT::Test::Shredder";
$test->create_savepoint('clean');

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

my $ticket = RT::Test->create_ticket(
    Subject => 'Test',
    Queue   => 'General',
    MIMEObj => $image_mime,
);

# Get rid of the warning of "TransactionBatch was fired on a ticket that no longer exists"
$ticket->ApplyTransactionBatch;

ok( RT::Test->run_singleton_command('sbin/rt-externalize-attachments'), "Ran rt-externalize-attachments successfully" );

my $attach = RT::Attachment->new( RT->SystemUser );
$attach->LoadByCols( Filename => 'owls.jpg' );
ok( $attach->Id, 'Found owls.jpg' );

is( $attach->_Value('Content'), $image_sha, 'owls.jpg is externalized' );

# Clean up the additional attribute for easier comparison
( RT->System->Attributes->Named("ExternalStorage") )[0]->Delete;

$test->create_savepoint('owls');

diag "Test shredder without external storage included";
{
    my $shredder = $test->shredder_new();
    $shredder->PutObjects( Objects => $ticket );
    $shredder->WipeoutAll;

    $test->db_is_valid;
    cmp_deeply( $test->dump_current_and_savepoint('clean'), "Shredded successfully" );

    is( RT->System->ExternalStorage->Get($image_sha), $image_content, 'External content is not deleted' );

    # Undo
    my $sql_file = $shredder->{dump_plugins}[0]->FileName;
    RT->DatabaseHandle->dbh->do($_) for split /^(?=INSERT)/m, RT::Test->file_content($sql_file);

    cmp_deeply( $test->dump_current_and_savepoint('owls'), "Undid successfully" );
}

diag "Test shredder with external storage included";
{
    $test->restore_savepoint('owls');

    local $RT::Shredder::IncludeExternalStorage = 1;
    my $shredder = $test->shredder_new();
    $shredder->PutObjects( Objects => $ticket );
    $shredder->WipeoutAll;

    my ($ret) = RT->System->ExternalStorage->Get($image_sha);
    ok( !$ret, 'External content is deleted' );

    $test->db_is_valid;
    cmp_deeply( $test->dump_current_and_savepoint('clean'), "Shredded successfully" );

    # Undo
    my $sql_file = $shredder->{dump_plugins}[0]->FileName;
    RT->DatabaseHandle->dbh->do($_) for split /^(?=INSERT)/m, RT::Test->file_content($sql_file);

    my $external_file = $shredder->{dump_plugins}[1]->FileName;
    ok( RT::Test->run_singleton_command($_), "$_ ran successfully" )
        for split /\n/, RT::Test->file_content($external_file);

    # Clean up the additional attribute
    ( RT->System->Attributes->Named("ExternalStorage") )[0]->Delete;
    cmp_deeply( $test->dump_current_and_savepoint('owls'), "Undid successfully" );
}

my $cf = RT::Test->load_or_create_custom_field( Name => 'Upload', Queue => 'General', Type => 'BinarySingle' );
ok( $ticket->AddCustomFieldValue( Field => $cf, Value => 'owls.jpg', LargeContent => $image_content ) );

ok( RT::Test->run_singleton_command('sbin/rt-externalize-attachments'), "Ran rt-externalize-attachments successfully" );

my $ocfv = $ticket->CustomFieldValues('Upload')->First;
is( $ocfv->LargeContent, $image_content );
is( $ocfv->_Value('LargeContent'), $image_sha, 'CF owls.jpg is externalized' );

# Clean up the additional attribute for easier comparison
( RT->System->Attributes->Named("ExternalStorage") )[0]->Delete;
$test->create_savepoint('2 owls');

diag "Test shredder with external content referenced by multiple times";
{
    local $RT::Shredder::IncludeExternalStorage = 1;
    my $shredder = $test->shredder_new();
    $shredder->PutObjects( Objects => $ocfv );
    $shredder->WipeoutAll;

    is( RT->System->ExternalStorage->Get($image_sha), $image_content, 'External content is not deleted' );

    $shredder = $test->shredder_new();
    $shredder->PutObjects( Objects => $ticket );
    $shredder->WipeoutAll;

    $shredder = $test->shredder_new();
    $shredder->PutObjects( Objects => $cf );
    $shredder->WipeoutAll;

    $test->db_is_valid;
    cmp_deeply( $test->dump_current_and_savepoint('clean'), "Shredded successfully" );

    my ($ret) = RT->System->ExternalStorage->Get($image_sha);
    ok( !$ret, 'External content is deleted' );
}

done_testing;
