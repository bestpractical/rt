# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2026 Best Practical Solutions, LLC
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

package RT::REST2::Resource::CustomFieldAppliesTo;
use strict;
use warnings;

use Moose;
use namespace::autoclean;
use JSON ();
use POSIX qw(ceil);
use RT::REST2::Util qw(error_as_json);

extends 'RT::REST2::Resource';
with 'RT::REST2::Resource::Role::RequestBodyIsJSON' => { type => 'HASH' };

has 'custom_field' => (
    is       => 'ro',
    required => 1,
);

has 'operation' => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
);

# For delete operations: the ObjectId to remove
has 'object_id' => (
    is  => 'ro',
    isa => 'Str',
);

# ---- Dispatch rules ----

sub dispatch_rules {
    my $load_cf = sub {
        my ( $match, $req ) = @_;
        my $cu = $req->env->{'rt.current_user'};
        my $cf = RT::CustomField->new($cu);
        $cf->Load( $match->pos(1) );
        return $cf;
    };

    return (
        Path::Dispatcher::Rule::Regex->new(
            regex => qr{^/customfield/(\d+)/appliesto/?$},
            block => sub {
                my ( $match, $req ) = @_;
                return {
                    custom_field => $load_cf->( $match, $req ),
                    operation    => 'list',
                };
            },
        ),
        Path::Dispatcher::Rule::Regex->new(
            regex => qr{^/customfield/(\d+)/appliesto/object/(\d+)/?$},
            block => sub {
                my ( $match, $req ) = @_;
                return {
                    custom_field => $load_cf->( $match, $req ),
                    operation    => 'delete',
                    object_id    => $match->pos(2),
                };
            },
        ),
    );
}

# ---- Webmachine callbacks ----

sub resource_exists {
    my $self = shift;
    return 0 unless $self->custom_field->Id;

    if ( $self->operation eq 'delete' ) {
        return $self->custom_field->IsAdded( $self->object_id ) ? 1 : 0;
    }

    return 1;
}

sub forbidden {
    my $self = shift;
    my $cf   = $self->custom_field;

    # Let resource_exists handle nonexistent CFs
    return 0 unless $cf->Id;

    # POST and DELETE check AssignCustomFields on the target object,
    # which is done in the action methods. Here we just verify the CF
    # is accessible.
    return !$cf->CurrentUserHasRight('SeeCustomField');
}

sub allowed_methods {
    my $self = shift;
    my $op   = $self->operation;
    return ['GET', 'HEAD', 'POST'] if $op eq 'list';
    return ['DELETE']               if $op eq 'delete';
    return [];
}

sub post_is_create     { 1 }
sub allow_missing_post { 1 }

sub create_path {
    my $self = shift;
    return '/customfield/' . $self->custom_field->Id . '/appliesto';
}

sub charsets_provided { ['utf-8'] }
sub default_charset   {  'utf-8'  }

sub content_types_provided { [{ 'application/json' => 'to_json' }] }
sub content_types_accepted { [{ 'application/json' => 'from_json' }] }

# ---- GET handler ----

sub to_json {
    my $self = shift;

    if ( $self->operation eq 'list' ) {
        return JSON::to_json( $self->_serialize_list, { pretty => 1 } );
    }

    return '{}';
}

# ---- POST handler ----

sub from_json {
    my $self = shift;

    if ( $self->operation eq 'list' ) {
        return $self->_add_to_object;
    }

    return error_as_json( $self->response, \400, 'Unsupported operation' );
}

# ---- DELETE handler ----

sub delete_resource {
    my $self      = shift;
    my $cf        = $self->custom_field;
    my $object_id = $self->object_id;

    my $object = $self->_load_object($object_id);
    unless ($object) {
        return 0;
    }

    my ( $ok, $msg ) = $cf->RemoveFromObject($object);
    return $ok ? 1 : 0;
}

# ---- Private methods ----

