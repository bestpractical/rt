# BEGIN LICENSE BLOCK
# 
# Copyright (c) 1996-2003 Jesse Vincent <jesse@bestpractical.com>
# 
# (Except where explictly superceded by other copyright notices)
# 
# This work is made available to you under the terms of Version 2 of
# the GNU General Public License. A copy of that license should have
# been provided with this software, but in any event can be snarfed
# from www.gnu.org.
# 
# This work is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
# 
# Unless otherwise specified, all modifications, corrections or
# extensions to this work which alter its source code become the
# property of Best Practical Solutions, LLC when submitted for
# inclusion in the work.
# 
# 
# END LICENSE BLOCK
=head1 NAME

  RT::Search::Generic - ;

=head1 SYNOPSIS

    use RT::Search::Generic;
    my $tickets = RT::Tickets->new($CurrentUser);
    my $foo = RT::Search::Generic->new(Argument => $arg,
                                       TicketsObj => $tickets);
    $foo->Prepare();
    while ( my $ticket = $foo->Next ) {
        # Do something with each ticket we've found
    }


=head1 DESCRIPTION


=head1 METHODS


=begin testing

ok (require RT::Search::Generic);

=end testing


=cut

package RT::Search::Generic;

use strict;

# {{{ sub new 
sub new  {
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my $self  = {};
  bless ($self, $class);
  $self->_Init(@_);
  return $self;
}
# }}}

# {{{ sub _Init 
sub _Init  {
  my $self = shift;
  my %args = ( 
           TicketsObj => undef,
	       Argument => undef,
	       @_ );
  
  $self->{'TicketsObj'} = $args{'TicketsObj'}; 
  $self->{'Argument'} = $args{'Argument'};
}
# }}}

# {{{ sub Argument 

=head2 Argument

Return the optional argument associated with this Search

=cut

sub Argument  {
  my $self = shift;
  return($self->{'Argument'});
}
# }}}


=head2 TicketsObj 

Return the Tickets object passed into this search

=cut

sub TicketsObj {
    my $self = shift;
    return($self->{'TicketsObj'});
}

# {{{ sub Describe 
sub Describe  {
  my $self = shift;
  return ($self->loc("No description for [_1]", ref $self));
}
# }}}

# {{{ sub Prepare
sub Prepare  {
  my $self = shift;
  return(1);
}
# }}}

eval "require RT::Search::Generic_Vendor";
die $@ if ($@ && $@ !~ qr{^Can't locate RT/Search/Generic_Vendor.pm});
eval "require RT::Search::Generic_Local";
die $@ if ($@ && $@ !~ qr{^Can't locate RT/Search/Generic_Local.pm});

1;
