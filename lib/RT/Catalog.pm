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

package RT::Catalog;
use base 'RT::Record';

use Role::Basic 'with';
with "RT::Record::Role::Lifecycle",
     "RT::Record::Role::Roles" => {
         -rename => {
             # We provide ACL'd wraps of these.
             AddRoleMember    => "_AddRoleMember",
             DeleteRoleMember => "_DeleteRoleMember",
             RoleGroup        => "_RoleGroup",
         },
     },
     "RT::Record::Role::Rights";

require RT::ACE;

=head1 NAME

RT::Catalog - A logical set of assets

=cut

# For the Lifecycle role
sub LifecycleType { "asset" }

# Setup rights
__PACKAGE__->AddRight( General => ShowCatalog  => 'See catalogs' ); #loc
__PACKAGE__->AddRight( Admin   => AdminCatalog => 'Create, modify, and disable catalogs' ); #loc

__PACKAGE__->AddRight( General => ShowAsset    => 'See assets' ); #loc
__PACKAGE__->AddRight( Staff   => CreateAsset  => 'Create assets' ); #loc
__PACKAGE__->AddRight( Staff   => ModifyAsset  => 'Modify assets' ); #loc

__PACKAGE__->AddRight( General => SeeCustomField        => 'View custom field values' ); # loc
__PACKAGE__->AddRight( Staff   => ModifyCustomField     => 'Modify custom field values' ); # loc
__PACKAGE__->AddRight( Staff   => SetInitialCustomField => 'Add custom field values only at object creation time'); # loc

RT::ACE->RegisterCacheHandler(sub {
    my %args = (
        Action      => "",
        RightName   => "",
        @_
    );

    return unless $args{Action}    =~ /^(Grant|Revoke)$/i
              and $args{RightName} =~ /^(ShowCatalog|CreateAsset)$/;

    RT::Catalog->CacheNeedsUpdate(1);
});

=head1 DESCRIPTION

Catalogs are for assets what queues are for tickets or classes are for
articles.

It announces the rights for assets, and rights are granted at the catalog or
global level.  Asset custom fields are either applied globally to all Catalogs
or individually to specific Catalogs.

=over 4

=item id

=item Name

Limited to 255 characters.

=item Description

Limited to 255 characters.

=item Lifecycle

=item Disabled

=item Creator

=item Created

=item LastUpdatedBy

=item LastUpdated

=back

All of these are readable through methods of the same name and mutable through
methods of the same name with C<Set> prefixed.  The last four are automatically
managed.

=head1 METHODS

=head2 Load ID or NAME

Loads the specified Catalog into the current object.

=cut

sub Load {
    my $self = shift;
    my $id   = shift;
    return unless $id;

    if ( $id =~ /\D/ ) {
        return $self->LoadByCols( Name => $id );
    }
    else {
        return $self->SUPER::Load($id);
    }
}

=head2 Create PARAMHASH

Create takes a hash of values and creates a row in the database.  Available keys are:

=over 4

=item Name

=item Description

=item Lifecycle

=item HeldBy, Contact

A single principal ID or array ref of principal IDs to add as members of the
respective role groups for the new catalog.

User Names and EmailAddresses may also be used, but Groups must be referenced
by ID.

=item Disabled

=back

Returns a tuple of (status, msg) on failure and (id, msg, non-fatal errors) on
success, where the third value is an array reference of errors that occurred
but didn't prevent creation.

=cut

sub Create {
    my $self = shift;
    my %args = (
        Name            => '',
        Description     => '',
        Lifecycle       => 'assets',

        HeldBy          => undef,
        Contact         => undef,

        Disabled        => 0,

        @_
    );
    my @non_fatal_errors;

    return (0, $self->loc("Permission Denied"))
        unless $self->CurrentUserHasRight('AdminCatalog');

    return (0, $self->loc('Invalid Name (names must be unique and may not be all digits)'))
        unless $self->ValidateName( $args{'Name'} );

    $args{'Lifecycle'} ||= 'assets';

    return (0, $self->loc('[_1] is not a valid lifecycle', $args{'Lifecycle'}))
        unless $self->ValidateLifecycle( $args{'Lifecycle'} );

    RT->DatabaseHandle->BeginTransaction();

    my ( $id, $msg ) = $self->SUPER::Create(
        map { $_ => $args{$_} } qw(Name Description Lifecycle Disabled),
    );
    unless ($id) {
        RT->DatabaseHandle->Rollback();
        return (0, $self->loc("Catalog create failed: [_1]", $msg));
    }

    # Create role groups
    unless ($self->_CreateRoleGroups()) {
        RT->Logger->error("Couldn't create role groups for catalog ". $self->id);
        RT->DatabaseHandle->Rollback();
        return (0, $self->loc("Couldn't create role groups for catalog"));
    }

    # Figure out users for roles
    my $roles = {};
    push @non_fatal_errors, $self->_ResolveRoles( $roles, %args );
    push @non_fatal_errors, $self->_AddRolesOnCreate( $roles, map { $_ => sub {1} } $self->Roles );

    # Create transaction
    my ( $txn_id, $txn_msg, $txn ) = $self->_NewTransaction( Type => 'Create' );
    unless ($txn_id) {
        RT->DatabaseHandle->Rollback();
        return (0, $self->loc( 'Catalog Create txn failed: [_1]', $txn_msg ));
    }

    $self->CacheNeedsUpdate(1);
    RT->DatabaseHandle->Commit();

    return ($id, $self->loc('Catalog #[_1] created: [_2]', $self->id, $args{'Name'}), \@non_fatal_errors);
}

