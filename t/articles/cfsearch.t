
use strict;
use warnings;

use RT::Test tests => 11;

my $suffix = '-'. $$;

use_ok 'RT::Class';
use_ok 'RT::Article';
use_ok 'RT::CustomField';

my $classname = 'TestClass';
my $class = RT::Class->new( $RT::SystemUser );
{
    $class->Load( $classname );
    unless ( $class->Id ) {
        my ($id, $msg) = $class->Create(
            Name => $classname,
            Description => 'class for cf tests',
        );
        ok $id, "created class '$classname' #$id"
            or diag "error: $msg";
    } else {
        ok 1, "class '$classname' exists";
    }
}

# create cf
my $cfname = 'TestCF'. $suffix;
my $cf = RT::CustomField->new( $RT::SystemUser );
{
    my ($id, $msg) = $cf->Create(
        Name => $cfname,
        LookupType => 'RT::Class-RT::Article',
        Type => 'Select', MaxValues => 1,
        Description => 'singleselect cf for tests',
    );
    ok $id, "created cf '$cfname' #$id"
        or diag "error: $msg";
}

# attach cf to class
{
    my ($status, $msg) = $cf->AddToObject( $class );
    ok $status, "attached the cf to the class"
        or diag "error: $msg";
}
  
# create two cf-values
{
    my ($status, $msg) = $cf->AddValue( Name => 'Value1' );
    ok $status, "added a value to the cf" or diag "error: $msg";

    ($status, $msg) = $cf->AddValue( Name => 'Value2' );
    ok $status, "added a value to the cf" or diag "error: $msg";
}

my $article1name = 'TestArticle1'.$suffix;
my $article1 = RT::Article->new($RT::SystemUser);
$article1->Create( Name => $article1name, Summary => 'Test', Class => $class->Id);
$article1->AddCustomFieldValue(Field => $cf->Id, Value => 'Value1');

my $article2name = 'TestArticle2'.$suffix;
my $article2 = RT::Article->new($RT::SystemUser);
$article2->Create( Name => $article2name, Summary => 'Test', Class => $class->Id);
$article2->AddCustomFieldValue(Field => $cf->Id, Value => 'Value2');

# search for articles containing 1st value
{
    my $articles = RT::Articles->new( $RT::SystemUser );
    $articles->UnLimit;
    $articles->Limit( FIELD => "Class", SUBCLAUSE => 'ClassMatch', VALUE => $class->Id);
    $articles->LimitCustomField( FIELD => $cf->Id, VALUE => 'Value1' );
    is $articles->Count, 1, 'found correct number of articles';
}

{
    my $articles = RT::Articles->new($RT::SystemUser);
    $articles->UnLimit;
    $articles->Limit( FIELD => "Class", SUBCLAUSE => 'ClassMatch', VALUE => $class->Id);
    $articles->LimitCustomField( FIELD => $cf, VALUE => 'Value1' );    
    is $articles->Count, 1, 'found correct number of articles';
}

{
    my $articles = RT::Articles->new($RT::SystemUser);
    $articles->UnLimit( );
    $articles->Limit( FIELD => "Class", SUBCLAUSE => 'ClassMatch', VALUE => $class->Id);
    $articles->LimitCustomField( FIELD => $cf->Name, VALUE => 'Value1' );
    is $articles->Count, 1, 'found correct number of articles';
}

