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

package RT::REST2::Resource::Rights;
use strict;
use warnings;

use Moose;
use namespace::autoclean;
use JSON ();
use POSIX qw(ceil);
use RT::REST2::Util qw(error_as_json);

extends 'RT::REST2::Resource';
with 'RT::REST2::Resource::Role::Rights';
with 'RT::REST2::Resource::Role::RequestBodyIsJSON' => { type => 'HASH' };

has 'object' => (
    is       => 'ro',
    required => 1,
);

has 'operation' => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
);

# For delete operations
has 'right_name'     => ( is => 'ro', isa => 'Str' );
has 'principal_type' => ( is => 'ro', isa => 'Str' );
has 'principal_id'   => ( is => 'ro', isa => 'Str' );

# ---- Dispatch rules ----

sub dispatch_rules {
    my $make_rules = sub {
        my ( $path, $object_type, $allow_name ) = @_;
        my @rules;

        my $load_obj = sub {
            my ( $match, $req ) = @_;
            my $cu  = $req->env->{'rt.current_user'};
            my $obj = "RT::$object_type"->new($cu);
            $obj->Load( $match->pos(1) );
            return $obj;
        };

        my @specs = (
            [ qr{^/$path/(\d+)/rights/available/?$},                          'available' ],
            [ qr{^/$path/(\d+)/rights/bulk/?$},                               'bulk'      ],
            [ qr{^/$path/(\d+)/rights/(\w+)/(group|user)/([^/]+)/?$},         'delete'    ],
            [ qr{^/$path/(\d+)/rights/?$},                                    'list'      ],
        );

        for my $spec (@specs) {
            my ( $regex, $op ) = @$spec;
            push @rules, Path::Dispatcher::Rule::Regex->new(
                regex => $regex,
                block => sub {
                    my ( $match, $req ) = @_;
                    my $obj  = $load_obj->( $match, $req );
                    my %args = ( object => $obj, operation => $op );
                    if ( $op eq 'delete' ) {
                        $args{right_name}     = $match->pos(2);
                        $args{principal_type} = $match->pos(3);
                        $args{principal_id}   = $match->pos(4);
                    }
                    return \%args;
                },
            );
        }

        if ($allow_name) {
            my @name_specs = (
                [ qr{^/$path/([^/]+)/rights/available/?$},                          'available' ],
                [ qr{^/$path/([^/]+)/rights/bulk/?$},                               'bulk'      ],
                [ qr{^/$path/([^/]+)/rights/(\w+)/(group|user)/([^/]+)/?$},         'delete'    ],
                [ qr{^/$path/([^/]+)/rights/?$},                                    'list'      ],
            );

            for my $spec (@name_specs) {
                my ( $regex, $op ) = @$spec;
                push @rules, Path::Dispatcher::Rule::Regex->new(
                    regex => $regex,
                    block => sub {
                        my ( $match, $req ) = @_;
                        my $obj  = $load_obj->( $match, $req );
                        my %args = ( object => $obj, operation => $op );
                        if ( $op eq 'delete' ) {
                            $args{right_name}     = $match->pos(2);
                            $args{principal_type} = $match->pos(3);
                            $args{principal_id}   = $match->pos(4);
                        }
                        return \%args;
                    },
                );
            }
        }

        return @rules;
    };

    # Global rights (no object id in URL)
    my @global_rules;
    my @global_specs = (
        [ qr{^/global/rights/available/?$},                          'available' ],
        [ qr{^/global/rights/bulk/?$},                               'bulk'      ],
        [ qr{^/global/rights/(\w+)/(group|user)/([^/]+)/?$},         'delete'    ],
        [ qr{^/global/rights/?$},                                    'list'      ],
    );

    for my $spec (@global_specs) {
        my ( $regex, $op ) = @$spec;
        push @global_rules, Path::Dispatcher::Rule::Regex->new(
            regex => $regex,
            block => sub {
                my ( $match, $req ) = @_;
                my %args = (
                    object    => RT::System->new( $req->env->{'rt.current_user'} ),
                    operation => $op,
                );
                if ( $op eq 'delete' ) {
                    $args{right_name}     = $match->pos(1);
                    $args{principal_type} = $match->pos(2);
                    $args{principal_id}   = $match->pos(3);
                }
                return \%args;
            },
        );
    }

    return (
        $make_rules->( 'queue',       'Queue',       1 ),
        $make_rules->( 'group',       'Group'          ),
        $make_rules->( 'class',       'Class',       1 ),
        $make_rules->( 'catalog',     'Catalog',     1 ),
        $make_rules->( 'customfield', 'CustomField'    ),
        @global_rules,
    );
}

