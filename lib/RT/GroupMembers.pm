#$Header$

=head1 NAME

  RT::GroupMembers - a collection of RT::GroupMember objects

=head1 SYNOPSIS

  use RT::GroupMembers;

=head1 DESCRIPTION


=head1 METHODS

=cut

package RT::GroupMembers;
use RT::EasySearch;

@ISA= qw(RT::EasySearch);


# {{{ sub _Init  
sub _Init   {
  my $self = shift;
 
  $self->{'table'} = "GroupMembers";
  $self->{'primary_key'} = "id";
  return ( $self->SUPER::_Init(@_) );
}
# }}}

# {{{ sub Limit 
sub Limit  {
  my $self = shift;
my %args = ( ENTRYAGGREGATOR => 'AND',
             @_);

  $self->SUPER::Limit(%args);
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
  my $Handle = shift;
  my $item;

  use RT::GroupMember;
  $item = new RT::GroupMember($self->CurrentUser);
  return($item);
}
# }}}
1;
