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

# {{{ LimiToSystemInternalGroups

=head2 LimitToSystemInternalGroups

Return only SystemInternal Groups, such as "privileged" "unprivileged" and "everyone" 

=cut


sub LimitToSystemInternalGroups {
    my $self = shift;
    $self->Limit(FIELD => 'Domain', OPERATOR => '=', VALUE => 'SystemInternal');
    $self->Limit(FIELD => 'Instance', OPERATOR => '=', VALUE => '');
}


# }}}

# {{{ LimiToUserDefinedGroups

=head2 LimitToUserDefined Groups

Return only UserDefined Groups

=cut


sub LimitToUserDefinedGroups {
    my $self = shift;
    $self->Limit(FIELD => 'Domain', OPERATOR => '=', VALUE => 'UserDefined');
    $self->Limit(FIELD => 'Instance', OPERATOR => '=', VALUE => '');
}


# }}}

# {{{ LimiToPersonalGroups

=head2 LimitToPersonalGroupsFor PRINCIPAL_ID

Return only Personal Groups for the user whose principal id 
is PRINCIPAL_ID

=cut


sub LimitToPersonalGroupsFor {
    my $self = shift;
    my $princ = shift;

    $self->Limit(FIELD => 'Domain', OPERATOR => '=', VALUE => 'Personal');
    $self->Limit(   FIELD => 'Instance',   
                    OPERATOR => '=', 
                    VALUE => $princ,
                    ENTRY_AGGREGATOR => 'OR');
}


# }}}

# {{{ LimitToRolesForQueue

=item LimitToRolesForQueue QUEUE_ID

Limits the set of groups found to role groups for queue QUEUE_ID

=cut

sub LimitToRolesForQueue {
    my $self = shift;
    my $queue = shift;
    $self->Limit(FIELD => 'Domain', OPERATOR => '=', VALUE => 'QueueRole');
    $self->Limit(FIELD => 'Instance', OPERATOR => '=', VALUE => $queue);
}

# }}}

# {{{ LimitToRolesForTicket

=item LimitToRolesForTicket Ticket_ID

Limits the set of groups found to role groups for Ticket Ticket_ID

=cut

sub LimitToRolesForTicket {
    my $self = shift;
    my $Ticket = shift;
    $self->Limit(FIELD => 'Domain', OPERATOR => '=', VALUE => 'TicketRole');
    $self->Limit(FIELD => 'Instance', OPERATOR => '=', VALUE => '$Ticket');
}

# }}}

# {{{ LimitToRolesForSystem

=item LimitToRolesForSystem System_ID

Limits the set of groups found to role groups for System System_ID

=cut

sub LimitToRolesForSystem {
    my $self = shift;
    $self->Limit(FIELD => 'Domain', OPERATOR => '=', VALUE => 'SystemRole');
}

# }}}
1;

