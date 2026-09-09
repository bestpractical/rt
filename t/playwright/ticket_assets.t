use strict;
use warnings;

use RT::Test::Assets tests => undef, playwright => 1, config => q{
    Set(@AssetQueues, 'General');
};

my ( $url, $p ) = RT::Test->started_ok;

my $catalog = RT::Test::Assets->load_or_create_catalog( Name => 'Office' );
ok $catalog->id, 'Created catalog';

my $laptop  = create_asset( Name => 'Laptop',  Catalog => $catalog->id );
my $monitor = create_asset( Name => 'Monitor', Catalog => $catalog->id );

my $ticket    = RT::Test->create_ticket( Queue => 'General', Subject => 'Asset links' );
my $ticket_id = $ticket->Id;

$p->login();

diag "Pick two assets from the autocomplete, then add them";
{
    $p->goto_ticket($ticket_id);
    $p->wait_for_htmx;

    my $input_selector = qq{div.ticket-assets input[name="$ticket_id-RefersTo"]};
    $p->wait_for_element( $input_selector, { state => 'attached' } );

    for my $asset ( $laptop, $monitor ) {
        $p->{page}->evaluate("return document.querySelector('$input_selector').tomselect.control_input.focus()");
        $p->{page}->keyboard->type( $asset->Name );
        my $option = $p->{page}->locator( 'div.ticket-assets .ts-dropdown .option', { hasText => $asset->Name } );
        $p->{handle}->await( $option->waitFor( { timeout => 5000 } ) );
        $option->click;
    }

    my $items = $p->{page}->locator('div.ticket-assets .ts-control .item');
    is( $items->count, 2, 'Both picked assets are shown' );

    my $value = $p->{page}->evaluate("return document.querySelector('$input_selector').value");
    like( $value, qr/^\Q@{[$laptop->id]}\E\s+\Q@{[$monitor->id]}\E$/, 'Both picked asset ids are in the field' );

    $p->{page}->locator('div.ticket-assets button[name=AddAsset]')->click;

    # The assets box reloads via htmx once the links are added; wait for
    # both assets to show up there before reading the database.
    $p->wait_for_element( '#accordion-asset-' . $_->id . '-title' ) for $laptop, $monitor;

    DBIx::SearchBuilder::Record::Cachable->FlushCache;
    my $reloaded = RT::Ticket->new( RT->SystemUser );
    $reloaded->Load($ticket_id);
    my @linked = sort map { $_->TargetObj->id } @{ $reloaded->RefersTo->ItemsArrayRef };
    is_deeply( \@linked, [ sort $laptop->id, $monitor->id ], 'Ticket refers to both assets' );
}

$p->logout;
done_testing;
