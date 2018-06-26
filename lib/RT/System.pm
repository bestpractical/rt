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

=head1 NAME 

RT::System

=head1 DESCRIPTION

RT::System is a simple global object used as a focal point for things
that are system-wide.

It works sort of like an RT::Record, except it's really a single object that has
an id of "1" when instantiated.

This gets used by the ACL system so that you can have rights for the scope "RT::System"

In the future, there will probably be other API goodness encapsulated here.

=cut


package RT::System;

use strict;
use warnings;

use base qw/RT::Record/;

use Role::Basic 'with';
with "RT::Record::Role::Roles",
     "RT::Record::Role::Rights" => { -excludes => [qw/AvailableRights RightCategories/] };

use RT::ACL;
use RT::ACE;
use Data::GUID;

__PACKAGE__->AddRight( Admin   => SuperUser           => 'Do anything and everything'); # loc
__PACKAGE__->AddRight( Staff   => ShowUserHistory     => 'Show history of public user properties'); # loc
__PACKAGE__->AddRight( Admin   => AdminUsers          => 'Create, modify and delete users'); # loc
__PACKAGE__->AddRight( Admin   => AdminCustomRoles    => 'Create, modify and delete custom roles'); # loc
__PACKAGE__->AddRight( Staff   => ModifySelf          => "Modify one's own RT account"); # loc
__PACKAGE__->AddRight( Staff   => ShowArticlesMenu    => 'Show Articles menu'); # loc
__PACKAGE__->AddRight( Admin   => ShowConfigTab       => 'Show Admin menu'); # loc
__PACKAGE__->AddRight( Admin   => ShowApprovalsTab    => 'Show Approvals tab'); # loc
__PACKAGE__->AddRight( Staff   => ShowAssetsMenu      => 'Show Assets menu'); # loc
__PACKAGE__->AddRight( Staff   => ShowGlobalTemplates => 'Show global templates'); # loc
__PACKAGE__->AddRight( General => LoadSavedSearch     => 'Allow loading of saved searches'); # loc
__PACKAGE__->AddRight( General => CreateSavedSearch   => 'Allow creation of saved searches'); # loc
__PACKAGE__->AddRight( Admin   => ExecuteCode         => 'Allow writing Perl code in templates, scrips, etc'); # loc

=head2 AvailableRights

Returns a hashref of available rights for this object.  The keys are the
right names and the values are a description of what the rights do.

This method as well returns rights of other RT objects, like
L<RT::Queue> or L<RT::Group>, to allow users to apply those rights
globally.

If an L<RT::Principal> is passed as the first argument, the available
rights will be limited to ones which make sense for the principal.
Currently only role groups are supported and rights announced by object
types to which the role group doesn't apply are not returned.

=cut

sub AvailableRights {
    my $self = shift;
    my $principal = shift;
    my $class = ref($self) || $self;

    my @rights;
    if ($principal and $principal->IsRoleGroup) {
        my $role = $principal->Object->Name;
        for my $class (keys %RT::ACE::RIGHTS) {
            next unless $class->DOES('RT::Record::Role::Roles') and $class->HasRole($role) and $class ne "RT::System";
            push @rights, values %{ $RT::ACE::RIGHTS{$class} };
        }
    } else {
        @rights = map {values %{$_}} values %RT::ACE::RIGHTS;
    }

    my %rights;
    $rights{$_->{Name}} = $_->{Description} for @rights;

    delete $rights{ExecuteCode} if RT->Config->Get('DisallowExecuteCode');

    return \%rights;
}

=head2 RightCategories

Returns a hashref where the keys are rights for this type of object and the
values are the category (General, Staff, Admin) the right falls into.

=cut

sub RightCategories {
    my $self = shift;
    my $class = ref($self) || $self;

    my %rights;
    $rights{$_->{Name}} = $_->{Category}
        for map {values %{$_}} values %RT::ACE::RIGHTS;
    return \%rights;
}

sub _Init {
    my $self = shift;
    $self->SUPER::_Init (@_) if @_ && $_[0];
}

=head2 id

Returns RT::System's id. It's 1. 

=cut

*Id = \&id;
sub id { return 1 }

sub UID { return "RT::System" }

=head2 Load

Since this object is pretending to be an RT::Record, we need a load method.
It does nothing

=cut

sub Load    { return 1 }
sub Name    { return 'RT System' }
sub __Set   { return 0 }
sub __Value { return 0 }
sub Create  { return 0 }
sub Delete  { return 0 }

sub SubjectTag {
    my $self = shift;
    my $queue = shift;

    return $queue->SubjectTag if $queue;

    my $queues = RT::Queues->new( $self->CurrentUser );
    $queues->Limit( FIELD => 'SubjectTag', OPERATOR => 'IS NOT', VALUE => 'NULL' );
    return $queues->DistinctFieldValues('SubjectTag');
}

=head2 QueueCacheNeedsUpdate ( 1 )

Attribute to decide when SelectQueue needs to flush the list of queues
and retrieve new ones.  Set when queues are created, enabled/disabled
and on certain acl changes.  Should also better understand group management.

If passed a true value, will update the attribute to be the current time.

=cut

sub QueueCacheNeedsUpdate {
    my $self = shift;
    my $update = shift;

    if ($update) {
        return $self->SetAttribute(Name => 'QueueCacheNeedsUpdate', Content => time);
    } else {
        my $cache = $self->FirstAttribute('QueueCacheNeedsUpdate');
        return (defined $cache ? $cache->Content : 0 );
    }
}

=head2 CustomRoleCacheNeedsUpdate ( 1 )

Attribute to decide when we need to flush the list of custom roles
and re-register any changes.  Set when roles are created, enabled/disabled, etc.

