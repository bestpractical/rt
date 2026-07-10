
use strict;
use warnings;
use RT;
use RT::Test tests => undef;
use Test::Warn;

use_ok ('RT::Transaction');

{
    my $u = RT::User->new(RT->SystemUser);
    $u->Load("root");
    ok ($u->Id, "Found the root user");
    ok(my $t = RT::Ticket->new(RT->SystemUser));
    my ($id, $msg) = $t->Create( Queue => 'General',
                                    Subject => 'Testing',
                                    Owner => $u->Id
                               );
    ok($id, "Create new ticket $id");
    isnt($id , 0);

    my $txn = RT::Transaction->new(RT->SystemUser);
    my ($txn_id, $txn_msg) = $txn->Create(
                  Type => 'AddLink',
                  Field => 'RefersTo',
                  Ticket => $id,
                  NewValue => 'ticket 42', );
    ok( $txn_id, "Created transaction $txn_id: $txn_msg");

    my $brief;
    warning_like { $brief = $txn->BriefDescription }
                  qr/Could not determine a URI scheme/,
                    "Caught URI warning";

    is( $brief, 'Reference to ticket 42 added', "Got string description: $brief");

    $txn = RT::Transaction->new(RT->SystemUser);
    ($txn_id, $txn_msg) = $txn->Create(
                  Type => 'DeleteLink',
                  Field => 'RefersTo',
                  Ticket => $id,
                  OldValue => 'ticket 42', );
    ok( $txn_id, "Created transaction $txn_id: $txn_msg");

    warning_like { $brief = $txn->BriefDescription }
                  qr/Could not determine a URI scheme/,
                    "Caught URI warning";

    is( $brief, 'Reference to ticket 42 deleted', "Got string description: $brief");

}

diag 'Test Content';
{
    require MIME::Entity;

    my $plain_file = File::Spec->catfile( RT::Test->temp_directory, 'attachment.txt' );
    open my $plain_fh, '>', $plain_file or die $!;
    print $plain_fh 'this is attachment';
    close $plain_fh;

    my @mime;

    my $mime = MIME::Entity->build( Data => [ 'main body' ] );
    push @mime, { object => $mime, expected => 'main body', description => 'no attachment' };

    $mime = MIME::Entity->build( Type => 'multipart/mixed' );
    $mime->attach(
        Type => 'text/plain',
        Data => [ 'main body' ],
    );
    $mime->attach(
        Path => $plain_file,
        Type => 'text/plain',
    );
    push @mime, { object => $mime, expected => 'main body', description => 'has an attachment' };

    $mime = MIME::Entity->build( Type => 'multipart/mixed' );
    $mime->attach(
        Path => $plain_file,
        Type => 'text/plain',
    );
    $mime->attach(
        Type => 'text/plain',
        Data => [ 'main body' ],
    );
    push @mime, { object => $mime, expected => 'main body', description => 'has an attachment as the first part' };

    $mime = MIME::Entity->build( Type => 'multipart/mixed' );
    $mime->attach(
        Path => $plain_file,
        Type => 'text/plain',
    );
    push @mime,
      { object => $mime, expected => 'This transaction appears to have no content', description => 'has an attachment but no main part' };

    my $parser = MIME::Parser->new();
    $parser->output_to_core(1);
    $mime = $parser->parse_data( <<EOF );
Content-Type: multipart/mixed; boundary="=-=-="

--=-=-=
Content-Type: message/rfc822
Content-Disposition: inline

Content-Type: text/plain
Subject: test

main body
--=-=-=
EOF

    push @mime, { object => $mime, expected => "main body", description => 'has an rfc822 message' };

    $mime = $parser->parse_data( <<EOF );
Content-Type: multipart/mixed; boundary="=-=-="

--=-=-=
Content-Type: message/rfc822
Content-Disposition: attachment

Content-Type: text/plain
Subject: test

inner body of rfc822

--=-=-=
Content-Type: text/plain
Subject: test

main body
--=-=-=

EOF

    push @mime,
      { object => $mime, expected => 'main body', description => 'has an attachment of rfc822 message and main part' };

    for my $mime ( @mime ) {
        my $ticket = RT::Ticket->new( RT->SystemUser );
        my ( $id, $txn_id ) = $ticket->Create(
            Queue   => 'General',
            Subject => 'Testing content',
            MIMEObj => $mime->{object},
        );
        ok( $id,     'Created ticket' );
        ok( $txn_id, 'Created transaction' );
        my $txn = RT::Transaction->new( RT->SystemUser );
        $txn->Load( $txn_id );
        is( $txn->Content, $mime->{expected}, "Got expected content for MIME: $mime->{description}" );
    }
}

