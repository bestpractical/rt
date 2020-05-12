# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2019 Best Practical Solutions, LLC
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

package RT::REST2::Resource::Role::RequestBodyIsJSON;
use strict;
use warnings;

use MooseX::Role::Parameterized;
use namespace::autoclean;

use JSON ();
use RT::REST2::Util qw( error_as_json );
use Moose::Util::TypeConstraints qw( enum );

parameter 'type' => (
    isa     => enum([qw(ARRAY HASH)]),
    default => 'HASH',
);

role {
    my $P = shift;

    around 'malformed_request' => sub {
        my $orig = shift;
        my $self = shift;
        my $malformed = $self->$orig(@_);
        return $malformed if $malformed;

        my $request = $self->request;
        return 0 unless $request->method =~ /^(PUT|POST)$/;
        return 0 unless $request->header('Content-Type') =~ /^application\/json/;

        my $json = eval {
            JSON::from_json($request->content)
        };
        if ($@ or not $json) {
            my $error = $@;
               $error =~ s/ at \S+? line \d+\.?$//;
            error_as_json($self->response, undef, "JSON parse error: $error");
            return 1;
        }
        elsif (ref $json ne $P->type) {
            error_as_json($self->response, undef, "JSON object must be a ", $P->type);
            return 1;
        } else {
            return 0;
        }
    };
};

1;
