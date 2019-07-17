use strict;
use warnings;

use RT::Test tests => undef;
my ( $baseurl, $m ) = RT::Test->started_ok;

my $ticket = RT::Ticket->new( RT->SystemUser );
$ticket->Create(
    Subject   => 'Test ticket',
    Queue     => 'General',
    Owner     => 'root',
);

ok( $ticket->SetStatus('open') );

is( $ticket->Transactions->Count, 3, 'Ticket has 3 txns' );

$m->login;

diag "Query builder";
{
    $m->follow_link_ok( { text => 'New Search', url_regex => qr/Class=RT::Transaction/ }, 'Query builder' );
    $m->title_is('Transaction Query Builder');

    $m->form_name('BuildQuery');
    $m->field( TicketIdOp      => '=' );
    $m->field( ValueOfTicketId => 1 );
    $m->click('AddClause');

    $m->follow_link_ok( { id => 'page-results' } );
    $m->title_is('Found 3 transactions');

    $m->back;
    $m->form_name('BuildQuery');
    $m->field( TypeOp      => '=' );
    $m->field( ValueOfType => 'Create' );
    $m->click('AddClause');

    $m->follow_link_ok( { id => 'page-results' } );
    $m->title_is('Found 1 transaction');
    $m->text_contains( 'Ticket created', 'Got create txn' );
}

diag "Advanced";
{
    $m->follow_link_ok( { text => 'New Search', url_regex => qr/Class=RT::Transaction/ }, 'Query builder' );
    $m->follow_link_ok( { text => 'Advanced' }, 'Advanced' );
    $m->title_is('Edit Transaction Query');

    $m->form_name('BuildQueryAdvanced');
    $m->field( Query => q{OldValue = 'new'} );
    $m->submit;

    $m->follow_link_ok( { id => 'page-results' } );
    $m->title_is('Found 1 transaction');
    $m->text_contains( q{Status changed from 'new' to 'open'}, 'Got status change txn' );
}

diag "Saved searches";
{
    $m->follow_link_ok( { text => 'New Search', url_regex => qr/Class=RT::Transaction/ }, 'Query builder' );
    $m->form_name('BuildQuery');
    $m->field( ValueOfTicketId => 10 );
    $m->submit('AddClause');

    $m->form_name('BuildQuery');
    $m->field( SavedSearchDescription => 'test txn search' );
    $m->click('SavedSearchSave');
    $m->text_contains('Current search: test txn search');

    my $form = $m->form_name('BuildQuery');
    my $input = $form->find_input( 'SavedSearchLoad' );
    # an empty search and the real saved search
    is( scalar $input->possible_values, 2, '2 SavedSearchLoad options' );

    my ($attr_id) = ($input->possible_values)[1] =~ /(\d+)$/;
    my $attr = RT::Attribute->new(RT->SystemUser);
    $attr->Load($attr_id);
    is_deeply(
        $attr->Content,
        {
            'Format' => '\'<b><a href="__WebPath__/Transaction/Display.html?id=__id__">__id__</a></b>/TITLE:ID\',
\'<b><a href="__WebPath__/Ticket/Display.html?id=__ObjectId__">__ObjectId__</a></b>/TITLE:Ticket\',
\'__Description__\',
\'<small>__OldValue__</small>\',
\'<small>__NewValue__</small>\',
\'<small>__Content__</small>\',
\'<small>__CreatedRelative__</small>\'',
            'OrderBy'     => 'id|||',
            'SearchType'  => 'Transaction',
            'RowsPerPage' => '50',
            'Order'       => 'ASC|ASC|ASC|ASC',
            'Query'       => 'TicketId < 10',
            'ObjectType'  => 'RT::Ticket'
        },
        'Saved search content'
    );
}

done_testing;
