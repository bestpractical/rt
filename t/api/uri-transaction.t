use strict;
use warnings;
use RT::Test::Assets tests => undef;
use Test::Warn;

my $ticket = RT::Test->create_ticket( Queue => 'General', Subject => 'txn uri' );
my $txn    = $ticket->Transactions->First;
ok( $txn && $txn->id, 'got a transaction' );
my $org = RT->Config->Get('Organization');

is( $txn->URI, "transaction://$org/" . $txn->id, 'RT::Transaction->URI' );

my $uri = RT::URI->new( RT->SystemUser );
ok( $uri->FromURI( "transaction://$org/" . $txn->id ), 'FromURI full URI' );
is( $uri->Resolver->Scheme, 'transaction', 'scheme is transaction' );
ok( $uri->Object, 'resolved an object' );
is( $uri->Object->id, $txn->id, 'resolved the right transaction' );

like(
    $uri->Resolver->HREF,
    qr{Transaction/Display\.html\?id=@{[$txn->id]}},
    'ticket transaction HREF links to the transaction display page'
);

my $catalog   = create_catalog( Name => 'txn uri catalog' );
my $asset     = create_asset( Name => 'txn uri asset', Catalog => $catalog->id );
my $asset_txn = $asset->Transactions->First;
ok( $asset_txn && $asset_txn->id, 'got an asset transaction' );
my $asset_uri = RT::URI->new( RT->SystemUser );
ok( $asset_uri->FromURI( "transaction://$org/" . $asset_txn->id ), 'FromURI asset transaction' );
like(
    $asset_uri->Resolver->HREF,
    qr{Asset/History\.html\?id=@{[$asset->id]}#txn-@{[$asset_txn->id]}},
    'asset transaction HREF links to the asset history page with the txn anchor'
);

my $user     = RT::Test->load_or_create_user( Name => 'txn uri user', Password => 'password' );
my $user_txn = $user->Transactions->First;
ok( $user_txn && $user_txn->id, 'got a user transaction' );
my $user_uri = RT::URI->new( RT->SystemUser );
ok( $user_uri->FromURI( "transaction://$org/" . $user_txn->id ), 'FromURI user transaction' );
like(
    $user_uri->Resolver->HREF,
    qr{User/History\.html\?id=@{[$user->id]}#txn-@{[$user_txn->id]}},
    'user transaction HREF links to the user history page, anchored at the txn'
);

is( $uri->Resolver->AsString, "Transaction #" . $txn->id, 'AsString' );

for my $short ( "transaction:" . $txn->id, "txn:" . $txn->id ) {
    my $u = RT::URI->new( RT->SystemUser );
    ok( $u->FromURI($short), "FromURI $short" );
    is( $u->Object && $u->Object->id, $txn->id, "$short resolves to the transaction" );
}

my $bad = RT::URI->new( RT->SystemUser );
my $ok;
warnings_like { $ok = $bad->FromURI("txn:0") }
[ qr/Unable to load transaction for id: 0/, qr/could not parse txn:0/ ], 'expected warnings for bad id';
ok( !$ok, 'txn:0 does not resolve' );

done_testing;
