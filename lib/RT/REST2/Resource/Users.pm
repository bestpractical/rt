# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2025 Best Practical Solutions, LLC
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

package RT::REST2::Resource::Users;
use strict;
use warnings;

use Moose;
use namespace::autoclean;

extends 'RT::REST2::Resource::Collection';
with 'RT::REST2::Resource::Collection::QueryByJSON';

has 'privileged' => (
    is  => 'ro',
    required => 0,
);

sub dispatch_rules {
    Path::Dispatcher::Rule::Regex->new(
        regex => qr{^/users(?:/(privileged|unprivileged)?)?$},
        block => sub {
            my ($match, $req) = @_;
            my $privileged = $match->pos(1);
            if ( $privileged ) {
                if ( lc $privileged eq 'privileged' ) {
                    $privileged = 1;
                }
                else {
                    $privileged = 0;
                }
            }
            return { collection_class => 'RT::Users', privileged => $privileged }
        },
    ),
}

sub searchable_fields {
    my $self = shift;
    my $class = $self->collection->RecordClass;
    my @fields;
    if ($self->current_user->HasRight(
            Right   => "AdminUsers",
            Object  => RT->System,
        )) {
        @fields = grep {
            $class->_Accessible($_ => "public")
        } $class->ReadableAttributes;
    }
    else {
        @fields = split(/\s*\,\s*/, RT->Config->Get('UserSummaryExtraInfo'));
    }
    return @fields
}

sub forbidden {
    my $self = shift;

    return 0 if $self->current_user->Privileged;
    return 1;
}

override 'limit_collection' => sub {
    my $self = shift;
    if ( defined $self->privileged ) {
        if ( $self->privileged ) {
            $self->collection->LimitToPrivileged;
        }
        else {
            $self->collection->LimitToUnprivileged;
        }
    }

    super();
};

RT::Base->_ImportOverlays();

__PACKAGE__->meta->make_immutable;

1;
