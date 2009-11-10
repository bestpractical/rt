use strict;
use warnings;

use RT::Test strict => 1, tests => 7;
use_ok('RT::Model::Config');
my $config = RT::Model::Config->new;
isa_ok( $config, 'RT::Model::Config' );
can_ok( $config, 'get' );
can_ok( $config, 'set' );

is( $config->get('rtname'), 'example.com', 'default rtname is rt3' );

my ( $ret, $msg ) = $config->load_by_cols( name => 'devel_mode' );
ok( !$ret, "no devel_mode in rt's config" );

( $ret, $msg ) = $config->load_by_cols( name => 'database_type' );
ok( !$ret, "no database_type in rt's config" );

