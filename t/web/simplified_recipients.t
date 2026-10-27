use strict;
use warnings;

use RT::Test tests => undef, config => q{
    Set( $SimplifiedRecipients, 1 );

    Set(
        %PageLayouts,
        'RT::Ticket' => {
            Update => {
                'No Preview Scrips' => [
                    {
                        Layout   => 'col-md-7,col-md-5',
                        Elements => [ [ 'Recipients', 'Message', 'Submit' ], ['Basics'] ],
                    },
                ],
                'No Recipients' => [
                    {
                        Layout   => 'col-md-7,col-md-5',
                        Elements => [ [ 'Message', 'Submit', 'PreviewScrips' ], ['Basics'] ],
                    },
                ],
            },
        },
    );

    Set(
        %PageLayoutMapping,
        'RT::Ticket' => {
            Update => [
                {
                    Type   => 'Queue',
                    Layout => {
                        'NoPreviewScrips' => 'No Preview Scrips',
                        'NoRecipients'    => 'No Recipients',
                    },
                },
                {
                    Type   => 'Default',
                    Layout => 'Default',
                },
            ],
        },
    );
};

my ( $baseurl, $m ) = RT::Test->started_ok;
ok( $m->login, 'Logged in as root' );

my %ticket;
for my $queue (qw(General NoPreviewScrips NoRecipients)) {
    RT::Test->load_or_create_queue( Name => $queue );
    $ticket{$queue} = RT::Test->create_ticket(
        Queue     => $queue,
        Subject   => "Simplified recipients in $queue",
        Requestor => 'alice@example.com',
        Cc        => 'bob@example.com',
    );
}

diag 'Update page seeds exactly one TxnRecipients from submitted args';
for my $queue (qw(General NoPreviewScrips NoRecipients)) {
    $m->get_ok( $baseurl . '/Ticket/Update.html?Action=Respond;id=' . $ticket{$queue}->Id
            . ';TxnRecipients=alice%40example.com,bob%40example.com;TxnSendMailTo=bob%40example.com' );

    my @inputs = $m->content =~ /(<input[^>]*name="TxnRecipients"[^>]*>)/g;
    is( scalar @inputs, 1, "$queue: one TxnRecipients input" );
    like( $inputs[0] // '', qr/value="alice\@example\.com,bob\@example\.com"/,
        "$queue: TxnRecipients carries the submitted value" );
}

done_testing;
