
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

done_testing;