sub _serialize_list {
    my $self = shift;
    my $cf   = $self->custom_field;

    # Use a SystemUser-loaded CF for AddedTo so results aren't
    # filtered by the requesting user's queue/class/catalog visibility.
    # The ACL gate is on the CF itself (SeeCustomField), not the objects.
    my $sys_cf = RT::CustomField->new( RT->SystemUser );
    $sys_cf->Load( $cf->Id );

    my @items;

    # Check for global application
    if ( $sys_cf->IsGlobal ) {
        push @items, {
            ObjectId => 0,
            Global   => JSON::true,
        };
    }

    # Get specific object applications
    my $added = $sys_cf->AddedTo;
    while ( my $obj = $added->Next ) {
        my $type = lc( ref($obj) =~ s/^RT:://r );
        push @items, {
            ObjectType => ref($obj),
            ObjectId   => $obj->Id + 0,
            ObjectName => $obj->Name,
            _url       => RT::REST2->base_uri . "/$type/" . $obj->Id,
        };
    }

    # Paging
    my $per_page = $self->request->param('per_page') || 20;
    if    ( $per_page !~ /^\d+$/ ) { $per_page = 20 }
    elsif ( $per_page == 0 )       { $per_page = 20 }
    elsif ( $per_page > 100 )      { $per_page = 100 }

    my $total = scalar @items;
    my $pages = $total ? ceil( $total / $per_page ) : 1;

    my $page = $self->request->param('page') || 1;
    if    ( $page !~ /^\d+$/ ) { $page = 1 }
    elsif ( $page == 0 )       { $page = 1 }
    $page = $pages if $page > $pages;

    my $start = ( $page - 1 ) * $per_page;
    my $end   = $start + $per_page - 1;
    $end = $#items if $end > $#items;

    my @paged = $start <= $#items ? @items[ $start .. $end ] : ();

    my %result = (
        count    => scalar(@paged) + 0,
        total    => $total + 0,
        per_page => $per_page + 0,
        page     => $page + 0,
        pages    => $pages + 0,
        items    => \@paged,
    );

    # Build paging URLs
    my $uri        = $self->request->uri;
    my @query_form = $uri->query_form;
    for my $i ( 0 .. $#query_form ) {
        if ( $query_form[$i] eq 'page' ) {
            delete @query_form[ $i, $i + 1 ];
            last;
        }
    }

    if ( $page < $pages ) {
        $uri->query_form( @query_form, page => $page + 1 );
        $result{next_page} = $uri->as_string;
    }

    if ( $page > 1 ) {
        $uri->query_form( @query_form, page => $page - 1 );
        $result{prev_page} = $uri->as_string;
    }

    return \%result;
}

sub _add_to_object {
    my $self = shift;
    my $cf   = $self->custom_field;
    my $data = JSON::from_json( $self->request->content );

    unless ( defined $data->{ObjectId} ) {
        return error_as_json( $self->response, \400, "ObjectId is required" );
    }

    my $object_id = $data->{ObjectId};

    unless ( $object_id =~ /^\d+$/ ) {
        return error_as_json( $self->response, \400, "ObjectId must be a non-negative integer" );
    }

    # Check for duplicate before attempting (for proper 409)
    if ( $cf->IsAdded($object_id) ) {
        return error_as_json(
            $self->response, \409,
            "Custom field already applied to this object"
        );
    }

    my $object = $self->_load_object($object_id);
    unless ($object) {
        return error_as_json(
            $self->response, \400,
            "Could not load object $object_id"
        );
    }

    my ( $ok, $msg ) = $cf->AddToObject($object);
    if ($ok) {
        my %body = ( message => $msg );
        if ( $object_id == 0 ) {
            $body{ObjectId} = 0;
            $body{Global}   = JSON::true;
        }
        else {
            # Load with SystemUser for Name in response
            my $sys_obj = $self->_load_object_as_system($object_id);
            my $type = lc( ref($object) =~ s/^RT:://r );
            $body{ObjectType} = ref($object);
            $body{ObjectId}   = $object->Id + 0;
            $body{ObjectName} = $sys_obj ? $sys_obj->Name : undef;
            $body{_url}       = RT::REST2->base_uri . "/$type/" . $object->Id;
        }
        $self->response->body( JSON::encode_json( \%body ) );
        return;
    }

    my $code
        = $msg =~ /Permission Denied/i ? 403
        :                                400;
    return error_as_json( $self->response, \$code, $msg );
}

sub _load_object {
    my $self      = shift;
    my $object_id = shift;
    my $cf        = $self->custom_field;

    my $class = $cf->RecordClassFromLookupType;
    return undef unless $class;

    my $object = $class->new( $self->current_user );
    if ( $object_id == 0 ) {
        # Unloaded object with id 0 represents "all objects" (global)
        return $object;
    }

    $object->Load($object_id);
    return $object->Id ? $object : undef;
}

sub _load_object_as_system {
    my $self      = shift;
    my $object_id = shift;
    my $cf        = $self->custom_field;

    my $class = $cf->RecordClassFromLookupType;
    return undef unless $class;

    my $object = $class->new( RT->SystemUser );
    $object->Load($object_id);
    return $object->Id ? $object : undef;
}

require RT::Base;
RT::Base->_ImportOverlays();

__PACKAGE__->meta->make_immutable;

1;
