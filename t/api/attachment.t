
use strict;
use warnings;
use RT;
use RT::Test tests => 7;


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
