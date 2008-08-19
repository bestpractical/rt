# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2007 Best Practical Solutions, LLC
#                                          <jesse@bestpractical.com>
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
# http://www.gnu.org/copyleft/gpl.html.
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

=head1 name

  RT::Model::ScripCondition - RT scrip conditional

=head1 SYNOPSIS

  use RT::Model::ScripCondition;


=head1 description

This module should never be called directly by client code. it's an internal module which
should only be accessed through exported APIs in other modules.



=head1 METHODS

=cut

use strict;
use warnings;

package RT::Model::ScripCondition;
use base qw/RT::Record/;

sub table {'ScripConditions'}
use Jifty::DBI::Schema;
use Jifty::DBI::Record schema {
    column name                   => type is 'text';
    column description            => type is 'text';
    column exec_module            => type is 'text';
    column argument               => type is 'text';
    column applicable_trans_types => type is 'text';
    column creator                => references RT::Model::User;
    column created                => type is 'timestamp';
    column last_updated_by        => references RT::Model::User;
    column last_updated           => type is 'timestamp';

};

=head2 delete

No API available for deleting things just yet.

=cut

sub delete {
    my $self = shift;
    return ( 0, _('Unimplemented') );
}

=head2 load IDENTIFIER

Loads a condition takes a name or ScripCondition id.

=cut

sub load {
    my $self       = shift;
    my $identifier = shift;

    unless ( defined $identifier ) {
        return (undef);
    }

    if ( $identifier !~ /\D/ ) {
        return ( $self->SUPER::load_by_id($identifier) );
    } else {
        return ( $self->load_by_cols( 'name', $identifier ) );
    }
}

=head2 load_condition  HASH

takes a hash which has the following elements:  transaction_obj and ticket_obj.
Loads the condition module in question.

=cut

sub load_condition {
    my $self = shift;
    my %args = (
        transaction_obj => undef,
        ticket_obj      => undef,
        @_
    );

    my $type = "RT::Condition::" . $self->exec_module;

    Jifty::Util->require($type);

    $self->{'condition'} = $type->new(
        'scrip_scrip_condition'  => $self,
        'ticket_obj'             => $args{'ticket_obj'},
        'scrip_obj'              => $args{'scrip_obj'},
        'transaction_obj'        => $args{'transaction_obj'},
        'argument'               => $self->argument,
        'applicable_trans_types' => $self->applicable_trans_types,
        current_user             => $self->current_user
    );
}

=head2 describe 

Helper method to call the condition module's describe method.

=cut

sub describe {
    my $self = shift;
    return ( $self->{'condition'}->describe() );

}

=head2 is_applicable

Helper method to call the condition module\'s is_applicable method.

=cut

sub is_applicable {
    my $self = shift;
    return ( $self->{'condition'}->is_applicable() );

}

sub DESTROY {
    my $self = shift;
    $self->{'condition'} = undef;
}

sub _value { shift->__value(@_) }
1;

