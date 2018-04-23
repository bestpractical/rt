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

  RT::Queues - a collection of RT::Queue objects

=head1 SYNOPSIS

  use RT::Queues;

=head1 DESCRIPTION


=head1 METHODS



=cut


package RT::Queues;

use strict;
use warnings;

use base 'RT::SearchBuilder';

use RT::Queue;

sub Table { 'Queues'}

# {{{ sub _Init
sub _Init { 
  my $self = shift;
  $self->{'with_disabled_column'} = 1;

  # By default, order by SortOrder, then Name
  $self->OrderByCols(
      {
          ALIAS => 'main',
          FIELD => 'SortOrder',
          ORDER => 'ASC',
      },
      {
          ALIAS => 'main',
          FIELD => 'Name',
          ORDER => 'ASC',
      }
  );

  return ($self->SUPER::_Init(@_));
}

sub Limit  {
  my $self = shift;
  my %args = ( ENTRYAGGREGATOR => 'AND',
               @_);
  $self->SUPER::Limit(%args);
}


=head2 AddRecord

Adds a record object to this collection if this user can see.
This is used for filtering objects for both Next and ItemsArrayRef.

=cut

sub AddRecord {
    my $self = shift;
    my $Queue = shift;
    return unless $Queue->CurrentUserHasRight('SeeQueue');

    push @{$self->{'items'}}, $Queue;
    $self->{'rows'}++;
}

# no need to order here, it's already ordered in _Init
sub ItemsOrderBy {
    my $self = shift;
    my $items = shift;
    return $items;
}

RT::Base->_ImportOverlays();

1;
