# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2020 Best Practical Solutions, LLC
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

package RT::REST2::Resource::Transactions;
use strict;
use warnings;

use Moose;
use namespace::autoclean;

extends 'RT::REST2::Resource::Collection';
with 'RT::REST2::Resource::Collection::QueryByJSON';

sub dispatch_rules {
    Path::Dispatcher::Rule::Regex->new(
        regex => qr{^/transactions/?$},
        block => sub { { collection_class => 'RT::Transactions' } },
    ),
    Path::Dispatcher::Rule::Regex->new(
        regex => qr{^/(ticket|queue|asset|user|group)/(\d+)/history/?$},
        block => sub {
            my ($match, $req) = @_;
            my ($class, $id) = ($match->pos(1), $match->pos(2));

            my $record;
            if ($class eq 'ticket') {
                $record = RT::Ticket->new($req->env->{"rt.current_user"});
            }
            elsif ($class eq 'queue') {
                $record = RT::Queue->new($req->env->{"rt.current_user"});
            }
            elsif ($class eq 'asset') {
                $record = RT::Asset->new($req->env->{"rt.current_user"});
            }
            elsif ($class eq 'user') {
                $record = RT::User->new($req->env->{"rt.current_user"});
            }
            elsif ($class eq 'group') {
                $record = RT::Group->new($req->env->{"rt.current_user"});
            }

            $record->Load($id);
            return { collection => $record->Transactions };
        },
    ),
    Path::Dispatcher::Rule::Regex->new(
        regex => qr{^/(queue|user)/([^/]+)/history/?$},
        block => sub {
            my ($match, $req) = @_;
            my ($class, $id) = ($match->pos(1), $match->pos(2));

            my $record;
            if ($class eq 'queue') {
                $record = RT::Queue->new($req->env->{"rt.current_user"});
            }
            elsif ($class eq 'user') {
                $record = RT::User->new($req->env->{"rt.current_user"});
            }

            $record->Load($id);
            return { collection => $record->Transactions };
        },
    )
}

__PACKAGE__->meta->make_immutable;

1;