# ---- Webmachine callbacks ----

sub resource_exists {
    my $self = shift;
    my $obj  = $self->object;
    return 1 if ref($obj) eq 'RT::System';
    return 0 unless $obj->Id;

    if ( $self->operation eq 'delete' ) {
        return $self->_find_ace ? 1 : 0;
    }

    return 1;
}

sub forbidden {
    my $self = shift;
    return $self->rights_forbidden;
}

sub allowed_methods {
    my $self = shift;
    my $op   = $self->operation;
    return ['GET', 'HEAD', 'POST'] if $op eq 'list';
    return ['GET', 'HEAD']         if $op eq 'available';
    return ['POST']                if $op eq 'bulk';
    return ['DELETE']              if $op eq 'delete';
    return [];
}

sub post_is_create     { 1 }
sub allow_missing_post { 1 }

sub create_path {
    my $self = shift;
    my $obj  = $self->object;
    if ( ref($obj) eq 'RT::System' ) {
        return '/global/rights';
    }
    my $type = lc( ref($obj) =~ s/^RT:://r );
    return "/$type/" . $obj->Id . '/rights';
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
        return JSON::to_json( $self->_serialize_list, { pretty => 1 } );
    }
    elsif ( $op eq 'available' ) {
        return JSON::to_json( $self->available_rights_for, { pretty => 1 } );
    }

    return '{}';
}

# ---- POST handlers ----

sub from_json {
    my $self = shift;
    my $op   = $self->operation;

    if ( $op eq 'list' ) {
        return $self->_grant_single;
    }
    elsif ( $op eq 'bulk' ) {
        return $self->_grant_revoke_bulk;
    }

    return error_as_json( $self->response, \400, 'Unsupported operation' );
}

# ---- DELETE handler ----

sub delete_resource {
    my $self = shift;

    my $principal = $self->_load_principal;
    return 0 unless $principal;

    my ( $ok, $msg ) = $principal->RevokeRight(
        Right  => $self->right_name,
        Object => $self->object,
    );
    return $ok ? 1 : 0;
}

# ---- Private methods ----

