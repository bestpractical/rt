use strict;
use warnings;

use Test::Deep;
use RT::Test::Shredder tests => undef;
use MIME::Entity;

my $test = "RT::Test::Shredder";

my @ARGS = sort qw(limit files_only file longer);

use_ok('RT::Shredder::Plugin::Attachments');
{
    my $plugin = RT::Shredder::Plugin::Attachments->new;
    isa_ok( $plugin, 'RT::Shredder::Plugin::Attachments' );

    is( lc $plugin->Type, 'search', 'correct type' );

    my @args = sort $plugin->SupportArgs;
    cmp_deeply( \@args, \@ARGS, "support all args" );
}

{
    my $ticket = RT::Ticket->new( RT->SystemUser );
    my $mime   = MIME::Entity->build(
        From => 'test@example.com',
        Type => 'text/html',
        Data => ['test attachment'],
    );

    $mime->attach(
        Path => 'share/static/images/bpslogo.png',
        Type => 'image/png',
    );

    RT::Test->create_ticket( MIMEObj => $mime, Queue => 'General', Subject => 'test attachment' );
    my $attachments = RT::Attachments->new( RT->SystemUser );
    $attachments->Limit( FIELD => 'Filename', VALUE => 'bpslogo.png' );
    is( $attachments->Count, 1, 'created the attachment' );

    my $plugin = RT::Shredder::Plugin::Attachments->new;
    my ( $status, $msg ) = $plugin->TestArgs( name => 'bpslogo.png', longer => '1k' );
    ok( $status, "plugin arguments are ok" ) or diag "error: $msg";

    ( $status, my @objects ) = $plugin->Run;
    ok( $status, "executed plugin successfully" ) or diag "error: @objects";
    is( scalar @objects, 1, 'found 1 attachment' );

    my $shredder = $test->shredder_new();
    $shredder->PutObjects( Objects => \@objects );
    $shredder->WipeoutAll;

    $attachments = RT::Attachments->new( RT->SystemUser );
    $attachments->Limit( FIELD => 'Filename', VALUE => 'bpslogo.png' );
    is( $attachments->Count, 0, 'shredded the attachment' );
}

done_testing;