=head2 ValidateName NAME

Requires that Names contain at least one non-digit and doesn't already exist.

=cut

sub ValidateName {
    my $self = shift;
    my $name = shift;
    return 0 unless defined $name and length $name;
    return 0 unless $name =~ /\D/;

    my $catalog = RT::Catalog->new( RT->SystemUser );
    $catalog->Load($name);
    return 0 if $catalog->id;

    return 1;
}

=head2 Delete

Catalogs may not be deleted.  Always returns failure.

You should disable the catalog instead using C<< $catalog->SetDisabled(1) >>.

=cut

sub Delete {
    my $self = shift;
    return (0, $self->loc("Catalogs may not be deleted"));
}

=head2 CurrentUserCanSee

Returns true if the current user can see the catalog via the I<ShowCatalog> or
I<AdminCatalog> rights.

=cut

sub CurrentUserCanSee {
    my $self = shift;
    return $self->CurrentUserHasRight('ShowCatalog')
        || $self->CurrentUserHasRight('AdminCatalog');
}

=head2 Owner

Returns an L<RT::User> object for this catalog's I<Owner> role group.  On error,
returns undef.

=head2 HeldBy

Returns an L<RT::Group> object for this catalog's I<HeldBy> role group.  The object
may be unloaded if permissions aren't satisfied.

=head2 Contacts

Returns an L<RT::Group> object for this catalog's I<Contact> role
group.  The object may be unloaded if permissions aren't satisfied.

=cut

sub Owner {
    my $self  = shift;
    my $group = $self->RoleGroup("Owner");
    return unless $group and $group->id;
    return $group->UserMembersObj->First;
}
sub HeldBy   { $_[0]->RoleGroup("HeldBy")  }
sub Contacts { $_[0]->RoleGroup("Contact") }

=head2 AddRoleMember

Checks I<AdminCatalog> before calling L<RT::Record::Role::Roles/_AddRoleMember>.

=cut

sub AddRoleMember {
    my $self = shift;

    return (0, $self->loc("No permission to modify this catalog"))
        unless $self->CurrentUserHasRight("AdminCatalog");

    return $self->_AddRoleMember(@_);
}

=head2 DeleteRoleMember

Checks I<AdminCatalog> before calling L<RT::Record::Role::Roles/_DeleteRoleMember>.

=cut

sub DeleteRoleMember {
    my $self = shift;

    return (0, $self->loc("No permission to modify this catalog"))
        unless $self->CurrentUserHasRight("AdminCatalog");

    return $self->_DeleteRoleMember(@_);
}

=head2 RoleGroup

An ACL'd version of L<RT::Record::Role::Roles/_RoleGroup>.  Checks I<ShowCatalog>.

=cut

sub RoleGroup {
    my $self = shift;
    if ($self->CurrentUserCanSee) {
        return $self->_RoleGroup(@_);
    } else {
        return RT::Group->new( $self->CurrentUser );
    }
}

=head2 AssetCustomFields

Returns an L<RT::CustomFields> object containing all global and
catalog-specific B<asset> custom fields.

=cut

sub AssetCustomFields {
    my $self = shift;
    my $cfs  = RT::CustomFields->new( $self->CurrentUser );
    if ($self->CurrentUserCanSee) {
        $cfs->SetContextObject( $self );
        $cfs->LimitToGlobalOrObjectId( $self->Id );
        $cfs->LimitToLookupType( RT::Asset->CustomFieldLookupType );
        $cfs->ApplySortOrder;
    } else {
        $cfs->Limit( FIELD => 'id', VALUE => 0, SUBCLAUSE => 'acl' );
    }
    return ($cfs);
}

=head1 INTERNAL METHODS

=head2 CacheNeedsUpdate

Takes zero or one arguments.

If a true argument is provided, marks any Catalog caches as needing an update.
This happens when catalogs are created, disabled/enabled, or modified.  Returns
nothing.

If no arguments are provided, returns an epoch time that any catalog caches
should be newer than.

May be called as a class or object method.

=cut

