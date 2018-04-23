# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2018 Best Practical Solutions, LLC
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

use strict;
use warnings;

package RT::Assets;
use base 'RT::SearchBuilder';

use Role::Basic "with";
with "RT::SearchBuilder::Role::Roles" => { -rename => {RoleLimit => '_RoleLimit'}};

use Scalar::Util qw/blessed/;

=head1 NAME

RT::Assets - a collection of L<RT::Asset> objects

=head1 METHODS

Only additional methods or overridden behaviour beyond the L<RT::SearchBuilder>
(itself a L<DBIx::SearchBuilder>) class are documented below.

=head2 LimitToActiveStatus

=cut

sub LimitToActiveStatus {
    my $self = shift;

    $self->Limit( FIELD => 'Status', VALUE => $_ )
        for RT::Catalog->LifecycleObj->Valid('initial', 'active');
}

=head2 LimitCatalog

Limit Catalog

=cut

sub LimitCatalog {
    my $self = shift;
    my %args = (
        FIELD    => 'Catalog',
        OPERATOR => '=',
        @_
    );

    if ( $args{OPERATOR} eq '=' ) {
        $self->{Catalog} = $args{VALUE};
    }
    $self->SUPER::Limit(%args);
}

=head2 Limit

Defaults CASESENSITIVE to 0

=cut

sub Limit {
    my $self = shift;
    my %args = (
        CASESENSITIVE => 0,
        @_
    );
    $self->SUPER::Limit(%args);
}

=head2 RoleLimit

Re-uses the underlying JOIN, if possible.

=cut

sub RoleLimit {
    my $self = shift;
    my %args = (
        TYPE => '',
        SUBCLAUSE => '',
        OPERATOR => '=',
        @_
    );

    my $key = "role-join-".join("-",map {$args{$_}//''} qw/SUBCLAUSE TYPE OPERATOR/);
    my @ret = $self->_RoleLimit(%args, BUNDLE => $self->{$key} );
    $self->{$key} = \@ret;
}

=head1 INTERNAL METHODS

Public methods which encapsulate implementation details.  You shouldn't need to
call these in normal code.

=head2 AddRecord

Checks the L<RT::Asset> is readable before adding it to the results

=cut

sub AddRecord {
    my $self  = shift;
    my $asset = shift;
    return unless $asset->CurrentUserCanSee;

    return if $asset->__Value('Status') eq 'deleted'
        and not $self->{'allow_deleted_search'};

    $self->SUPER::AddRecord($asset, @_);
}

=head1 PRIVATE METHODS

=head2 _Init

Sets default ordering by Name ascending.

=cut

sub _Init {
    my $self = shift;

    $self->OrderBy( FIELD => 'Name', ORDER => 'ASC' );
    return $self->SUPER::_Init( @_ );
}

sub SimpleSearch {
    my $self = shift;
    my %args = (
        Fields      => RT->Config->Get('AssetSearchFields'),
        Catalog     => RT->Config->Get('DefaultCatalog'),
        Term        => undef,
        @_
    );

    # XXX: We only search a single catalog so that we can map CF names
    # to their ids, as searching CFs by CF name is rather complicated
    # and currently fails in odd ways.  Such a mapping obviously assumes
    # that names are unique within the catalog, but ids are also
    # allowable as well.
    my $catalog;
    if (ref $args{Catalog}) {
        $catalog = $args{Catalog};
    } else {
        $catalog = RT::Catalog->new( $self->CurrentUser );
        $catalog->Load( $args{Catalog} );
    }

    my %cfs;
    my $cfs = $catalog->AssetCustomFields;
    while (my $customfield = $cfs->Next) {
        $cfs{$customfield->id} = $cfs{$customfield->Name}
            = $customfield;
    }

    $self->LimitCatalog( VALUE => $catalog->id );

    while (my ($name, $op) = each %{$args{Fields}}) {
        $op = 'STARTSWITH'
            unless $op =~ /^(?:LIKE|(?:START|END)SWITH|=|!=)$/i;

        if ($name =~ /^CF\.(?:\{(.*)}|(.*))$/) {
            my $cfname = $1 || $2;
            $self->LimitCustomField(
                CUSTOMFIELD     => $cfs{$cfname},
                OPERATOR        => $op,
                VALUE           => $args{Term},
                ENTRYAGGREGATOR => 'OR',
                SUBCLAUSE       => 'autocomplete',
            ) if $cfs{$cfname};
        } elsif ($name eq 'id' and $op =~ /(?:LIKE|(?:START|END)SWITH)$/i) {
            $self->Limit(
                FUNCTION        => "CAST( main.$name AS TEXT )",
                OPERATOR        => $op,
                VALUE           => $args{Term},
                ENTRYAGGREGATOR => 'OR',
                SUBCLAUSE       => 'autocomplete',
            ) if $args{Term} =~ /^\d+$/;
        } else {
            $self->Limit(
                FIELD           => $name,
                OPERATOR        => $op,
                VALUE           => $args{Term},
                ENTRYAGGREGATOR => 'OR',
                SUBCLAUSE       => 'autocomplete',
            ) unless $args{Term} =~ /\D/ and $name eq 'id';
        }
    }
    return $self;
}

sub OrderByCols {
    my $self = shift;
    my @res  = ();

    my $class = $self->_RoleGroupClass;

    for my $row (@_) {
        if ($row->{FIELD} =~ /^(?:CF|CustomField)\.(?:\{(.*)\}|(.*))$/) {
            my $name = $1 || $2;
            my $cf = RT::CustomField->new( $self->CurrentUser );
            $cf->LoadByNameAndCatalog(
                Name => $name,
                Catalog => $self->{'Catalog'},
            );
            if ( $cf->id ) {
                push @res, $self->_OrderByCF( $row, $cf->id, $cf );
            }
        } elsif ($row->{FIELD} =~ /^(\w+)(?:\.(\w+))?$/) {
            my ($role, $subkey) = ($1, $2);
            if ($class->HasRole($role)) {
                $self->{_order_by_role}{ $role }
                        ||= ( $self->_WatcherJoin( Name => $role, Class => $class) )[2];
                push @res, {
                    %$row,
                    ALIAS => $self->{_order_by_role}{ $role },
                    FIELD => $subkey || 'EmailAddress',
                };
            } else {
                push @res, $row;
            }
        } else {
            push @res, $row;
        }
    }
    return $self->SUPER::OrderByCols( @res );
}

=head2 _DoSearch

=head2 _DoCount

Limits to non-deleted assets unless the C<allow_deleted_search> flag is set.

=cut

sub _DoSearch {
    my $self = shift;
    $self->Limit( FIELD => 'Status', OPERATOR => '!=', VALUE => 'deleted', SUBCLAUSE => "not_deleted" )
        unless $self->{'allow_deleted_search'};
    $self->SUPER::_DoSearch(@_);
}

sub _DoCount {
    my $self = shift;
    $self->Limit( FIELD => 'Status', OPERATOR => '!=', VALUE => 'deleted', SUBCLAUSE => "not_deleted" )
        unless $self->{'allow_deleted_search'};
    $self->SUPER::_DoCount(@_);
}

sub Table { "Assets" }

RT::Base->_ImportOverlays();

1;
