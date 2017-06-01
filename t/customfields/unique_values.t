use warnings;
use strict;

use RT::Test tests => undef;

{
    diag "testing freeform single cf";
    my $unique_single = RT::Test->load_or_create_custom_field(
        Name         => 'unique single',
        Type         => 'FreeformSingle',
        Queue        => 0,
        UniqueValues => 1,
    );
    ok($unique_single->UniqueValues, 'unique values for this CF');

    my @tests = (
        ['foo', 'bar'], # Content
        [('foo' x 256), ('bar' x 256)], # LargeContent
    );

    for (@tests) {
        my ($foo, $bar) = @$_;
        my $alpha = RT::Test->create_ticket( Subject => 'test unique values alpha', Queue => 'General' );
        my $beta = RT::Test->create_ticket( Subject => 'test unique values beta', Queue => 'General' );

        my ( $ret, $msg ) =
          $alpha->AddCustomFieldValue( Field => $unique_single, Value => $foo );
        ok( $ret, $msg );
        is( $alpha->FirstCustomFieldValue($unique_single), $foo, 'value is foo' );

        ( $ret, $msg ) =
          $beta->AddCustomFieldValue( Field => $unique_single, Value => $foo );
        ok( !$ret, "can't reuse the OCFV 'foo'");
        like($msg, qr/That is not a unique value/);
        is( $beta->FirstCustomFieldValue($unique_single), undef, 'no value since it was a duplicate' );

        ( $ret, $msg ) =
          $alpha->AddCustomFieldValue( Field => $unique_single, Value => $bar );
        ok( $ret, $msg );

        is( $alpha->FirstCustomFieldValue($unique_single), $bar, 'value is now bar' );

        ( $ret, $msg ) =
          $beta->AddCustomFieldValue( Field => $unique_single, Value => $foo );
        ok( $ret, "can reuse foo since alpha switched away");
        is( $beta->FirstCustomFieldValue($unique_single), $foo, 'now beta has foo' );

        ( $ret, $msg ) =
          $alpha->AddCustomFieldValue( Field => $unique_single, Value => $foo );
        ok( !$ret, "alpha can't switch back to foo since beta uses it");

        is( $alpha->FirstCustomFieldValue($unique_single), $bar, 'value is still bar' );
    }
}

done_testing;

