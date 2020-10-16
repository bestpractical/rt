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

package RT::Test::REST2;

use strict;
use warnings;

use base 'RT::Test';
use Test::WWW::Mechanize::PSGI;

sub import {
    my $class = shift;
    my %args  = @_;

    $class->SUPER::import( %args );
    __PACKAGE__->export_to_level(1);
}

=pod

sub import {
    my $class = shift;
    my %args  = @_;

    $args{'requires'} ||= [];
    if ( $args{'testing'} ) {
        unshift @{ $args{'requires'} }, 'RT::REST2';
    } else {
        $args{'testing'} = 'RT::REST2';
    }

    $class->SUPER::import( %args );
    $class->export_to_level(1);

    require RT::REST2;
}

=cut

sub mech { RT::Test::REST2::Mechanize->new }

{
    my $u;

    sub authorization_header {
        $u = _create_user() unless ($u && $u->id);
        return 'Basic dGVzdDpwYXNzd29yZA==';
    }

    sub user {
        $u = _create_user() unless ($u && $u->id);
        return $u;
    }

    sub _create_user {
        my $u = RT::User->new( RT->SystemUser );
        $u->Create(
            Name => 'test',
            Password => 'password',
            Privileged => 1,
        );
        return $u;
    }
}

{
    package RT::Test::REST2::Mechanize;
    use parent 'Test::WWW::Mechanize::PSGI';

    use JSON;
    my $json = JSON->new->utf8;

    sub new {
        my $class = shift;
        my %args = (
            app => RT::REST2->PSGIWrap(sub { die "Requested non-REST path" }),
            @_,
        );
        return $class->SUPER::new(%args);
    }

    sub hypermedia_ref {
        my ($self, $ref) = @_;

        my $json = $self->json_response;
        my @matches = grep { $_->{ref} eq $ref } @{ $json->{_hyperlinks} };
        Test::More::is(@matches, 1, "got one match for hypermedia with ref '$ref'") or return;
        return $matches[0];

    }

    sub url_for_hypermedia {
        my ($self, $ref) = @_;
        return $self->hypermedia_ref($ref)->{_url};
    }

    sub post_json {
        my ($self, $url, $payload, %headers) = @_;
        $self->post(
            $url,
            Content => $json->encode($payload),
            'Content-Type' => 'application/json; charset=utf-8',
            %headers,
        );
    }

    sub put_json {
        my ($self, $url, $payload, %headers) = @_;
        $self->put(
            $url,
            $payload ? ( Content => $json->encode($payload) ) : (),
            'Content-Type' => 'application/json; charset=utf-8',
            %headers,
        );
    }

    sub json_response {
        local $Test::Builder::Level = $Test::Builder::Level + 1;
        my $self = shift;

        my $res = $self->response;

        local $main::TODO;
        Test::More::like($res->header('content-type'),
            qr{^application/json(?:; charset="?utf-8"?)?$});

        return $json->decode($res->content);
    }
}

1;
