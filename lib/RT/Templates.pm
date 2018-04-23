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

  RT::Templates - a collection of RT Template objects

=head1 SYNOPSIS

  use RT::Templates;

=head1 DESCRIPTION


=head1 METHODS


=cut


package RT::Templates;

use strict;
use warnings;

use base 'RT::SearchBuilder';

use RT::Template;

sub Table { 'Templates'}


=head2 LimitToNotInQueue

Takes a queue id # and limits the returned set of templates to those which 
aren't that queue's templates.

=cut

sub LimitToNotInQueue {
    my $self = shift;
    my $queue_id = shift;
    $self->Limit(FIELD => 'Queue',
                 VALUE => "$queue_id",
                 OPERATOR => '!='
                );
}


=head2 LimitToGlobal

Takes no arguments. Limits the returned set to "Global" templates
which can be used with any queue.

=cut

sub LimitToGlobal {
    my $self = shift;
    $self->Limit(FIELD => 'Queue',
                 VALUE => "0",
                 OPERATOR => '='
                );
}


=head2 LimitToQueue

Takes a queue id # and limits the returned set of templates to that queue's
templates

=cut

sub LimitToQueue {
    my $self = shift;
    my $queue_id = shift;
    $self->Limit(FIELD => 'Queue',
                 VALUE => "$queue_id",
                 OPERATOR => '='
                );
}


=head2 AddRecord

Overrides the collection to ensure that only templates the user can see
are returned.

=cut

sub AddRecord {
    my $self = shift;
    my ($record) = @_;

    return unless $record->CurrentUserCanRead;
    return $self->SUPER::AddRecord( $record );
}

RT::Base->_ImportOverlays();

1;
