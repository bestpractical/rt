#!/usr/bin/perl
use strict;
use warnings;
use RT::Test nodb => 1, tests => 4;
use Test::Warn;

use_ok('RT::I18N');
use utf8;
use Encode;
my $test_string    = 'À';
my $encoded_string = encode( 'iso-8859-1', $test_string );
my $mime           = MIME::Entity->build(
    Subject => $encoded_string,
    Data    => [$encoded_string],
);

# set the wrong charset mime in purpose
$mime->head->mime_attr( "Content-Type.charset" => 'utf8' );
warnings_are {
    RT::I18N::SetMIMEEntityToEncoding( $mime, 'iso-8859-1' );
} ['Encoding error: "\x{fffd}" does not map to iso-8859-1'], " We can't encode something into the wrong encoding without Encode complaining";


my $subject = decode( 'iso-8859-1', $mime->head->get('Subject') );
chomp $subject;
is( $subject, $test_string, 'subject is set to iso-8859-1' );
my $body = decode( 'iso-8859-1', $mime->stringify_body );
chomp $body;
is( $body, $test_string, 'body is set to iso-8859-1' );
