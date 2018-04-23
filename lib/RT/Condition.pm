# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2018 Best Practical Solutions, LLC
#                                          <sales@bestpractical.com>
#
# (Except where explicitly superseded by other copyright notices)
#
#
# LICENSE:
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
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA
# 02110-1301 or visit their web page on the internet at
# http://www.gnu.org/licenses/old-licenses/gpl-2.0.html.
#
#
# CONTRIBUTION SUBMISSION POLICY:
#
# (The following paragraph is not intended to limit the rights granted
# to you to modify and distribute this software under the terms of
# the GNU General Public License and is only of importance to you if
# you choose to contribute your changes and enhancements to the
# community by submitting them to Best Practical Solutions, LLC.)
#
# By intentionally submitting any modifications, corrections or
# derivatives to this work, or any other work intended for use with
# Request Tracker, to Best Practical Solutions, LLC, you confirm that
# you are the copyright holder for those contributions and you grant
# Best Practical Solutions,  LLC a nonexclusive, worldwide, irrevocable,
# royalty-free, perpetual, license to use, copy, create derivative
# works based on those contributions, and sublicense and distribute
# those contributions and any derivatives thereof.
#
# END BPS TAGGED BLOCK }}}

=head1 NAME

  RT::Condition - generic baseclass for scrip condition;

=head1 SYNOPSIS

    use RT::Condition;
    my $foo = RT::Condition->new( 
                TransactionObj => $tr, 
                TicketObj => $ti, 
                ScripObj => $scr, 
                Argument => $arg, 
                Type => $type);

    if ($foo->IsApplicable) {
           # do something
    }


=head1 DESCRIPTION


=head1 METHODS




=cut

package RT::Condition;

use strict;
use warnings;


use base qw/RT::Base/;

sub new  {
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my $self  = {};
  bless ($self, $class);
  $self->_Init(@_);
  return $self;
}

sub _Init  {
  my $self = shift;
  my %args = ( TransactionObj => undef,
               TicketObj => undef,
               ScripObj => undef,
               TemplateObj => undef,
               Argument => undef,
               ApplicableTransTypes => undef,
           CurrentUser => undef,
               @_ );

  $self->{'Argument'} = $args{'Argument'};
  $self->{'ScripObj'} = $args{'ScripObj'};
  $self->{'TicketObj'} = $args{'TicketObj'};
  $self->{'TransactionObj'} = $args{'TransactionObj'};
  $self->{'ApplicableTransTypes'} = $args{'ApplicableTransTypes'};
  $self->CurrentUser($args{'CurrentUser'});
}

# Access Scripwide data


=head2 Argument

Return the optional argument associated with this ScripCondition

=cut

sub Argument  {
  my $self = shift;
  return($self->{'Argument'});
}


=head2 TicketObj

Return the ticket object we're talking about

=cut

sub TicketObj  {
  my $self = shift;
  return($self->{'TicketObj'});
}


=head2 ScripObj

Return the Scrip object we're talking about

=cut

sub ScripObj  {
  my $self = shift;
  return($self->{'ScripObj'});
}

=head2 TransactionObj

Return the transaction object we're talking about

=cut

sub TransactionObj  {
  my $self = shift;
  return($self->{'TransactionObj'});
}


=head2 Type 



=cut

sub ApplicableTransTypes  {
  my $self = shift;
  return($self->{'ApplicableTransTypes'});
}


# Scrip methods


#What does this type of Action does

sub Describe  {
  my $self = shift;
  return ($self->loc("No description for [_1]", ref $self));
}


#Parse the templates, get things ready to go.

#If this rule applies to this transaction, return true.

sub IsApplicable  {
  my $self = shift;
  return(undef);
}

sub DESTROY {
    my $self = shift;

    # We need to clean up all the references that might maybe get
    # oddly circular
    $self->{'TemplateObj'} =undef
    $self->{'TicketObj'} = undef;
    $self->{'TransactionObj'} = undef;
    $self->{'ScripObj'} = undef;
     
}


RT::Base->_ImportOverlays();

1;
