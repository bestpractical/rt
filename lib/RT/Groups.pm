#$Header: /raid/cvsroot/rt/lib/RT/Groups.pm,v 1.2 2001/11/06 23:04:14 jesse Exp $

=head1 NAME

  RT::Groups - a collection of RT::Group objects

=head1 SYNOPSIS

  use RT::Groups;
  my $groups = $RT::Groups->new($CurrentUser);
  $groups->LimitToReal();
  while (my $group = $groups->Next()) {
     print $group->Id ." is a group id\n";
  }

=head1 DESCRIPTION


=head1 METHODS


=begin testing

ok (require RT::TestHarness);
ok (require RT::Groups);

=end testing

=cut

package RT::Groups;
use RT::EasySearch;
use RT::Groups;

@ISA= qw(RT::EasySearch);

# {{{ sub _Init

sub _Init { 
  my $self = shift;
  $self->{'table'} = "Groups";
  $self->{'primary_key'} = "id";

  $self->OrderBy( ALIAS => 'main',
		  FIELD => 'Name',
		  ORDER => 'ASC');


  return ( $self->SUPER::_Init(@_));
}
# }}}

# {{{ LimitToReal

=head2 LimitToReal

Make this groups object return only "real" groups, which can be
granted rights and have members assigned to them

=cut

sub LimitToReal {
    my $self = shift;

    return ($self->Limit( FIELD => 'Pseudo',
			  VALUE => '0',
			  OPERATOR => '='));

}
# }}}

# {{{ sub LimitToPseudo

=head2 LimitToPseudo

Make this groups object return only "pseudo" groups, which can be
granted rights but whose membership lists are determined dynamically.

=cut
  
  sub LimitToPseudo {
    my $self = shift;

    return ($self->Limit( FIELD => 'Pseudo',
			  VALUE => '1',
			  OPERATOR => '='));

}
# }}}

# {{{ sub NewItem 
sub NewItem  {
  my $self = shift;
  return (RT::Group->new($self->CurrentUser));
}
# }}}


1;

