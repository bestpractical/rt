use strict;
use warnings;

use RT::Test tests => 18;

my $suffix = '-'. $$;

use_ok 'RT::Users';
use_ok 'RT::CustomField';

my $u1 = RT::User->new( RT->SystemUser );
isa_ok( $u1, 'RT::User' );
ok( $u1->Load('root'), "Loaded user 'root'" );

# create cf
my $cfname = 'TestUserCF'. $suffix;
my $cf = RT::CustomField->new( RT->SystemUser );
isa_ok( $cf, 'RT::CustomField' );

{
    my ($id, $msg) = $cf->Create(
       Name => $cfname,
       LookupType => 'RT::User',
       Type => 'Freeform',
       Description => 'Freeform CF for tests',
    );
    ok( $id, "Created cf '$cfname' - " . $msg );
}

{
  my ($status, $msg) = $cf->AddToObject( $u1 );
  ok( $status, "Added CF to user object - " . $msg);
}

my $cfvalue1 = 'Foo';

{
  my ($id, $msg) = $u1->AddCustomFieldValue(
                          Field => $cfname,
                          Value => $cfvalue1,
                          RecordTransaction => 0 );
  ok( $id, "Adding CF value '$cfvalue1' - " . $msg );
}

# Confirm value is returned.
{
  my $cf_value_ref = QueryCFValue( $cfvalue1, $cf->id );
  is( scalar(@$cf_value_ref), 1, 'Got one value.' );
  is( $cf_value_ref->[0], 'Foo', 'Got Foo back for value.' );
}

{
  my ($id, $msg) = $u1->DeleteCustomFieldValue(
                            Field => $cfname,
                            Value => $cfvalue1,
                            RecordTransaction => 0 );
  ok( $id, "Deleting CF value - " . $msg );
}

my $cfvalue2 = 'Bar';
{
  my ($id, $msg) = $u1->AddCustomFieldValue(
                          Field => $cfname,
                          Value => $cfvalue2,
                          RecordTransaction => 0 );
  ok( $id, "Adding second CF value '$cfvalue2' - " . $msg );
}

# Confirm no value is returned for Foo.
{
  # Calling with $cfvalue1 on purpose to confirm
  # it has been disabled by the delete above.

  my $cf_value_ref = QueryCFValue( $cfvalue1, $cf->id );
  is( scalar(@$cf_value_ref), 0, 'No values returned for Foo.' );
}

# Confirm value is returned for Bar.
{
  my $cf_value_ref = QueryCFValue( $cfvalue2, $cf->id );
  is( scalar(@$cf_value_ref), 1, 'Got one value.' );
  is( $cf_value_ref->[0], 'Bar', 'Got Bar back for value.' );
}


sub QueryCFValue{
  my $cf_value = shift;
  my $cf_id = shift;
  my @cf_value_strs;

  my $users = RT::Users->new(RT->SystemUser);
  isa_ok( $users, 'RT::Users' );

  $users->LimitCustomField(
      CUSTOMFIELD => $cf_id,
      OPERATOR => "=",
      VALUE => $cf_value );

  while ( my $filtered_user = $users->Next() ){
    my $cf_values = $filtered_user->CustomFieldValues($cf->id);
    while (my $cf_value = $cf_values->Next() ){
      push @cf_value_strs, $cf_value->Content;
    }
  }
  return \@cf_value_strs;
}
