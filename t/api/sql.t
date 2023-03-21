use strict;
use warnings;

use RT::Test tests => undef;

# The IN version of this SQL is 4x faster in a real RT instance.
my $users = RT::Users->new( RT->SystemUser );
$users->WhoHaveGroupRight( Right => 'OwnTicket', Object => RT->System, IncludeSuperusers => 1 );
like(
    $users->BuildSelectQuery(PreferBind => 0),
    qr{RightName IN \('SuperUser', 'OwnTicket'\)},
    'RightName check in WhoHaveGroupRight uses IN'
);

my $root_id  = RT::Test->load_or_create_user( Name => 'root' )->id;
my $alice_id = RT::Test->load_or_create_user( Name => 'alice' )->id;
my $general_id = RT::Test->load_or_create_queue( Name => 'General' )->id;
my $support_id = RT::Test->load_or_create_queue( Name => 'Support' )->id;

my $lifecycles = RT->Config->Get('Lifecycles');
RT->Config->Set(
    Lifecycles => %{$lifecycles},
    hardware   => {
        type     => 'asset',
        initial  => ['new'],
        active   => ['tracked'],
        inactive => ['retired'],
        defaults => { on_create => 'new', },
    },
);

RT::Lifecycle->FillCache();

require RT::Test::Assets;
my $general_catalog_id = RT::Test::Assets->load_or_create_catalog( Name => 'General assets' )->Id;
my $hardware_catalog_id = RT::Test::Assets->load_or_create_catalog( Name => 'Hardware', Lifecycle => 'hardware' )->Id;

my %sql = (
    'RT::Tickets' => {
        like => {
            q{Status = 'new' OR Status = 'open'}                => qr{Status IN \('new', 'open'\)},
            q{Status = '__Active__'}                            => qr{Status IN \('new', 'open', 'stalled'\)},
            q{id = 2 OR id = 3}                                 => qr{id IN \('2', '3'\)},
            q{Creator = 'root' OR Creator = 'alice'}            => qr{Creator IN \('$alice_id', '$root_id'\)},
            q{Queue = 'General' OR Queue = 'Support'}           => qr{Queue IN \('$general_id', '$support_id'\)},
            q{Lifecycle = 'default' or Lifecycle = 'approvals'} => qr{Lifecycle IN \('approvals', 'default'\)},
            q{(Queue = 'General' OR Queue = 'Support') AND (Status = 'new' OR Status = 'open')} =>
                qr{Queue IN \('$general_id', '$support_id'\).+Status IN \('new', 'open'\)},
        },
        unlike => {
            q{Status = '__Active__' and Queue = 'General'}       => qr{approvals},
            q{Status = '__Inactive__' and Lifecycle = 'default'} => qr{approvals},
        },
    },
    'RT::Transactions' => {
        like => {
            q{TicketStatus = 'new' OR TicketStatus = 'open'}      => qr{Status IN \('new', 'open'\)},
            q{TicketStatus = '__Active__'}                        => qr{Status IN \('new', 'open', 'stalled'\)},
            q{id = 2 OR id = 3}                                   => qr{id IN \('2', '3'\)},
            q{Creator = 'root' OR Creator = 'alice'}              => qr{Creator IN \('$alice_id', '$root_id'\)},
            q{TicketCreator = 'root' OR TicketCreator = 'alice'}  => qr{Creator IN \('$alice_id', '$root_id'\)},
            q{TicketLastUpdatedBy = 'root' OR TicketLastUpdatedBy = 'alice'}  => qr{LastUpdatedBy IN \('$alice_id', '$root_id'\)},
            q{TicketQueue = 'General' OR TicketQueue = 'Support'} => qr{Queue IN \('$general_id', '$support_id'\)},
            q{TicketQueueLifecycle = 'default' or TicketQueueLifecycle = 'approvals'} =>
                qr{Lifecycle IN \('approvals', 'default'\)},
            q{(TicketQueue = 'General' OR TicketQueue = 'Support') AND (TicketStatus = 'new' OR TicketStatus = 'open')}
                => qr{Queue IN \('$general_id', '$support_id'\).+Status IN \('new', 'open'\)},
        },
        unlike => {
            q{TicketStatus = '__Active__' and TicketQueue = 'General'} => qr{approvals},
        },
    },
    'RT::Assets' => {
        like => {
            q{Status = 'new' OR Status = 'allocated'}             => qr{Status IN \('allocated', 'new'\)},
            q{Status = '__Active__'}                              => qr{Status IN \('allocated', 'in-use', 'new'\)},
            q{id = 2 OR id = 3}                                   => qr{id IN \('2', '3'\)},
            q{Catalog = 'General assets' OR Catalog = 'Hardware'} =>
                qr{Catalog IN \('$general_catalog_id', '$hardware_catalog_id'\)},
            q{(Catalog = 'General assets' OR Catalog = 'Hardware') AND (Status = 'allocated' OR Status = 'new')} =>
                qr{Catalog IN \('$general_catalog_id', '$hardware_catalog_id'\).+Status IN \('allocated', 'new'\)},
        },
        unlike => {
            q{Status = '__Active__' and Catalog = 'General assets'} => qr{hardware},
        },
    },
);

for my $type ( sort keys %sql ) {
    my $collection = $type->new( RT->SystemUser );
    for my $op ( sort keys %{ $sql{$type} } ) {
        for my $query ( sort keys %{ $sql{$type}{$op} } ) {
            $collection->FromSQL($query);
            no strict 'refs';
            $op->(
                $collection->BuildSelectQuery( PreferBind => 0 ),
                $sql{$type}{$op}{$query},
                qq{SQL "$query" is simplified}
            );
        }
    }

}

done_testing;
