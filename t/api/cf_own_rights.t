use warnings;
use strict;

use RT::Test tests => undef;

# Create a user custom field
my $cf = RT::CustomField->new( RT->SystemUser );
my ( $id, $msg ) = $cf->Create(
    Name       => 'UserPhone-' . $$,
    Type       => 'FreeformSingle',
    LookupType => RT::User->CustomFieldLookupType,
);
ok( $id, "Created user CF: $msg" );

my $user_a = RT::Test->load_or_create_user( Name => 'UserA-' . $$ );
ok( $user_a->id, "Created user A" );

my $user_b = RT::Test->load_or_create_user( Name => 'UserB-' . $$ );
ok( $user_b->id, "Created user B" );

# Pre-populate user A's CF value as system user
my $system_cf = RT::CustomField->new( RT->SystemUser );
$system_cf->Load( $cf->id );
( $id, $msg ) = $system_cf->AddValueForObject( Object => $user_a, Content => 'A-value' );
ok( $id, "Set CF value for user A" . ( $msg ? ": $msg" : '' ) );

( $id, $msg ) = $system_cf->AddValueForObject( Object => $user_b, Content => 'B-value' );
ok( $id, "Set CF value for user B" . ( $msg ? ": $msg" : '' ) );

RT::Test->add_rights(
    {   Principal => $user_a,
        Object    => RT->System,
        Right     => [ 'SeeOwnCustomField', 'ModifyOwnCustomField' ],
    },
);

subtest 'SeeOwnCustomField - can see own CF value' => sub {
    my $cf_a = RT::CustomField->new($user_a);
    $cf_a->Load( $cf->id );
    $cf_a->SetContextObject($user_a);

    ok( $cf_a->CurrentUserCanSee, "User A can see CF when context is self" );

    my $values = $cf_a->ValuesForObject($user_a);
    my $val    = $values->First;
    ok( $val && $val->id, "User A can retrieve CF value object for self" );
    is( $val->Content, 'A-value', "User A sees correct CF value for self" );
};

subtest "SeeOwnCustomField - cannot see other user's CF value" => sub {
    my $cf_a = RT::CustomField->new($user_a);
    $cf_a->Load( $cf->id );
    $cf_a->SetContextObject($user_b);

    ok( !$cf_a->CurrentUserCanSee, "User A cannot see CF when context is user B" );
};

subtest 'SeeOwnCustomField - ObjectCustomFieldValue respects right' => sub {

    # Load the OCFV directly as user A for their own record
    my $ocfv  = RT::ObjectCustomFieldValue->new($user_a);
    my $ocfvs = RT::ObjectCustomFieldValues->new( RT->SystemUser );
    $ocfvs->LimitToCustomField( $cf->id );
    $ocfvs->Limit( FIELD => 'ObjectType', VALUE => 'RT::User' );
    $ocfvs->Limit( FIELD => 'ObjectId',   VALUE => $user_a->id );
    $ocfvs->Limit( FIELD => 'Disabled',   VALUE => 0 );
    my $sys_val = $ocfvs->First;
    ok( $sys_val && $sys_val->id, "Found OCFV for user A" );

    # Load same OCFV as user A
    $ocfv->Load( $sys_val->id );
    ok( $ocfv->CurrentUserCanSee, "User A can see their own OCFV" );
    is( $ocfv->Content, 'A-value', "User A reads correct content from OCFV" );

    # Load user B's OCFV as user A
    my $ocfvs_b = RT::ObjectCustomFieldValues->new( RT->SystemUser );
    $ocfvs_b->LimitToCustomField( $cf->id );
    $ocfvs_b->Limit( FIELD => 'ObjectType', VALUE => 'RT::User' );
    $ocfvs_b->Limit( FIELD => 'ObjectId',   VALUE => $user_b->id );
    $ocfvs_b->Limit( FIELD => 'Disabled',   VALUE => 0 );
    my $sys_val_b = $ocfvs_b->First;
    ok( $sys_val_b && $sys_val_b->id, "Found OCFV for user B" );

    my $ocfv_b = RT::ObjectCustomFieldValue->new($user_a);
    $ocfv_b->Load( $sys_val_b->id );
    ok( !$ocfv_b->CurrentUserCanSee, "User A cannot see user B's OCFV" );
    is( $ocfv_b->Content, undef, "User A gets undef content for user B's OCFV" );
};

subtest 'ModifyOwnCustomField - can modify own CF value' => sub {
    my $cf_a = RT::CustomField->new($user_a);
    $cf_a->Load( $cf->id );
    $cf_a->SetContextObject($user_a);

    ( $id, $msg ) = $cf_a->AddValueForObject( Object => $user_a, Content => 'A-value-updated' );
    ok( $id, "User A can add/update CF value for self" . ( $msg ? ": $msg" : '' ) );

    # FreeformSingle replaces old value, so delete the new value
    ( $id, $msg ) = $cf_a->DeleteValueForObject( Object => $user_a, Content => 'A-value-updated' );
    ok( $id, "User A can delete CF value for self: $msg" );
};

subtest "ModifyOwnCustomField - cannot modify other user's CF value" => sub {
    my $cf_a = RT::CustomField->new($user_a);
    $cf_a->Load( $cf->id );
    $cf_a->SetContextObject($user_b);

    ( $id, $msg ) = $cf_a->AddValueForObject( Object => $user_b, Content => 'hacked' );
    ok( !$id, "User A cannot add CF value for user B: $msg" );

    ( $id, $msg ) = $cf_a->DeleteValueForObject( Object => $user_b, Content => 'B-value' );
    ok( !$id, "User A cannot delete CF value for user B: $msg" );
};

subtest 'No rights - cannot see own CF' => sub {
    my $cf_b = RT::CustomField->new($user_b);
    $cf_b->Load( $cf->id );
    $cf_b->SetContextObject($user_b);

    ok( !$cf_b->CurrentUserCanSee, "User B without rights cannot see own CF" );
};

subtest 'No rights - cannot see own OCFV' => sub {
    my $ocfvs = RT::ObjectCustomFieldValues->new( RT->SystemUser );
    $ocfvs->LimitToCustomField( $cf->id );
    $ocfvs->Limit( FIELD => 'ObjectType', VALUE => 'RT::User' );
    $ocfvs->Limit( FIELD => 'ObjectId',   VALUE => $user_b->id );
    $ocfvs->Limit( FIELD => 'Disabled',   VALUE => 0 );
    my $sys_val = $ocfvs->First;
    ok( $sys_val && $sys_val->id, "Found OCFV for user B" );

    my $ocfv = RT::ObjectCustomFieldValue->new($user_b);
    $ocfv->Load( $sys_val->id );
    ok( !$ocfv->CurrentUserCanSee, "User B without rights cannot see own OCFV" );
    is( $ocfv->Content, undef, "User B gets undef content for own OCFV" );
};

subtest 'No rights - cannot modify own CF' => sub {
    my $cf_b = RT::CustomField->new($user_b);
    $cf_b->Load( $cf->id );
    $cf_b->SetContextObject($user_b);

    ( $id, $msg ) = $cf_b->AddValueForObject( Object => $user_b, Content => 'B-new' );
    ok( !$id, "User B without rights cannot add own CF value: $msg" );

    ( $id, $msg ) = $cf_b->DeleteValueForObject( Object => $user_b, Content => 'B-value' );
    ok( !$id, "User B without rights cannot delete own CF value: $msg" );
};

done_testing;
