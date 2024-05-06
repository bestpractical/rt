
use strict;
use warnings;

use RT::Test tests => undef;

ok(require RT::EmailParser);

RT->Config->Set( RTAddressRegexp => undef );
is(RT::EmailParser::IsRTAddress("",""),undef, "Empty emails from users don't match queues without email addresses" );

my $general = RT::Test->load_or_create_queue(Name => 'General');
ok( $general->SetCorrespondAddress('general@example.com'), 'Updated CorrespondAddress' );
ok( $general->SetCommentAddress('comment@example.com'), 'Updated CommentAddress' );
is( RT::EmailParser::IsRTAddress( "", "general\@example.com" ), 1, "Queue CorrespondAddress matched rt address" );
is( RT::EmailParser::IsRTAddress( "", "comment\@example.com" ), 1, "Queue CommentAddress matched rt address" );

RT->Config->Set( RTAddressRegexp => qr/^rt\@example.com$/i );

is(RT::EmailParser::IsRTAddress("","rt\@example.com"),1, "Regexp matched rt address" );
is(RT::EmailParser::IsRTAddress("","frt\@example.com"),undef, "Regexp didn't match non-rt address" );

is( RT::EmailParser::IsRTAddress( "", "general\@example.com" ), 1, "Queue CorrespondAddress matched rt address" );
is( RT::EmailParser::IsRTAddress( "", "comment\@example.com" ), 1, "Queue CommentAddress matched rt address" );

my @before = ("rt\@example.com", "frt\@example.com");
my @after = ("frt\@example.com");
ok(eq_array(RT::EmailParser->CullRTAddresses(@before),@after), "CullRTAddresses only culls RT addresses");

{
    my ( $addr ) =
      RT::EmailParser->ParseEmailAddress('foo@example.com');
    is( $addr->address, 'foo@example.com', 'addr for foo@example.com' );
    is( $addr->phrase,  undef,             'no name for foo@example.com' );

    ( $addr ) =
      RT::EmailParser->ParseEmailAddress('Foo <foo@example.com>');
    is( $addr->address, 'foo@example.com', 'addr for Foo <foo@example.com>' );
    is( $addr->phrase,  'Foo',             'name for Foo <foo@example.com>' );

    ( $addr ) =
      RT::EmailParser->ParseEmailAddress('foo@example.com (Comment)');
    is( $addr->address, 'foo@example.com', 'addr for foo@example.com (Comment)' );
    is( $addr->phrase,  undef,             'no name for foo@example.com (Comment)' );
}

done_testing;