# Test GetTransactionTypes method
{
    # Test default behavior (all transaction types)
    my @all_types = RT::Transaction->GetTransactionTypes();
    ok(@all_types > 0, 'GetTransactionTypes returns some transaction types');

    # Check that we get common types like Create, Correspond, Comment
    my %all_types_hash = map { $_ => 1 } @all_types;
    ok(exists $all_types_hash{Create}, 'All types includes Create');
    ok(exists $all_types_hash{Correspond}, 'All types includes Correspond');
    ok(exists $all_types_hash{Comment}, 'All types includes Comment');

    # Test short list behavior
    my @short_types = RT::Transaction->GetTransactionTypes(TicketList => 1);
    ok(@short_types > 0, 'GetTransactionTypes with TicketList returns some types');
    ok(@short_types < @all_types, 'Short list has fewer types than full list');

    # Check that short list contains expected common types
    my %short_types_hash = map { $_ => 1 } @short_types;
    ok(exists $short_types_hash{Create}, 'Short list includes Create');
    ok(exists $short_types_hash{Correspond}, 'Short list includes Correspond');
    ok(exists $short_types_hash{Comment}, 'Short list includes Comment');
    ok(exists $short_types_hash{Status}, 'Short list includes Status');

    # Verify short list is a subset of all types
    for my $type (@short_types) {
        ok(exists $all_types_hash{$type}, "Short list type '$type' exists in full list");
    }

    # Test that both lists are sorted
    my @all_sorted = sort @all_types;
    my @short_sorted = sort @short_types;
    is_deeply(\@all_types, \@all_sorted, 'All types list is sorted');
    is_deeply(\@short_types, \@short_sorted, 'Short types list is sorted');

    # Test asset list behavior
    my @asset_types = RT::Transaction->GetTransactionTypes(AssetList => 1);
    ok(@asset_types > 0, 'GetTransactionTypes with AssetList returns some types');
    ok(@asset_types <= @all_types, 'Asset list has fewer or equal types than full list');

    # Check that asset list contains expected common types
    my %asset_types_hash = map { $_ => 1 } @asset_types;
    ok(exists $asset_types_hash{Create}, 'Asset list includes Create');
    ok(exists $asset_types_hash{Status}, 'Asset list includes Status');
    ok(exists $asset_types_hash{Set}, 'Asset list includes Set');

    # Verify asset list is a subset of all types
    for my $type (@asset_types) {
        ok(exists $all_types_hash{$type}, "Asset list type '$type' exists in full list");
    }

    # Test that asset list is sorted
    my @asset_sorted = sort @asset_types;
    is_deeply(\@asset_types, \@asset_sorted, 'Asset types list is sorted');
}

diag 'Roll back and report failure when the database aborts the transaction';
{
    my $queue = RT::Test->load_or_create_queue( Name => 'AbortTest' );
    ok( $queue->id, "loaded/created queue " . $queue->id );

    my $poison = '$DBIx::SearchBuilder::Handle::TRANSABORT{ RT->DatabaseHandle->dbh } = 1; return 1;';

    my $comment_scrip = RT::Scrip->new( RT->SystemUser );
    my ( $sid, $smsg ) = $comment_scrip->Create(
        Queue             => $queue->id,
        ScripCondition    => 'On Comment',
        ScripAction       => 'User Defined',
        CustomPrepareCode => 'return 1',
        CustomCommitCode  => $poison,
        Template          => 'Blank',
    );
    ok( $sid, "created On Comment poisoning scrip: $smsg" );

    my $ticket = RT::Test->create_ticket( Queue => $queue->id, Subject => 'abort me' );
    ok( $ticket->id, "created ticket " . $ticket->id );
    my $before = $ticket->Transactions->Count;

    my ( $ok, $msg );
    warnings_like {
        ( $ok, $msg ) = $ticket->Comment( Content => 'trigger the scrip' );
    }
    [ qr/the database transaction was aborted/, qr/couldn't init a transaction/ ],
        "logged the aborted-transaction reason for the comment";

    ok( !$ok, "Comment reports failure when the transaction was aborted" );

    $ticket->Load( $ticket->id );
    is( $ticket->Transactions->Count, $before, "the comment transaction was rolled back; none persisted" );
    ok( !RT->DatabaseHandle->TransactionAborted, "the database handle is clean after the rolled-back comment" );

    my $create_scrip = RT::Scrip->new( RT->SystemUser );
    ( $sid, $smsg ) = $create_scrip->Create(
        Queue             => $queue->id,
        ScripCondition    => 'On Create',
        ScripAction       => 'User Defined',
        CustomPrepareCode => 'return 1',
        CustomCommitCode  => $poison,
        Template          => 'Blank',
    );
    ok( $sid, "created On Create poisoning scrip: $smsg" );

    my $tickets = RT::Tickets->new( RT->SystemUser );
    $tickets->Limit( FIELD => 'Queue', VALUE => $queue->id );
    my $count = $tickets->Count;

    my $id;
    warnings_like {
        ($id) = RT::Ticket->new( RT->SystemUser )->Create( Queue => $queue->id, Subject => 'abort on create' );
    }
    [ qr/the database transaction was aborted/, qr/Ticket couldn't be created/ ],
        "logged the aborted-transaction reason for the create";

    ok( !$id, "Create reports failure when a scrip aborts the transaction" );

    $tickets->RedoSearch;
    is( $tickets->Count, $count, "no new ticket persisted after the aborted create" );
    ok( !RT->DatabaseHandle->TransactionAborted, "the database handle is clean after the rolled-back create" );
}

done_testing;
