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

ok (require RT::Groups);

=end testing

=cut

no warnings qw(redefine);


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


=head2 LimitToSystemGroups

Return only System Groups 

=cut


sub LimitToSystemGroups {
    my $self = shift;
    $self->Limit(FIELD => 'Domain', OPERATOR => '=', VALUE => 'System');
    $self->Limit(FIELD => 'Instance', OPERATOR => '=', VALUE => '');
}

1;

