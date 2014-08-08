use strict;
use warnings;
use RT::Test nodb => 1, tests => undef;

use_ok('RT::I18N');
my $test_string    = Encode::decode("UTF-8", 'À');
my $encoded_string = Encode::encode( 'iso-8859-1', $test_string );
my $mime           = MIME::Entity->build(
    "Subject" => $encoded_string,
    "Data"    => [$encoded_string],
);

# set the wrong charset mime in purpose
$mime->head->mime_attr( "Content-Type.charset" => 'utf8' );

my @warnings;
local $SIG{__WARN__} = sub {
    push @warnings, "@_";
};

RT::I18N::SetMIMEEntityToEncoding( $mime, 'iso-8859-1' );

# this is a weird behavior for different perl versions, 5.12 warns twice,
# which is correct since we do the encoding thing twice, for Subject
# and Data respectively.
# but 5.8 and 5.10 warns only once.
ok( @warnings == 1 || @warnings == 2, "1 or 2 warnings are ok" );
ok( @warnings == 1 || ( @warnings == 2 && $warnings[1] eq $warnings[0] ),
    'if there are 2 warnings, they should be same' );

like(
    $warnings[0],
    qr/\QEncoding error: "\x{fffd}" does not map to iso-8859-1/,
"We can't encode something into the wrong encoding without Encode complaining"
);

my $subject = Encode::decode( 'iso-8859-1', $mime->head->get('Subject') );
chomp $subject;
is( $subject, $test_string, 'subject is set to iso-8859-1' );
my $body = Encode::decode( 'iso-8859-1', $mime->stringify_body );
chomp $body;
is( $body, $test_string, 'body is set to iso-8859-1' );

done_testing;
