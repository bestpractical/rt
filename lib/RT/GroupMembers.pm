#$Header$

=head1 NAME

  RT::GroupMembers - a collection of RT::GroupMember objects

=head1 SYNOPSIS

  use RT::GroupMembers;

=head1 DESCRIPTION


=head1 METHODS


=begin testing

ok (require RT::TestHarness);
ok (require RT::GroupMembers);

=end testing

=cut

package RT::GroupMembers;
use RT::EasySearch;
use RT::GroupMember;

@ISA= qw(RT::EasySearch);


# {{{ sub _Init  
sub _Init   {
  my $self = shift;
 
  $self->{'table'} = "GroupMembers";
  $self->{'primary_key'} = "id";
  return ( $self->SUPER::_Init(@_) );
}
# }}}

# {{{ sub LimitToGroup

=head2 LimitToGroup

Takes a group id as its only argument.  Limits the current search to that
group object

=cut

sub LimitToGroup {
    my $self = shift;
    my $group = shift;

    return ($self->Limit( 
                         VALUE => "$group",
                         FIELD => 'GroupId',
                         ENTRYAGGREGATOR => 'OR',
                         ));

}
# }}}

# {{{ sub NewItem 

sub NewItem  {
    my $self = shift;
    return(RT::GroupMember->new($self->CurrentUser))
}

# }}}
1;
