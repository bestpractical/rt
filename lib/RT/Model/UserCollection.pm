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

=head1 NAME

  RT::Model::UserCollection - Collection of RT::Model::User objects

=head1 SYNOPSIS

  use RT::Model::UserCollection;


=head1 description


=head1 METHODS


=cut

use warnings;
use strict;

package RT::Model::UserCollection;
use base qw/RT::IsPrincipalCollection RT::Collection/;

sub _init {
    my $self = shift;

    my @result = $self->SUPER::_init(@_);

    # By default, order by name
    $self->order_by(
        alias  => 'main',
        column => 'name',
        order  => 'ASC'
    );

    return (@result);
}


=head2 _do_search

  A subclass of Jifty::DBI::_do_search that makes sure that _disabled rows never get seen unless
we're explicitly trying to see them.

=cut

sub _do_search {
    my $self = shift;

    #unless we really want to find disabled rows, make sure we\'re only finding enabled ones.
    unless ( $self->{'find_disabled_rows'} ) {
        $self->limit_to_enabled();
    }
    return ( $self->SUPER::_do_search(@_) );
}

=head2 limit_to_email

Takes one argument. an email address. limits the returned set to
that email address

=cut

sub limit_to_email {
    my $self = shift;
    my $addr = shift;
    $self->limit( column => 'email', value => "$addr" );
}



=head2 limit_to_privileged

Limits to users who can be made members of ACLs and groups

=cut

sub limit_to_privileged {
    my $self = shift;

    my $priv = RT::Model::Group->new;
    $priv->load_system_internal('privileged');
    unless ( $priv->id ) {
        Jifty->log->fatal("Couldn't find a privileged users group");
    }
    $self->member_of( $priv->principal_id );
}

1;
