no warnings qw/redefine/;

use RT::FM::CustomFieldCollection;


# {{{ Create

=item Create PARAMHASH

Create takes a hash of values and creates a row in the database:

  varchar(255) 'Name'.
  varchar(255) 'Description'.
  int(11) 'SortOrder'.

=begin testing

use_ok(RT::FM::Class);

my $root = RT::CurrentUser->new('root');
ok ($root->Id, "Loaded root");
my $cl = RT::FM::Class->new($root);
ok (UNIVERSAL::isa($cl, 'RT::FM::Class'), "the new class is a class");

my ($id, $msg) = $cl->Create(Name => 'Test', Description => 'A test class');

ok ($id, $msg);

# no duplicate class names should be allowed
($id, $msg) = $cl->Create(Name => 'Test', Description => 'A test class');

ok (!$id, $msg);

#class name should be required

($id, $msg) = $cl->Create(Name => '', Description => 'A test class');

ok (!$id, $msg);



$cl->Load('Test');
ok($cl->id, "Loaded the class we want");




=end testing


=cut


sub Create {
    my $self = shift;
    my %args = ( 
                Name => '',
                Description => '',
                SortOrder => '',

		  @_);
    $self->SUPER::Create(
                         Name => $args{'Name'},
                         Description => $args{'Description'},
                         SortOrder => $args{'SortOrder'},
);

}

sub ValidateName {
    my $self = shift;
    my $newval = shift;

    return undef unless ($newval);
    my $obj = RT::FM::Class->new($RT::SystemUser);
    $obj->Load($newval);
    return undef if ($obj->Id);
    return 1;     

}
# }}}

# {{{ CustomFields

=head2 CustomFields

Returns a CustomFieldCollection of all custom fields related to this article

=begin testing

my ($id,$msg);

my $class = RT::FM::Class->new($RT::SystemUser);
($id,$msg) = $class->Create(Name => 'CFTests');
ok($id, $msg);

ok($class->CustomFields->Count == 0, "The class has no custom fields");
my $cf1 = RT::FM::CustomField->new($RT::SystemUser);
($id, $msg) =$cf1->Create(Name => "ListTest1", Type => "SelectMultiple");
ok ($id, $msg);
ok($cf1->AddToClass($class->Id));
ok($class->CustomFields->Count == 1, "The class has 1 custom field");

my $cf2 = RT::FM::CustomField->new($RT::SystemUser);
($id, $msg) =$cf2->Create(Name => "ListTest2", Type => "SelectMultiple");
ok ($id, $msg);
ok($cf2->AddToClass(0));
ok($class->CustomFields->Count == 2, "The class has 1 custom field and one global custom field");

=end testing

=cut


sub CustomFields {
    my $self      = shift;
    my $cfs       = RT::FM::CustomFieldCollection->new( $self->CurrentUser );
    my $class_cfs = $cfs->NewAlias('FM_ClassCustomFields');
    $cfs->Join( ALIAS1 => 'main',
                FIELD1 => 'id',
                ALIAS2 => $class_cfs,
                FIELD2 => 'CustomField' );
    $cfs->Limit( ALIAS           => $class_cfs,
                 FIELD           => 'Class',
                 OPERATOR        => '=',
                 VALUE           => $self->Id,
                 ENTRYAGGREGATOR => 'OR' );
    $cfs->Limit( ALIAS           => $class_cfs,
                 FIELD           => 'Class',
                 OPERATOR        => '=',
                 VALUE           => "0",
                 ENTRYAGGREGATOR => 'OR' );
    return($cfs);                
}
# }}}

1;

