no warnings qw/redefine/;


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

1;

