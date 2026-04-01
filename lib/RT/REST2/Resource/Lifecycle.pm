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

package RT::REST2::Resource::Lifecycle;
use strict;
use warnings;

use Moose;
use namespace::autoclean;
use JSON ();
use RT::REST2::Util qw(error_as_json);

extends 'RT::REST2::Resource';
with 'RT::REST2::Resource::Role::RequestBodyIsJSON' => { type => 'HASH' };

has 'operation' => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
);

has 'lifecycle_name' => (
    is  => 'ro',
    isa => 'Str',
);

# ---- Dispatch rules ----

sub dispatch_rules {
    Path::Dispatcher::Rule::Regex->new(
        regex => qr{^/lifecycles/?$},
        block => sub { return { operation => 'list' } },
    ),
    Path::Dispatcher::Rule::Regex->new(
        regex => qr{^/lifecycle/([^/]+)/maps/?$},
        block => sub {
            my ($match) = @_;
            return { operation => 'maps', lifecycle_name => $match->pos(1) };
        },
    ),
    Path::Dispatcher::Rule::Regex->new(
        regex => qr{^/lifecycle/([^/]+)/validate/?$},
        block => sub {
            my ($match) = @_;
            return { operation => 'validate', lifecycle_name => $match->pos(1) };
        },
    ),
    Path::Dispatcher::Rule::Regex->new(
        regex => qr{^/lifecycle/([^/]+)/?$},
        block => sub {
            my ($match) = @_;
            return { operation => 'show', lifecycle_name => $match->pos(1) };
        },
    ),
}

# ---- Webmachine callbacks ----

sub resource_exists {
    my $self = shift;
    my $op   = $self->operation;

    return 1 if $op eq 'list';

    my $name = $self->lifecycle_name;
    my $lifecycles = RT->Config->Get('Lifecycles');
    return exists $lifecycles->{$name} ? 1 : 0;
}

sub forbidden {
    my $self = shift;
    my $cu   = $self->current_user;

    return 1 unless $cu->UserObj->HasRight(
        Right  => 'SuperUser',
        Object => RT->System,
    );

    return 0;
}

sub allowed_methods {
    my $self = shift;
    my $op   = $self->operation;

    return ['GET', 'HEAD', 'POST']       if $op eq 'list';
    return ['GET', 'HEAD', 'PUT', 'DELETE'] if $op eq 'show';
    return ['GET', 'HEAD', 'PUT']        if $op eq 'maps';
    return ['POST']                      if $op eq 'validate';
    return [];
}

sub post_is_create {
    my $self = shift;
    return $self->operation eq 'list' ? 1 : 0;
}

sub allow_missing_post { 1 }

sub process_post {
    my $self = shift;
    my $op   = $self->operation;

    if ( $op eq 'validate' ) {
        $self->_validate;
        return 1;
    }

    return 0;
}

sub create_path {
    '/lifecycle';
}

sub charsets_provided { ['utf-8'] }
sub default_charset   {  'utf-8'  }

sub content_types_provided { [{ 'application/json' => 'to_json' }] }
sub content_types_accepted { [{ 'application/json' => 'from_json' }] }

# ---- GET handlers ----

sub to_json {
    my $self = shift;
    my $op   = $self->operation;

    if ( $op eq 'list' ) {
        return $self->_serialize_list;
    }
    elsif ( $op eq 'show' ) {
        return $self->_serialize_lifecycle;
    }
    elsif ( $op eq 'maps' ) {
        return $self->_serialize_maps;
    }

    return '{}';
}

# ---- POST / PUT handlers ----

sub from_json {
    my $self = shift;
    my $op   = $self->operation;

    if ( $op eq 'list' ) {
        # POST /lifecycles -> create
        return $self->_create;
    }
    elsif ( $op eq 'show' ) {
        # PUT /lifecycle/:name -> update
        return $self->_update;
    }
    elsif ( $op eq 'maps' ) {
        # PUT /lifecycle/:name/maps -> update maps
        return $self->_update_maps;
    }
    return error_as_json( $self->response, \400, 'Unsupported operation' );
}

# ---- DELETE handler ----

sub delete_resource {
    my $self = shift;
    my $name = $self->lifecycle_name;

    my ( $ok, $msg ) = RT::Lifecycle->DeleteLifecycle(
        CurrentUser => $self->current_user,
        Name        => $name,
    );

    unless ($ok) {
        # Store error for finish_request to handle
        $self->{_delete_error} = $msg;
        $self->{_delete_error_code} = $msg =~ /used by|must.+remove/ ? 409 : 400;
        return 0;
    }

    RT::Lifecycle->FillCache;
    return 1;
}

sub finish_request {
    my ( $self, $metadata ) = @_;
    # Override 500 from failed delete_resource with the real error
    if ( $self->{_delete_error} ) {
        my $code = $self->{_delete_error_code} || 400;
        $self->response->status($code);
        $self->response->header( 'Content-Type' => 'application/json; charset=utf-8' );
        $self->response->body(
            JSON::to_json( { message => $self->{_delete_error} } )
        );
    }
}

# ---- Private methods ----

sub _serialize_list {
    my $self = shift;
    my $type = $self->request->param('type') || '';

    my @types;
    if ($type) {
        @types = ($type);
    }
    else {
        @types = List::MoreUtils::uniq(
            'ticket', 'asset',
            sort keys %RT::Lifecycle::LIFECYCLES_TYPES,
        );
    }

    my $base = RT::REST2->base_uri;
    my @items;

    for my $t (@types) {
        for my $name ( RT::Lifecycle->List($t) ) {
            my $lc_config = RT->Config->Get('Lifecycles')->{$name};
            push @items, {
                name     => $name,
                type     => $t,
                initial  => $lc_config->{initial}  || [],
                active   => $lc_config->{active}   || [],
                inactive => $lc_config->{inactive} || [],
                _url     => "$base/lifecycle/$name",
            };
        }
    }

    return JSON::to_json( \@items, { pretty => 1 } );
}

