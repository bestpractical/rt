
use strict;
use warnings;
use RT;
use RT::Test tests => undef;


{

ok (require RT::Attachment);


}

{

my $test1 = "From: jesse";
my @headers = RT::Attachment->_SplitHeaders($test1);
is ($#headers, 0, $test1 );

my $test2 = qq{From: jesse
To: bobby
Subject: foo
};

@headers = RT::Attachment->_SplitHeaders($test2);
is ($#headers, 2, "testing a bunch of singline multiple headers" );


my $test3 = qq{From: jesse
To: bobby,
 Suzie,
    Sally,
    Joey: bizzy,
Subject: foo
};

@headers = RT::Attachment->_SplitHeaders($test3);
is ($#headers, 2, "testing a bunch of singline multiple headers" );



}


{
    my $iso_8859_1_ticket_email =
      RT::Test::get_relocatable_file( 'new-ticket-from-iso-8859-1',
        ( File::Spec->updir(), 'data', 'emails' ) );
    my $content = RT::Test->file_content($iso_8859_1_ticket_email);

    my $parser = RT::EmailParser->new;
    $parser->ParseMIMEEntityFromScalar($content);
    my $attachment = RT::Attachment->new( $RT::SystemUser );
    my ( $id, $msg ) =
      $attachment->Create( TransactionId => 1, Attachment => $parser->Entity );
    ok( $id, $msg );
    my $mime = $attachment->ContentAsMIME;
    like( $mime->head->get('Content-Type'),
        qr/charset="iso-8859-1"/, 'content type of ContentAsMIME is original' );
    is(
        Encode::decode( 'iso-8859-1', $mime->stringify_body ),
        Encode::decode( 'UTF-8',      "Håvard\n" ),
        'body of ContentAsMIME is original'
    );
}

diag 'Test clearing and replacing header and content in attachments table';
{
    my $queue = RT::Test->load_or_create_queue( Name => 'General' );
    ok $queue && $queue->id, 'loaded or created queue';

    my $t = RT::Test->create_ticket( Queue => 'General', Subject => 'test' );
    ok $t && $t->id, 'created a ticket';

    $t->Comment( Content => 'test' );

    my $attachments = RT::Attachments->new(RT->SystemUser);
    $attachments->Limit(
        FIELD           => 'Content',
        OPERATOR        => 'LIKE',
        VALUE           => 'test',
    );
    is $attachments->Count, 1, 'Found content with "test"';

    # Replace attachment value for 'test' in Conetent col
    my ($ret, $msg) = $attachments->ReplaceAttachments(Search => 'test', Replacement => 'new_value', Headers => 0);
    ok $ret, $msg;

    $attachments->CleanSlate;

    $attachments->Limit(
        FIELD           => 'Content',
        OPERATOR        => 'LIKE',
        VALUE           => 'test',
    );
    is $attachments->Count, 0, 'Found no content with "test"';

    $attachments->Limit(
        FIELD           => 'Content',
        OPERATOR        => 'LIKE',
        VALUE           => 'new_value',
    );
    is $attachments->Count, 1, 'Found content with "new_value"';

    $attachments->CleanSlate;

    $attachments->Limit(
        FIELD           => 'Headers',
        OPERATOR        => 'LIKE',
        VALUE           => 'API',
    );
    is $attachments->Count, 1, 'Found header with content "API"';

    # Replace attachment value for 'API' in Header col
    ($ret, $msg) = $attachments->ReplaceAttachments(Search => 'API', Replacement => 'replacement', Content => 0);
    ok $ret, $msg;
    $attachments->CleanSlate;

    $attachments->Limit(
        FIELD           => 'Headers',
        OPERATOR        => 'LIKE',
        VALUE           => 'API',
    );
    is $attachments->Count, 0, 'Found no header with content "API"';
    $attachments->CleanSlate;

    $attachments->Limit(
        FIELD           => 'Headers',
        OPERATOR        => 'LIKE',
        VALUE           => 'replacement',
    );
    is $attachments->Count, 1, 'Found header with content "replacement"';

    ($ret, $msg) = $attachments->ReplaceAttachments(Search => 'new_value', Replacement => 'replacement', Content => 0);
    ok $ret, $msg;

    $attachments->CleanSlate;
    $attachments->Limit(
        FIELD           => 'Content',
        OPERATOR        => 'LIKE',
        VALUE           => 'new_value',
    );
    is $attachments->Count, 1, 'Content is not changed when flagged as false';

    ($ret, $msg) = $attachments->ReplaceAttachments(Search => 'replacement', Replacement => 'new_value', Headers => 0);
    ok $ret, $msg;

    $attachments->CleanSlate;
    $attachments->Limit(
        FIELD           => 'Headers',
        OPERATOR        => 'LIKE',
        VALUE           => 'replacement',
    );
    is $attachments->Count, 1, 'Headers are not replaced when flagged as false';
}

done_testing();
