use strict;
use warnings;
use RT::Test nodb => 1, tests => undef;

my %format = %{ RT->Config->Get('LinksFormat') || {} };
ok( $format{'RT::Ticket'},  'LinksFormat has an RT::Ticket entry' );
ok( $format{'RT::Asset'},   'LinksFormat has an RT::Asset entry' );
ok( $format{'RT::Article'}, 'LinksFormat has an RT::Article entry' );
ok( $format{'RT::User'},    'LinksFormat has an RT::User entry' );
ok( $format{'RT::Group'},   'LinksFormat has an RT::Group entry' );
like( $format{'RT::Ticket'}, qr/Subject/, 'ticket format mentions Subject' );

like( $format{'RT::Group'}, qr/__Description__/, 'group format mentions Description' );
unlike( $format{'RT::Group'}, qr/>__id__</, 'group format has no standalone id column' );

unlike( $format{'RT::Asset'},   qr/__Catalog__/,   'asset format has no Catalog column' );
unlike( $format{'RT::Article'}, qr/__ClassName__/, 'article format has no Class column' );

ok( $format{'RT::Transaction'}, 'LinksFormat has an RT::Transaction entry' );
like( $format{'RT::Transaction'}, qr/Description/, 'transaction format mentions Description' );

{
    my %links = HTML::Mason::Commands::ProcessLinksForCreate(
        ARGSRef => { 'new-RefersTo' => '5 6', 'RefersTo-new' => '10' } );
    is_deeply( $links{RefersTo},     [ '5', '6' ], 'scalar new-RefersTo split on whitespace' );
    is_deeply( $links{ReferredToBy}, ['10'],       'scalar RefersTo-new' );
}

{
    my %links = HTML::Mason::Commands::ProcessLinksForCreate(
        ARGSRef => {
            'new-RefersTo'  => [ '5', 'asset:6' ],
            'new-DependsOn' => [ '',  '7' ],
        }
    );
    is_deeply( $links{RefersTo},  [ '5', 'asset:6' ], 'arrayref new-RefersTo flattened, prefixes kept' );
    is_deeply( $links{DependsOn}, ['7'],              'arrayref new-DependsOn drops empty values' );
}

{
    my %links = HTML::Mason::Commands::ProcessLinksForCreate( ARGSRef => { 'new-RefersTo' => [ '', '  ' ] } );
    ok( !exists $links{RefersTo}, 'all-empty arrayref produces no RefersTo key' );
}

done_testing;
