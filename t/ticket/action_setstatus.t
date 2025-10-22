use strict;
use warnings;

use RT;
use RT::Test tests => undef;
use IPC::Run3 'run3';

my ($id, $msg);

use_ok('RT::Action::SetStatus');

my $q = RT::Test->load_or_create_queue( Name => 'General' );
ok $q && $q->id, 'loaded or created queue';

# Load the root user which already exists and has all necessary permissions
my $root = RT::User->new(RT->SystemUser);
$root->Load('root');
ok $root && $root->id, 'loaded root user';

# Set Gecos for rt-crontool
$root->SetGecos( ( getpwuid($<) )[0] );

my $first_ticket = RT::Test->create_ticket(
    Queue => $q->id,
    Subject => "First ticket - will depend on second",
);
ok($first_ticket && $first_ticket->id, "Created first ticket");

my $second_ticket = RT::Test->create_ticket(
    Queue => $q->id,
    Subject => "Second ticket - dependency",
);
ok($second_ticket && $second_ticket->id, "Created second ticket");

# Create dependency: first ticket depends on second ticket
($id, $msg) = $first_ticket->AddLink( Type => 'DependsOn', Target => $second_ticket->id );
ok($id, "Created dependency link? " . $msg);

my $first_id = $first_ticket->id;

diag "Resolve with dependencies does not change status";
{
    my $stdout = '';
    my $stderr = '';
    run3(
        [
            "$RT::BinPath/rt-crontool", '--search', 'RT::Search::FromSQL', '--search-arg',
            "id = $first_id", '--action', 'RT::Action::SetStatus', '--action-arg', 'resolved', '--transaction', 'first'
        ],
        \undef,
        \$stdout,
        \$stderr
    );

    DBIx::SearchBuilder::Record::Cachable->FlushCache;
    $first_ticket->Load($first_id);
    is( $first_ticket->Status, 'new', "First ticket should still be 'new' - resolution blocked by dependency" );

    # If this test fails because the message is changed, also update RT::Action::SetStatus
    # and any other locations that rely on the specific message.
    like( $stderr, qr/That ticket has unresolved dependencies/, "Expected message about unresolved dependencies" );
    like( $stderr, qr/\[warning\]/, "Unresolved dependency message should be logged at warning level" );
    unlike( $stderr, qr/\[error\]/, "Unresolved dependency message should not be logged at error level" );
}

diag "Use rt-crontool to resolve the dependent ticket";
{
    my $second_id = $second_ticket->Id;
    my $stdout = '';
    my $stderr = '';
    run3(
        [
            "$RT::BinPath/rt-crontool", '--search', 'RT::Search::FromSQL', '--search-arg',
            "id = $second_id", '--action', 'RT::Action::SetStatus', '--action-arg', 'resolved', '--transaction', 'first'
        ],
        \undef,
        \$stdout,
        \$stderr
    );

    DBIx::SearchBuilder::Record::Cachable->FlushCache;
    $second_ticket->Load($second_id);
    is( $second_ticket->Status, 'resolved', "Second ticket is resolved" );
}

diag "Resolve on initial ticket now succeeds";
{
    my $stdout = '';
    my $stderr = '';
    run3(
        [
            "$RT::BinPath/rt-crontool", '--search', 'RT::Search::FromSQL', '--search-arg',
            "id = $first_id", '--action', 'RT::Action::SetStatus', '--action-arg', 'resolved', '--transaction', 'first'
        ],
        \undef,
        \$stdout,
        \$stderr
    );

    DBIx::SearchBuilder::Record::Cachable->FlushCache;
    $first_ticket->Load($first_id);

    is( $first_ticket->Status, 'resolved', "First ticket is resolved" );
}

done_testing;
