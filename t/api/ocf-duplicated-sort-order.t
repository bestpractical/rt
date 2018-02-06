use strict;
use warnings;
use RT::Test tests => undef;

my $queue_foo = RT::Test->load_or_create_queue( Name => 'foo' );
my $queue_bar = RT::Test->load_or_create_queue( Name => 'bar' );

my $global_cf_1 = RT::Test->load_or_create_custom_field( Name => 'global 1', Type => 'Freeform', Queue => 0 );
my $global_cf_2 = RT::Test->load_or_create_custom_field( Name => 'global 2', Type => 'Freeform', Queue => 0 );

my $foo_cf_1 = RT::Test->load_or_create_custom_field( Name => 'foo 1', Type => 'Freeform', Queue => $queue_foo->id );
my $bar_cf_1 = RT::Test->load_or_create_custom_field( Name => 'bar 1', Type => 'Freeform', Queue => $queue_bar->id );

my $ocf = RT::ObjectCustomField->new( RT->SystemUser );
$ocf->LoadByCols( CustomField => $foo_cf_1->id, ObjectId => $queue_foo->id );
my ( $ret, $msg ) = $ocf->MoveUp;
ok( $ret, "foo 1 moved up" );

$ocf = RT::ObjectCustomField->new( RT->SystemUser );
$ocf->LoadByCols( CustomField => $bar_cf_1->id, ObjectId => $queue_bar->id );
for ( 1 .. 2 ) {
    ( $ret, $msg ) = $ocf->MoveUp;
    ok( $ret, "bar 1 moved up" );
}

$ocf = RT::ObjectCustomField->new( RT->SystemUser );
$ocf->LoadByCols( CustomField => $foo_cf_1->id, ObjectId => $queue_foo->id );
my $foo_cf_sort_order = $ocf->SortOrder;

$ocf = RT::ObjectCustomField->new( RT->SystemUser );
$ocf->LoadByCols( CustomField => $global_cf_1->id, ObjectId => 0 );
my $global_cf_1_sort_order = $ocf->SortOrder;

TODO: {
    local $TODO = "Duplicated sort order";
    ok( $foo_cf_sort_order != $global_cf_1_sort_order, "foo 1's sort order should be different from global 1's" );
}

done_testing;
