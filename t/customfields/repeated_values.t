use warnings;
use strict;

use RT::Test tests => undef;


my $ticket = RT::Test->create_ticket( Subject => 'test repeated values', Queue => 'General' );
my ( $ret, $msg );

{
    diag "testing freeform single cf";
    my $freeform_single = RT::Test->load_or_create_custom_field(
        Name  => 'freeform single',
        Type  => 'FreeformSingle',
        Queue => 0,
    );

    ( $ret, $msg ) =
      $ticket->AddCustomFieldValue( Field => $freeform_single, Value => 'foo' );
    ok( $ret, $msg );
    is( $ticket->FirstCustomFieldValue($freeform_single), 'foo', 'value is foo' );

    my $ocfv = $ticket->CustomFieldValues($freeform_single)->First;
    ( $ret, $msg ) =
      $ticket->AddCustomFieldValue( Field => $freeform_single, Value => 'foo' );
    is( $ret, $ocfv->id, "got the same previous object" );
    is( $ticket->FirstCustomFieldValue($freeform_single), 'foo', 'value is still foo' );

    ( $ret, $msg ) =
      $ticket->AddCustomFieldValue( Field => $freeform_single, Value => 'FOO' );
    ok( $ret, $msg );
    isnt( $ret, $ocfv->id, "got a new value" );
    is( $ticket->FirstCustomFieldValue($freeform_single), 'FOO', 'value is FOO' );
}

{
    diag "testing freeform multiple cf";
    my $freeform_multiple = RT::Test->load_or_create_custom_field(
        Name  => 'freeform multiple',
        Type  => 'FreeformMultiple',
        Queue => 0,
    );

    ($ret, $msg) = $ticket->AddCustomFieldValue( Field => $freeform_multiple, Value => 'foo' );
    ok($ret, $msg);
    is( $ticket->FirstCustomFieldValue($freeform_multiple), 'foo', 'value is foo' );

    my $ocfv = $ticket->CustomFieldValues($freeform_multiple)->First;
    ($ret, $msg) = $ticket->AddCustomFieldValue( Field => $freeform_multiple, Value => 'foo' );
    is($ret, $ocfv->id, "got the same previous object");
    is( $ticket->FirstCustomFieldValue($freeform_multiple), 'foo', 'value is still foo' );

    ($ret, $msg) = $ticket->AddCustomFieldValue( Field => $freeform_multiple, Value => 'bar' );
    ok($ret, $msg);

    my $ocfvs = $ticket->CustomFieldValues($freeform_multiple)->ItemsArrayRef;
    is( scalar @$ocfvs, 2, 'has 2 values');
    is( $ocfvs->[0]->Content, 'foo', 'first is foo' );
    is( $ocfvs->[1]->Content, 'bar', 'sencond is bar' );
}

{
    diag "testing select single cf";

    my $select_single = RT::Test->load_or_create_custom_field(
        Name  => 'select single',
        Type  => 'SelectSingle',
        Queue => 0,
    );

    for my $value ( qw/foo bar baz/ ) {
        $select_single->AddValue( Name => $value );
    }

    ( $ret, $msg ) =
      $ticket->AddCustomFieldValue( Field => $select_single, Value => 'foo' );
    ok( $ret, $msg );
    my $ocfv = $ticket->CustomFieldValues($select_single)->First;
    is( $ticket->FirstCustomFieldValue($select_single), 'foo', 'value is foo' );
    ( $ret, $msg ) =
      $ticket->AddCustomFieldValue( Field => $select_single, Value => 'foo' );
    is( $ret, $ocfv->id, "got the same previous object" );
    is( $ticket->FirstCustomFieldValue($select_single), 'foo', 'value is still foo' );

    diag "select values are case insensitive";

    ( $ret, $msg ) =
      $ticket->AddCustomFieldValue( Field => $select_single, Value => 'FOO' );
    is( $ret, $ocfv->id, "got the same previous object" );
    is( $ticket->FirstCustomFieldValue($select_single), 'foo', 'value is still foo' );

    ($ret, $msg) = $ticket->AddCustomFieldValue( Field => $select_single, Value => 'bar' );
    ok($ret, $msg);
    isnt( $ret, $ocfv->id, "got a new value" );
    is( $ticket->FirstCustomFieldValue($select_single), 'bar', 'new value is bar' );
}

{
    diag "testing binary single cf";

    my $binary_single = RT::Test->load_or_create_custom_field(
        Name  => 'upload single',
        Type  => 'BinarySingle',
        Queue => 0,
    );

    ( $ret, $msg ) =
      $ticket->AddCustomFieldValue( Field => $binary_single, Value => 'foo', LargeContent => 'bar' );
    ok( $ret, $msg );
    my $ocfv = $ticket->CustomFieldValues($binary_single)->First;
    ( $ret, $msg ) =
      $ticket->AddCustomFieldValue( Field => $binary_single, Value => 'foo', LargeContent => 'bar' );
    is( $ret, $ocfv->id, "got the same previous object" );
    is($ocfv->Content, 'foo', 'name is foo');
    is($ocfv->LargeContent, 'bar', 'content is bar');

    ( $ret, $msg ) =
      $ticket->AddCustomFieldValue( Field => $binary_single, Value => 'foo', LargeContent => 'baz' );
    ok( $ret, $msg );
    isnt( $ret, $ocfv->id, "got a new value" );
    $ocfv = $ticket->CustomFieldValues($binary_single)->First;
    is($ocfv->Content, 'foo', 'name is foo');
    is($ocfv->LargeContent, 'baz', 'content is baz');

    ( $ret, $msg ) =
      $ticket->AddCustomFieldValue( Field => $binary_single, Value => 'foo.2', LargeContent => 'baz' );
    ok( $ret, $msg );
    isnt( $ret, $ocfv->id, "got a new value" );
    $ocfv = $ticket->CustomFieldValues($binary_single)->First;
    is($ocfv->Content, 'foo.2', 'name is foo.2');
    is($ocfv->LargeContent, 'baz', 'content is baz');
}

done_testing();
