# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2017 Best Practical Solutions, LLC
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

use RT::Link ();
package RT::Link;

use strict;
use warnings;
use warnings FATAL => 'redefine';

use RT::Shredder::Exceptions;
use RT::Shredder::Dependencies;
use RT::Shredder::Constants;

use RT::Shredder::Transaction;
use RT::Shredder::Record;

sub __DependsOn
{
    my $self = shift;
    my %args = (
            Shredder => undef,
            Dependencies => undef,
            @_,
           );
    my $deps = $args{'Dependencies'};
    my $list = [];

# AddLink transactions
    my $map = RT::Ticket->LINKTYPEMAP;
    my $link_meta = $map->{ $self->Type };
    unless ( $link_meta && $link_meta->{'Mode'} && $link_meta->{'Type'} ) {
        RT::Shredder::Exception->throw( 'Wrong link link_meta, no record for '. $self->Type );
    }
    if ( $self->BaseURI->IsLocal ) {
        my $objs = $self->BaseObj->Transactions;
        $objs->Limit(
            FIELD    => 'Type',
            OPERATOR => '=',
            VALUE    => 'AddLink',
        );
        $objs->Limit( FIELD => 'NewValue', VALUE => $self->Target );
        while ( my ($k, $v) = each %$map ) {
            next unless $v->{'Type'} eq $link_meta->{'Type'};
            next unless $v->{'Mode'} eq $link_meta->{'Mode'};
            $objs->Limit( FIELD => 'Field', VALUE => $k );
        }
        push( @$list, $objs );
    }

    my %reverse = ( Base => 'Target', Target => 'Base' );
    if ( $self->TargetURI->IsLocal ) {
        my $objs = $self->TargetObj->Transactions;
        $objs->Limit(
            FIELD    => 'Type',
            OPERATOR => '=',
            VALUE    => 'AddLink',
        );
        $objs->Limit( FIELD => 'NewValue', VALUE => $self->Base );
        while ( my ($k, $v) = each %$map ) {
            next unless $v->{'Type'} eq $link_meta->{'Type'};
            next unless $v->{'Mode'} eq $reverse{ $link_meta->{'Mode'} };
            $objs->Limit( FIELD => 'Field', VALUE => $k );
        }
        push( @$list, $objs );
    }

    $deps->_PushDependencies(
            BaseObject => $self,
            Flags => DEPENDS_ON|WIPE_AFTER,
            TargetObjects => $list,
            Shredder => $args{'Shredder'}
        );
    return $self->SUPER::__DependsOn( %args );
}

#TODO: Link record has small strength, but should be encountered
# if we plan write export tool.

sub __Relates
{
    my $self = shift;
    my %args = (
            Shredder => undef,
            Dependencies => undef,
            @_,
           );
    my $deps = $args{'Dependencies'};
    my $list = [];
# FIXME: if link is local then object should exist

    return $self->SUPER::__Relates( %args );
}

1;
