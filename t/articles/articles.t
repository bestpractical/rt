
use strict;
use warnings;

use RT::Test tests => 29;

use_ok 'RT::Articles';
use_ok 'RT::Classes';
use_ok 'RT::Class';

my $class = RT::Class->new($RT::SystemUser);
my ( $id, $msg ) = $class->Create( Name => 'CollectionTest-' . $$ );
ok( $id, $msg );

# Add a custom field to our class
use_ok('RT::CustomField');
my $cf = RT::CustomField->new($RT::SystemUser);
isa_ok($cf, 'RT::CustomField');

($id,$msg) = $cf->Create( Name => 'Articles::Sample-'.$$,
             Description => 'Test text cf',
             LookupType => RT::Article->CustomFieldLookupType,
             Type => 'Freeform'
             );



ok($id,$msg);


($id,$msg) = $cf->AddToObject($class);
ok ($id,$msg);



my $art = RT::Article->new($RT::SystemUser);
( $id, $msg ) = $art->Create(
    Class   => $class->id,
    Name    => 'Collection-1-' . $$,
    Summary => 'Coll-1-' . $$,
    'CustomField-'.$cf->Name => 'Test-'.$$
);

ok( $id, $msg );






my $arts = RT::Articles->new($RT::SystemUser);
$arts->LimitName( VALUE => 'Collection-1-' . $$ . 'fake' );
is( $arts->Count, 0,
    "Found no artlcles with names matching something that is not there" );

my $arts2 = RT::Articles->new($RT::SystemUser);
$arts2->LimitName( VALUE => 'Collection-1-' . $$ );
is( $arts2->Count, 1, 'Found one with names matching the word "test"' );

$arts = RT::Articles->new($RT::SystemUser);
$arts->LimitSummary( VALUE => 'Coll-1-' . $$ . 'fake' );
is( $arts->Count, 0,
    'Found no artlcles with summarys matching something that is not there' );

$arts2 = RT::Articles->new($RT::SystemUser);
$arts2->LimitSummary( VALUE => 'Coll-1-' . $$ );
is( $arts2->Count, 1, 'Found one with summarys matching the word "Coll-1"' );

my $new_art = RT::Article->new($RT::SystemUser);
( $id, $msg ) = $new_art->Create(
    Class          => $class->id,
    Name           => 'CFSearchTest1' . $$,
    'CustomField-'.$cf->Name  => 'testing' . $$
);

ok( $id, $msg . " Created a second testable article" );


$arts = RT::Articles->new($RT::SystemUser);
$arts->LimitCustomField( OPERATOR => 'LIKE', VALUE => "esting".$$ );
is( $arts->Count, 1, "Found 1 cf values matching 'esting" . $$ . "' for an unspecified field");

$arts = RT::Articles->new($RT::SystemUser);
$arts->LimitCustomField( OPERATOR => '=', VALUE => "esting".$$ );
is( $arts->Count, 0, "Found 0 cf values EXACTLY matching 'esting" . $$ . "' for an unspecified field");

$arts = RT::Articles->new($RT::SystemUser);
$arts->LimitCustomField( OPERATOR => '=', VALUE => "testing".$$ );
is( $arts->Count, 1, "Found 0 cf values EXACTLY matching 'testing" . $$ . "' for an unspecified field");


$arts = RT::Articles->new($RT::SystemUser);
$arts->LimitCustomField( OPERATOR => 'LIKE', VALUE => $$ );
is( $arts->Count, 2, "Found 1 cf values matching '" . $$ . "' for an unspecified field");


# Test searching on named custom fields
$arts = RT::Articles->new($RT::SystemUser);
$arts->LimitCustomField( OPERATOR => 'LIKE', VALUE => $$, FIELD => $cf->Name );
is( $arts->Count, 2, "Found 1 Article with cf values matching '".$$."' for CF named " .$cf->Name);

$arts = RT::Articles->new($RT::SystemUser);
$arts->LimitCustomField( OPERATOR => 'LIKE', VALUE => $$, FIELD => 'NO-SUCH-CF' );
is( $arts->Count,0, "Found no cf values matching '".$$."' for CF 'NO-SUCH-CF'  " );

$arts = RT::Articles->new($RT::SystemUser);
$arts->Limit(FIELD =>'Class', VALUE => $class->id);
        
$arts->LimitCustomField(
    OPERATOR => 'NOT LIKE',
    VALUE    => 'blah',
    FIELD    => $cf->id
);
is(
    $arts->Count ,2,
    "Found 1 articles with custom field values not matching blah");

$arts = RT::Articles->new($RT::SystemUser);
$arts->Limit(FIELD =>'Class', VALUE => $class->id);
$arts->LimitCustomField( OPERATOR => 'NOT LIKE', VALUE => 'est', FIELD => $cf->id );
is( $arts->Count , 0, "Found 0 cf values not matching 'est' for CF  ".$cf->id. " " . join(',', map {$_->id} @{$arts->ItemsArrayRef}));
$arts = RT::Articles->new($RT::SystemUser);
$arts->Limit(FIELD =>'Class', VALUE => $class->id);
$arts->LimitCustomField( OPERATOR => 'NOT LIKE', VALUE => 'BOGUS', FIELD => $cf->id );
is( $arts->Count , 2, "Found 2 articles not matching 'BOGUS' for CF  ".$cf->id);

my $ac = RT::Articles->new($RT::SystemUser);
ok( $ac->isa('RT::Articles') );
ok( $ac->isa('DBIx::SearchBuilder') );
ok( $ac->LimitRefersTo('http://dead.link') );
is( $ac->Count, 0 );

$ac = RT::Articles->new($RT::SystemUser);
ok( $ac->LimitReferredToBy('http://dead.link') );
is( $ac->Count, 0 );

