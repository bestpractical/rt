# BEGIN LICENSE BLOCK
# 
#  Copyright (c) 2002 Jesse Vincent <jesse@bestpractical.com>
#  
#  This program is free software; you can redistribute it and/or modify
#  it under the terms of version 2 of the GNU General Public License 
#  as published by the Free Software Foundation.
# 
#  A copy of that license should have arrived with this
#  software, but in any event can be snarfed from www.gnu.org.
# 
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
# 
# END LICENSE BLOCK

#$Header: /raid/cvsroot/fm/lib/RT/FM/SearchBuilder.pm,v 1.3 2001/09/09 07:19:58 jesse Exp $

=head1 NAME

  RT::FM::SearchBuilder - a baseclass for RT collection objects

=head1 SYNOPSIS

=head1 DESCRIPTION


=head1 METHODS

=cut

package RT::FM::SearchBuilder;
use DBIx::SearchBuilder;
@ISA= qw(DBIx::SearchBuilder);

# {{{ sub _Init 
sub _Init  {
    my $self = shift;
    
    $self->{'user'} = shift;
    unless(defined($self->CurrentUser)) {
	use Carp;
	Carp::confess("$self was created without a CurrentUser");
	return(0);
    }
    $self->SUPER::_Init( 'Handle' => $RT::FM::Handle);
}
# }}}

# {{{ sub LimitToEnabled

=head2 LimitToEnabled

Only find items that haven\'t been disabled

=cut

sub LimitToEnabled {
    my $self = shift;
    
    $self->Limit( FIELD => 'Disabled',
		  VALUE => '0',
		  OPERATOR => '=' );
}
# }}}

# {{{ sub LimitToDisabled

=head2 LimitToDeleted

Only find items that have been deleted.

=cut

sub LimitToDeleted {
    my $self = shift;
    
    $self->{'find_disabled_rows'} = 1;
    $self->Limit( FIELD => 'Disabled',
		  OPERATOR => '=',
		  VALUE => '1'
		);
}
# }}}

# {{{ sub HasEntry

=item HasEntry ID

If this Collection has an entry with the ID $id, returns that entry. Otherwise returns
undef

=cut

sub HasEntry {
    my $self = shift;
    my $id = shift;
   
    my @items = grep {$_->Id == $id } @{$self->ItemsArrayRef};
   
    if ($#items > 1) {
	die "$self HasEntry had a list with more than one of $item in it. this can never happen";
    }
    
    if ($#items == -1 ) {
	return undef;
    }
    else {
	return ($items[0]);
    }	

}


# {{{ sub CurrentUser 

=head2 CurrentUser

  Returns the current user as an RT::User object.

=cut

sub CurrentUser  {
  my $self = shift;
  return ($self->{'user'});
}
# }}}
    
# {{{ sub _Handle
sub _Handle  {
  my $self = shift;
  return($RT::FM::Handle);
}
# }}}
1;


