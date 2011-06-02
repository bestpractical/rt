use strict;
use warnings;

use RT::Test tests => 13;

my $cf = RT::CustomField->new($RT::SystemUser);
my ( $id, $ret, $msg );

diag "single select";
( $id, $msg ) = $cf->Create(
    Name      => 'single_select',
    Type      => 'Select',
    MaxValues => '1',
    Queue     => 0,
);
ok( $id, $msg );

is( $cf->RenderType, 'Select box', 'default render type is Select box' );
( $ret, $msg ) = $cf->SetRenderType('Dropdown');
ok( $ret, 'changed to Dropdown' );
is( $cf->RenderType, 'Dropdown', 'render type is indeed updated' );

( $ret, $msg ) = $cf->SetRenderType('List');
ok( $ret, 'changed to List' );
is( $cf->RenderType, 'List', 'render type is indeed updated' );

( $ret, $msg ) = $cf->SetRenderType('fakeone');
ok( !$ret, 'failed to set an invalid render type' );
is( $cf->RenderType, 'List', 'render type is still List' );

diag "multiple select";
( $id, $msg ) = $cf->Create(
    Name       => 'multiple_select',
    Type       => 'Select',
    MaxValues  => '0',
    Queue      => 0,
    RenderType => 'List',
);

is( $cf->RenderType, 'List', 'set render type to List' );
( $ret, $msg ) = $cf->SetRenderType('Dropdown');
ok( !$ret, 'Dropdown is invalid for multiple select' );

is( $cf->RenderType, 'List', 'render type is still List' );

( $ret, $msg ) = $cf->SetRenderType('Select box');
ok( $ret, 'changed to Select box' );
is( $cf->RenderType, 'Select box', 'render type is indeed updated' );