sub _serialize_lifecycle {
    my $self = shift;
    my $name = $self->lifecycle_name;

    my $lifecycle_obj = RT::Lifecycle->new;
    $lifecycle_obj->Load( Name => $name );
    my $type = $lifecycle_obj->Type || 'ticket';

    my $config = RT->Config->Get('Lifecycles')->{$name};
    my $base = RT::REST2->base_uri;

    my %result = (
        name => $name,
        type => $type,
        %$config,
        _url => "$base/lifecycle/$name",
    );

    # Add used_by info
    my @used_by;
    my $class = $type eq 'asset' ? 'RT::Catalogs' : 'RT::Queues';
    my $objects = $class->new( $self->current_user );
    $objects->UnLimit;
    $objects->Limit( FIELD => 'Lifecycle', VALUE => $name );
    while ( my $obj = $objects->Next ) {
        push @used_by, {
            type => $type eq 'asset' ? 'catalog' : 'queue',
            id   => $obj->Id,
            name => $obj->Name,
            _url => "$base/" . ( $type eq 'asset' ? 'catalog' : 'queue' ) . '/' . $obj->Id,
        };
    }
    $result{used_by} = \@used_by;

    # Remove internal fields that shouldn't be exposed
    delete $result{canonical_case};

    return JSON::to_json( \%result, { pretty => 1 } );
}

sub _serialize_maps {
    my $self = shift;
    my $name = $self->lifecycle_name;
    my $all_maps = RT->Config->Get('Lifecycles')->{__maps__} || {};

    my %maps;
    for my $key ( grep { /^\Q$name\E -> | -> \Q$name\E$/ } keys %$all_maps ) {
        $maps{$key} = $all_maps->{$key};
    }

    return JSON::to_json( \%maps, { pretty => 1 } );
}

sub _create {
    my $self = shift;
    my $data = JSON::from_json( $self->request->content );

    my $name  = $data->{Name};
    my $type  = $data->{Type}  || 'ticket';
    my $clone = $data->{Clone} || '';

    unless ($name) {
        return error_as_json( $self->response, \400, "Name is required" );
    }

    my ( $ok, $msg ) = RT::Lifecycle->CreateLifecycle(
        CurrentUser => $self->current_user,
        Name        => $name,
        Type        => $type,
        Clone       => $clone,
    );

    unless ($ok) {
        my $code = $msg =~ /already exists/ ? 409 : 400;
        return error_as_json( $self->response, \$code, $msg );
    }

    RT::Lifecycle->FillCache;

    my $base = RT::REST2->base_uri;
    my $config = RT->Config->Get('Lifecycles')->{$name};

    $self->response->body( JSON::to_json( {
        name => $name,
        %$config,
        _url => "$base/lifecycle/$name",
    }, { pretty => 1 } ) );

    return;
}

sub _update {
    my $self = shift;
    my $name = $self->lifecycle_name;
    my $data = JSON::from_json( $self->request->content );

    my $lifecycle_obj = RT::Lifecycle->new;
    $lifecycle_obj->Load( Name => $name );

    # Validate first
    my ( $valid, @warnings ) = $lifecycle_obj->ValidateLifecycle(
        Lifecycle   => $data,
        CurrentUser => $self->current_user,
    );

    unless ($valid) {
        return error_as_json( $self->response, \400,
            join( '; ', @warnings ) );
    }

    my ( $ok, $msg ) = RT::Lifecycle->UpdateLifecycle(
        CurrentUser  => $self->current_user,
        LifecycleObj => $lifecycle_obj,
        NewConfig    => $data,
    );

    unless ($ok) {
        return error_as_json( $self->response, \400, $msg );
    }

    RT::Lifecycle->FillCache;

    my $base = RT::REST2->base_uri;
    my $config = RT->Config->Get('Lifecycles')->{$name};

    $self->response->body( JSON::to_json( {
        name => $name,
        %$config,
        _url => "$base/lifecycle/$name",
    }, { pretty => 1 } ) );

    return;
}

sub _update_maps {
    my $self = shift;
    my $name = $self->lifecycle_name;
    my $data = JSON::from_json( $self->request->content );

    my ( $ok, $msg ) = RT::Lifecycle->UpdateMaps(
        CurrentUser => $self->current_user,
        Maps        => $data,
        Name        => $name,
    );

    unless ($ok) {
        return error_as_json( $self->response, \400, $msg );
    }

    RT::Lifecycle->FillCache;

    # Return the updated maps
    my $all_maps = RT->Config->Get('Lifecycles')->{__maps__} || {};
    my %maps;
    for my $key ( grep { /^\Q$name\E -> | -> \Q$name\E$/ } keys %$all_maps ) {
        $maps{$key} = $all_maps->{$key};
    }

    $self->response->body( JSON::to_json( \%maps, { pretty => 1 } ) );
    return;
}

sub _validate {
    my $self = shift;
    my $name = $self->lifecycle_name;
    my $data = JSON::from_json( $self->request->content );

    my $lifecycle_obj = RT::Lifecycle->new;
    $lifecycle_obj->Load( Name => $name );

    my ( $valid, @warnings ) = $lifecycle_obj->ValidateLifecycle(
        Lifecycle   => $data,
        CurrentUser => $self->current_user,
    );

    $self->response->body( JSON::to_json( {
        valid    => $valid ? JSON::true : JSON::false,
        warnings => \@warnings,
    }, { pretty => 1 } ) );

    return;
}

require RT::Base;
RT::Base->_ImportOverlays();

__PACKAGE__->meta->make_immutable;

1;
