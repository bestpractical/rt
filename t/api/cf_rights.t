use warnings;
use strict;

use RT;
use RT::Test tests => 12;

my $q = RT::Queue->new($RT::SystemUser);
my ($id,$msg) =$q->Create(Name => "CF-Rights-".$$);
ok($id,$msg);

my $cf = RT::CustomField->new($RT::SystemUser);
($id,$msg) = $cf->Create(Name => 'CF-'.$$, Type => 'Select', MaxValues => '1', Queue => $q->id);
ok($id,$msg);


($id,$msg) =$cf->AddValue(Name => 'First');
ok($id,$msg);

my $u = RT::User->new($RT::SystemUser);
($id,$msg) = $u->Create( Name => 'User1', Privileged => 1 );
ok ($id,$msg);

($id,$msg) = $u->PrincipalObj->GrantRight( Object => $cf, Right => 'SeeCustomField' );
ok ($id,$msg);

my $ucf = RT::CustomField->new($u);
($id,$msg) = $ucf->Load( $cf->Id );
ok ($id,$msg);

my $cfv = $ucf->Values->First;

($id,$msg) = $cfv->SetName( 'First1' );
ok (!$id,$msg);

($id,$msg) = $u->PrincipalObj->GrantRight( Object => $cf, Right => 'AdminCustomFieldValues' );
ok ($id,$msg);

($id,$msg) = $cfv->SetName( 'First2' );
ok ($id,$msg);

($id,$msg) = $u->PrincipalObj->RevokeRight( Object => $cf, Right => 'AdminCustomFieldValues' );
ok ($id,$msg);

($id,$msg) = $u->PrincipalObj->GrantRight( Object => $cf, Right => 'AdminCustomField' );
ok ($id,$msg);

($id,$msg) = $cfv->SetName( 'First3' );
ok ($id,$msg);

1;