sub CacheNeedsUpdate {
    my $class  = shift;
    my $update = shift;

    if ($update) {
        RT->System->SetAttribute(Name => 'CatalogCacheNeedsUpdate', Content => time);
        return;
    } else {
        my $attribute = RT->System->FirstAttribute('CatalogCacheNeedsUpdate');
        return $attribute ? $attribute->Content : 0;
    }
}

=head1 PRIVATE METHODS

Documented for internal use only, do not call these from outside RT::Catalog
itself.

=head2 _Set

Checks if the current user can I<AdminCatalog> before calling C<SUPER::_Set>
and records a transaction against this object if C<SUPER::_Set> was
successful.

=cut

sub _Set {
    my $self = shift;
    my %args = (
        Field => undef,
        Value => undef,
        @_
    );

    return (0, $self->loc("Permission Denied"))
        unless $self->CurrentUserHasRight('AdminCatalog');

    my $old = $self->_Value( $args{'Field'} );

    my ($ok, $msg) = $self->SUPER::_Set(@_);

    # Only record the transaction if the _Set worked
    return ($ok, $msg) unless $ok;

    my $txn_type = "Set";
    if ($args{'Field'} eq "Disabled") {
        if (not $old and $args{'Value'}) {
            $txn_type = "Disabled";
        }
        elsif ($old and not $args{'Value'}) {
            $txn_type = "Enabled";
        }
    }

    $self->CacheNeedsUpdate(1);

    my ($txn_id, $txn_msg, $txn) = $self->_NewTransaction(
        Type     => $txn_type,
        Field    => $args{'Field'},
        NewValue => $args{'Value'},
        OldValue => $old,
    );
    return ($txn_id, scalar $txn->BriefDescription);
}

=head2 _Value

Checks L</CurrentUserCanSee> before calling C<SUPER::_Value>.

=cut

sub _Value {
    my $self = shift;
    return unless $self->CurrentUserCanSee;
    return $self->SUPER::_Value(@_);
}

sub Table { "Catalogs" }

sub _CoreAccessible {
    {
        id            => { read => 1, type => 'int(11)',        default => '' },
        Name          => { read => 1, type => 'varchar(255)',   default => '',          write => 1 },
        Description   => { read => 1, type => 'varchar(255)',   default => '',          write => 1 },
        Lifecycle     => { read => 1, type => 'varchar(32)',    default => 'assets',    write => 1 },
        Disabled      => { read => 1, type => 'int(2)',         default => '0',         write => 1 },
        Creator       => { read => 1, type => 'int(11)',        default => '0', auto => 1 },
        Created       => { read => 1, type => 'datetime',       default => '',  auto => 1 },
        LastUpdatedBy => { read => 1, type => 'int(11)',        default => '0', auto => 1 },
        LastUpdated   => { read => 1, type => 'datetime',       default => '',  auto => 1 },
    }
}

sub FindDependencies {
    my $self = shift;
    my ($walker, $deps) = @_;

    $self->SUPER::FindDependencies($walker, $deps);

    # Role groups( HeldBy, Contact)
    my $objs = RT::Groups->new( $self->CurrentUser );
    $objs->Limit( FIELD => 'Domain', VALUE => 'RT::Catalog-Role', CASESENSITIVE => 0 );
    $objs->Limit( FIELD => 'Instance', VALUE => $self->Id );
    $deps->Add( in => $objs );

    # Custom Fields on assets _in_ this catalog
    $objs = RT::ObjectCustomFields->new( $self->CurrentUser );
    $objs->Limit( FIELD           => 'ObjectId',
                  OPERATOR        => '=',
                  VALUE           => $self->id,
                  ENTRYAGGREGATOR => 'OR' );
    $objs->Limit( FIELD           => 'ObjectId',
                  OPERATOR        => '=',
                  VALUE           => 0,
                  ENTRYAGGREGATOR => 'OR' );
    my $cfs = $objs->Join(
        ALIAS1 => 'main',
        FIELD1 => 'CustomField',
        TABLE2 => 'CustomFields',
        FIELD2 => 'id',
    );
    $objs->Limit( ALIAS    => $cfs,
                  FIELD    => 'LookupType',
                  OPERATOR => 'STARTSWITH',
                  VALUE    => 'RT::Catalog-' );
    $deps->Add( in => $objs );

    # Assets
    $objs = RT::Assets->new( $self->CurrentUser );
    $objs->Limit( FIELD => "Catalog", VALUE => $self->Id );
    $objs->{allow_deleted_search} = 1;
    $deps->Add( in => $objs );

}

sub PreInflate {
    my $class = shift;
    my ( $importer, $uid, $data ) = @_;

    $class->SUPER::PreInflate( $importer, $uid, $data );
    $data->{Name} = $importer->Qualify( $data->{Name} );

    return if $importer->MergeBy( "Name", $class, $uid, $data );
    return 1;
}

RT::Base->_ImportOverlays();

1;