If passed a true value, will update the attribute to be the current time.

=cut

sub CustomRoleCacheNeedsUpdate {
    my $self = shift;
    my $update = shift;

    if ($update) {
        return $self->SetAttribute(Name => 'CustomRoleCacheNeedsUpdate', Content => time);
    } else {
        my $cache = $self->FirstAttribute('CustomRoleCacheNeedsUpdate');
        return (defined $cache ? $cache->Content : 0 );
    }
}

=head2 AddUpgradeHistory package, data

Adds an entry to the upgrade history database. The package can be either C<RT>
for core RT upgrades, or the fully qualified name of a plugin. The data must be
a hash reference.

=cut

sub AddUpgradeHistory {
    my $self  = shift;
    my $package = shift;
    my $data  = shift;

    $data->{timestamp}  ||= time;
    $data->{rt_version} ||= $RT::VERSION;

    my $upgrade_history_attr = $self->FirstAttribute('UpgradeHistory');
    my $upgrade_history = $upgrade_history_attr ? $upgrade_history_attr->Content : {};

    push @{ $upgrade_history->{$package} }, $data;

    $self->SetAttribute(
        Name    => 'UpgradeHistory',
        Content => $upgrade_history,
    );
}

=head2 UpgradeHistory [package]

Returns the entries of RT's upgrade history. If a package is specified, the list
of upgrades for that package will be returned. Otherwise a hash reference of
C<< package => [upgrades] >> will be returned.

=cut

sub UpgradeHistory {
    my $self  = shift;
    my $package = shift;

    my $upgrade_history_attr = $self->FirstAttribute('UpgradeHistory');
    my $upgrade_history = $upgrade_history_attr ? $upgrade_history_attr->Content : {};

    if ($package) {
        return @{ $upgrade_history->{$package} || [] };
    }

    return $upgrade_history;
}

sub ParsedUpgradeHistory {
    my $self = shift;
    my $package = shift;

    my $version_status = "Current version: ";
    if ( $package eq 'RT' ){
        $version_status .= $RT::VERSION;
    } elsif ( grep {/$package/} @{RT->Config->Get('Plugins')} ) {
        no strict 'refs';
        $version_status .= ${ $package . '::VERSION' };
    } else {
        $version_status = "Not currently loaded";
    }

    my %ids;
    my @lines;

    my @events = $self->UpgradeHistory( $package );
    for my $event (@events) {
        if ($event->{stage} eq 'before' or (($event->{action}||'') eq 'insert' and not $event->{full_id})) {
            if (not $event->{full_id}) {
                # For upgrade done in the 4.1 series without GUIDs
                if (($event->{type}||'') eq 'full upgrade') {
                    $event->{full_id} = $event->{individual_id} = Data::GUID->new->as_string;
                } else {
                    $event->{individual_id} = Data::GUID->new->as_string;
                    $event->{full_id} = (@lines ? $lines[-1]{full_id} : Data::GUID->new->as_string);
                }
                $event->{return_value} = [1] if $event->{stage} eq 'after';
            }
            if ($ids{$event->{full_id}}) {
                my $kids = $ids{$event->{full_id}}{sub_events} ||= [];
                # Stitch non-"upgrade"s beneath the previous "upgrade"
                if ( @{$kids} and $event->{action} ne 'upgrade' and $kids->[-1]{action} eq 'upgrade') {
                    push @{ $kids->[-1]{sub_events} }, $event;
                } else {
                    push @{ $kids }, $event;
                }
            } else {
                push @lines, $event;
            }
            $ids{$event->{individual_id}} = $event;
        } elsif ($event->{stage} eq 'after') {
            if (not $event->{individual_id}) {
                if (($event->{type}||'') eq 'full upgrade') {
                    $lines[-1]{end} = $event->{timestamp} if @lines;
                } elsif (($event->{type}||'') eq 'individual upgrade') {
                    $lines[-1]{sub_events}[-1]{end} = $event->{timestamp}
                        if @lines and @{ $lines[-1]{sub_events} };
                }
            } elsif ($ids{$event->{individual_id}}) {
                my $end = $event;
                $event = $ids{$event->{individual_id}};
                $event->{end} = $end->{timestamp};

                $end->{return_value} = [ split ', ', $end->{return_value}, 2 ]
                    if $end->{return_value} and not ref $end->{return_value};
                $event->{return_value} = $end->{return_value};
                $event->{content} ||= $end->{content};
            }
        }
    }

    return ($version_status, @lines);
}

=head2 ExternalStorage

Accessor for the storage engine selected by L<RT::ExternalStorage>. Will
be undefined if external storage is not configured.

=cut

sub ExternalStorage {
    my $self = shift;
    if (@_) {
        $self->{ExternalStorage} = shift;
    }
    return $self->{ExternalStorage};
}

=head2 ExternalStorageURLFor object

Returns a URL for direct linking to an L<RT::ExternalStorage>
engine. Will return C<undef> if external storage is not configured, or
if direct linking is disabled in config (C<$ExternalStorageDirectLink>),
or if the external storage engine doesn't support hyperlinking (as in
L<RT::ExternalStorage::Disk>), or finally, if the object is for whatever
reason not present in external storage.

=cut

sub ExternalStorageURLFor {
    my $self = shift;
    my $Object = shift;

    # external storage not configured
    return undef if !$self->ExternalStorage;

    # external storage direct links disabled
    return undef if !RT->Config->Get('ExternalStorageDirectLink');

    return undef unless $Object->ContentEncoding eq 'external';

    return $self->ExternalStorage->DownloadURLFor($Object);
}

RT::Base->_ImportOverlays();

1;