sub _serialize_list {
    my $self = shift;
    my $obj  = $self->object;

    my $acl = RT::ACL->new( $self->current_user );
    $acl->LimitToObject($obj);

    # Filter by principal
    if ( my $group_id = $self->request->param('group') ) {
        $acl->LimitToPrincipal( Id => $group_id );
    }
    elsif ( my $user_id = $self->request->param('user') ) {
        my $user = RT::User->new( $self->current_user );
        $user->Load($user_id);
        if ( $user->Id ) {
            $acl->LimitToPrincipal( Id => $user->PrincipalObj->Id );
        }
    }

    # Paging setup
    my $per_page = $self->request->param('per_page') || 20;
    if    ( $per_page !~ /^\d+$/ ) { $per_page = 20 }
    elsif ( $per_page == 0 )       { $per_page = 20 }
    elsif ( $per_page > 100 )      { $per_page = 100 }
    $acl->RowsPerPage($per_page);

    my $page = $self->request->param('page') || 1;
    if    ( $page !~ /^\d+$/ ) { $page = 1 }
    elsif ( $page == 0 )       { $page = 1 }

    my $total = $acl->CountAll;
    my $pages = $total ? ceil( $total / $per_page ) : 1;
    $page = $pages if $page > $pages;
    $acl->GotoPage( $page - 1 );

    # Serialize items
    my @items;
    while ( my $ace = $acl->Next ) {
        push @items, $self->serialize_ace($ace);
    }

    my %result = (
        count    => scalar(@items) + 0,
        total    => $total + 0,
        per_page => $per_page + 0,
        page     => $page + 0,
        pages    => $pages + 0,
        items    => \@items,
    );

    # Build paging URLs (follows Collection.pm pattern)
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

sub _grant_single {
    my $self = shift;
    my $data = JSON::from_json( $self->request->content );
    my $obj  = $self->object;

    my $right = $data->{Right};
    unless ($right) {
        return error_as_json( $self->response, \400, "Right is required" );
    }

    my ( $principal, $display ) = $self->resolve_principal($data);
    unless ($principal) {
        return error_as_json( $self->response, \400, $display );
    }

    my ( $ok, $msg ) = $principal->GrantRight( Right => $right, Object => $obj );
    if ($ok) {
        $self->response->body(
            JSON::encode_json( { Right => $right, %$display } )
        );
        return;
    }

    my $code
        = $msg =~ /already has/i      ? 409
        : $msg =~ /Permission Denied/i ? 403
        :                               400;
    return error_as_json( $self->response, \$code, $msg );
}

sub _grant_revoke_bulk {
    my $self = shift;
    my $data = JSON::from_json( $self->request->content );
    my $obj  = $self->object;

    unless ( ref($data) eq 'HASH'
        && ( $data->{grant} || $data->{revoke} ) )
    {
        return error_as_json( $self->response, \400,
            "Request must include 'grant' and/or 'revoke' arrays" );
    }

    for my $key (qw(grant revoke)) {
        next unless exists $data->{$key};
        unless ( ref( $data->{$key} ) eq 'ARRAY' ) {
            return error_as_json( $self->response, \400, "'$key' must be an array" );
        }
    }

    my @granted;
    for my $item ( @{ $data->{grant} || [] } ) {
        unless ( ref($item) eq 'HASH' ) {
            push @granted, { status => 400, message => "Each item must be a JSON object" };
            next;
        }
        my $right = $item->{Right};
        unless ($right) {
            push @granted, { %$item, status => 400, message => "Right is required" };
            next;
        }

        my ( $principal, $display ) = $self->resolve_principal($item);
        unless ($principal) {
            push @granted, { Right => $right, status => 400, message => $display };
            next;
        }

        my ( $ok, $msg ) = $principal->GrantRight( Right => $right, Object => $obj );
        if ($ok) {
            push @granted, { Right => $right, %$display, status => 201 };
        }
        else {
            my $code
                = $msg =~ /already has/i      ? 409
                : $msg =~ /Permission Denied/i ? 403
                :                               400;
            push @granted,
                { Right => $right, %$display, status => $code, message => $msg };
        }
    }

    my @revoked;
    for my $item ( @{ $data->{revoke} || [] } ) {
        unless ( ref($item) eq 'HASH' ) {
            push @revoked, { status => 400, message => "Each item must be a JSON object" };
            next;
        }
        my $right = $item->{Right};
        unless ($right) {
            push @revoked, { %$item, status => 400, message => "Right is required" };
            next;
        }

        my ( $principal, $display ) = $self->resolve_principal($item);
        unless ($principal) {
            push @revoked, { Right => $right, status => 400, message => $display };
            next;
        }

        my ( $ok, $msg ) = $principal->RevokeRight( Right => $right, Object => $obj );
        if ($ok) {
            push @revoked, { Right => $right, %$display, status => 204 };
        }
        else {
            my $code
                = $msg =~ /not granted|not found/i ? 404
                : $msg =~ /Permission Denied/i      ? 403
                :                                    400;
            push @revoked,
                { Right => $right, %$display, status => $code, message => $msg };
        }
    }

    $self->response->body(
        JSON::encode_json( { granted => \@granted, revoked => \@revoked } )
    );
    return;
}

sub _find_ace {
    my $self = shift;

    my $principal = $self->_load_principal;
    return undef unless $principal;

    my $ace = RT::ACE->new( $self->current_user );
    $ace->LoadByValues(
        PrincipalId   => $principal->Id,
        PrincipalType => $self->principal_type eq 'user' ? 'User' : 'Group',
        Object        => $self->object,
        RightName     => $self->right_name,
    );

    return $ace->Id ? $ace : undef;
}

sub _load_principal {
    my $self = shift;

    my $type = $self->principal_type;
    my $id   = $self->principal_id;

    if ( $type eq 'group' ) {
        my $group = RT::Group->new( $self->current_user );
        $group->Load($id);
        return $group->PrincipalObj if $group->Id;
    }
    elsif ( $type eq 'user' ) {
        my $user = RT::User->new( $self->current_user );
        $user->Load($id);
        return $user->PrincipalObj if $user->Id;
    }

    return undef;
}

require RT::Base;
RT::Base->_ImportOverlays();

__PACKAGE__->meta->make_immutable;

1;
