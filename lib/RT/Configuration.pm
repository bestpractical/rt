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

use strict;
use warnings;
use 5.10.1;

package RT::Configuration;
use base 'RT::Record';

use Storable ();
use MIME::Base64;
use JSON ();

=head1 NAME

RT::Configuration - Represents a config setting

=cut

=head1 METHODS

=head2 Create PARAMHASH

Create takes a hash of values and creates a row in the database.  Available
keys are:

=over 4

=item Name

Must be unique.

=item Content

If you provide a reference, we will automatically serialize the data structure
using L<Storable>. Otherwise any string is passed through as-is.

=item ContentType

Currently handles C<perl> or C<application/json>.

=back

Returns a tuple of (status, msg) on failure and (id, msg) on success.
Also automatically propagates this config change to all server processes.

=cut

sub Create {
    my $self = shift;
    my %args = (
        Name => '',
        Content => '',
        ContentType => '',
        @_,
    );

    return (0, $self->loc("Permission Denied"))
        unless $self->CurrentUserHasRight('SuperUser');

    if ( $args{'Name'} ) {
        my ( $ok, $msg ) = $self->ValidateName( $args{'Name'} );
        unless ($ok) {
            return ($ok, $msg);
        }
    }
    else {
        return ( 0, $self->loc("Must specify 'Name' attribute") );
    }


    $RT::Handle->BeginTransaction;
    my ( $id, $msg ) = $self->_Create(%args);
    unless ($id) {
        $RT::Handle->Rollback;
        return ($id, $msg);
    }

    my ($content, $error) = $self->Content;
    unless (defined($content) && length($content)) {
        $content = $self->loc('(no value)');
    }

    my ( $Trans, $tx_msg, $TransObj ) = $self->_NewTransaction(
        Type => 'SetConfig',
        Field => $self->Name,
        ObjectType => 'RT::Configuration',
        ObjectId => $self->id,
        ReferenceType => ref($self),
        NewReference => $self->id,
    );
    unless ($Trans) {
        $RT::Handle->Rollback;
        return (0, $self->loc("Setting [_1] to [_2] failed: [_3]", $args{Name}, $content, $tx_msg));
    }

    $RT::Handle->Commit;
    RT->Config->ApplyConfigChangeToAllServerProcesses;

    my $old_value = RT->Config->Get($args{Name});
    if ( ref $old_value ) {
        $old_value = $self->_SerializeContent($old_value);
    }
    RT->Logger->info($self->CurrentUser->Name . " changed " . $args{Name});
    return ( $id, $self->loc( '[_1] changed from "[_2]" to "[_3]"', $self->Name, $old_value // '', $content // '' ) );
}

=head2 CurrentUserCanSee

Returns true if the current user can see the database setting

=cut

sub CurrentUserCanSee {
    my $self = shift;

    return $self->CurrentUserHasRight('SuperUser');
}

=head2 Load

Load a setting from the database. Takes a single argument. If the
argument is numerical, load by the column 'id'. Otherwise, load by the
"Name" column.

=cut

sub Load {
    my $self = shift;
    my $identifier = shift || return undef;

    if ( $identifier !~ /\D/ ) {
        return $self->SUPER::LoadById( $identifier );
    } else {
        return $self->LoadByCol( "Name", $identifier );
    }
}

=head2 SetName

Not permitted

=cut

sub SetName {
    my $self = shift;
    return (0, $self->loc("Permission Denied"));
}

=head2 ValidateName

Returns either (0, "failure reason") or 1 depending on whether the given
name is valid.

=cut

sub ValidateName {
    my $self = shift;
    my $name = shift;

    return ( 0, $self->loc('empty name') ) unless defined $name && length $name;

    my $TempSetting  = RT::Configuration->new( RT->SystemUser );
    $TempSetting->LoadByCols(Name => $name, Disabled => 0);

    if ( $TempSetting->id && ( !$self->id || $TempSetting->id != $self->id ) ) {
        return ( 0, $self->loc('Name in use') );
    }
    else {
        return 1;
    }
}

=head2 Delete

Checks ACL, and on success propagates this config change to all server
processes.

=cut

sub Delete {
    my $self = shift;
    return (0, $self->loc("Permission Denied")) unless $self->CurrentUserCanSee;

    $RT::Handle->BeginTransaction;
    my ( $ok, $msg ) = $self->SetDisabled( 1 );
    unless ($ok) {
        $RT::Handle->Rollback;
        return ($ok, $msg);
    }

    my ( $Trans, $tx_msg, $TransObj ) = $self->_NewTransaction(
        Type => 'DeleteConfig',
        Field => $self->Name,
        ObjectType => 'RT::Configuration',
        ObjectId => $self->Id,
        ReferenceType => ref($self),
        OldReference => $self->id,
    );

    unless ($Trans) {
        $RT::Handle->Rollback();
        return ( 0, $self->loc( "Deleting [_1] failed: [_2]", $self->Name, $tx_msg ) );
    }

    $RT::Handle->Commit;
    RT->Config->ApplyConfigChangeToAllServerProcesses;
    RT->Logger->info($self->CurrentUser->Name . " removed database setting for " . $self->Name);

    return ($ok, $self->loc("Database setting removed."));
}

=head2 DecodedContent

Returns a pair of this setting's content and any error.

=cut

sub DecodedContent {
    my $self = shift;

    # Here we call _Value to run the ACL check.
    my $content = $self->_Value('Content');

    my $type = $self->__Value('ContentType') || '';

    if ($type eq 'perl') {
        return $self->_DeserializeContent($content);
    }
    elsif ($type eq 'application/json') {
        return $self->_DeJSONContent($content);
    }

    return ($content, "");
}

=head2 SetContent

=cut

sub SetContent {
    my $self         = shift;
    my $raw_value    = shift;
    my $content_type = shift || '';

    return (0, $self->loc("Permission Denied")) unless $self->CurrentUserCanSee;

    my ( $ok, $msg ) = $self->ValidateContent( Content => $raw_value );
    return ( 0, $msg ) unless $ok;

    my $value = $raw_value;
    if (ref $value) {
        $value = $self->_SerializeContent($value, $self->Name);
        $content_type = 'perl';
    }
    if ($self->Content eq $value) {
        return (0, $self->loc("[_1] update: Nothing changed", ucfirst($self->Name)));
    }

    $RT::Handle->BeginTransaction;
    ( $ok, $msg ) = $self->SetDisabled( 1 );
    unless ($ok) {
        $RT::Handle->Rollback;
        return ($ok, $msg);
    }

    my ($old_value, $error) = $self->Content;
    my $old_id = $self->id;
    my ( $new_id, $new_msg ) = $self->_Create(
        Name => $self->Name,
        Content => $raw_value,
        ContentType => $content_type,
    );

    unless ($new_id) {
        $RT::Handle->Rollback;
        return (0, $self->loc("Setting [_1] to [_2] failed: [_3]", $self->Name, $value, $new_msg));
    }

    unless (defined($value) && length($value)) {
        $value = $self->loc('(no value)');
    }

    my ( $Trans, $tx_msg, $TransObj ) = $self->_NewTransaction(
        Type => 'SetConfig',
        Field => $self->Name,
        ObjectType => 'RT::Configuration',
        ObjectId => $new_id,
        ReferenceType => ref($self),
        OldReference => $old_id,
        NewReference => $new_id,
    );
    unless ($Trans) {
        $RT::Handle->Rollback();
        return (0, $self->loc("Setting [_1] to [_2] failed: [_3]", $self->Name, $value, $tx_msg));
    }

    $RT::Handle->Commit;
    RT->Config->ApplyConfigChangeToAllServerProcesses;

    RT->Logger->info($self->CurrentUser->Name . " changed " . $self->Name);
    unless (defined($old_value) && length($old_value)) {
        $old_value = $self->loc('(no value)');
    }

    return( 1, $self->loc('[_1] changed from "[_2]" to "[_3]"', $self->Name, $old_value // '', $value // '') );

}

=head2 ValidateContent

Returns either (0, "failure reason") or 1 depending on whether the given
content is valid.

=cut

sub ValidateContent {
    my $self = shift;
    my %args = @_ == 1 ? ( Content => @_ ) : @_;
    $args{Name} ||= $self->Name;

    # Validate methods are automatically called on Create by RT::Record.
    # Sadly we have to skip that because it doesn't pass other field values,
    # which we need here, as content type depends on the config name.
    # We need to explicitly call Validate ourselves instead.
    return 1 unless $args{Name};

    my $meta = RT->Config->Meta( $args{Name} );
    if ( my $type = $meta->{Type} ) {
        if (   ( $type eq 'ARRAY' && ref $args{Content} ne 'ARRAY' )
            || ( $type eq 'HASH' && ref $args{Content} ne 'HASH' ) )
        {
            return ( 0, $self->loc( 'Invalid value for [_1], should be of type [_2]', $args{Name}, $type ) );
        }
    }
    return ( 1, $self->loc('Content valid') );
}

=head1 PRIVATE METHODS

Documented for internal use only, do not call these from outside
RT::Configuration itself.

=head2 _Create

Checks that the field being created/updated is not immutable, before calling
C<SUPER::Create> to save changes in a new row, returning id of new row on success
 and 0, and message on failure.

=cut

sub _Create {
    my $self = shift;
    my %args = (
        Name => '',
        Content => '',
        ContentType => '',
        @_
    );
    my $meta = RT->Config->Meta($args{'Name'});
    if ($meta->{Immutable}) {
        return ( 0, $self->loc("You cannot update [_1] using database config; you must edit your site config", $args{'Name'}) );
    }

    if ( ref( $args{'Content'} ) ) {
        $args{'Content'} = $self->_SerializeContent( $args{'Content'}, $args{'Name'} );
        $args{'ContentType'} = 'perl';
    }

    my ( $id, $msg ) = $self->SUPER::Create(
        map { $_ => $args{$_} } qw(Name Content ContentType),
    );
    unless ($id) {
        return (0, $self->loc("Setting [_1] to [_2] failed: [_3]", $args{Name}, $args{Content}, $msg));
    }

    return ($id, $msg);
}


=head2 _Set

Checks if the current user has I<SuperUser> before calling
C<SUPER::_Set>, and then propagates this config change to all server processes.

=cut

sub _Set {
    my $self = shift;
    my %args = (
        Field => undef,
        Value => undef,
        @_
    );

    return (0, $self->loc("Permission Denied"))
        unless $self->CurrentUserCanSee;

    my ($ok, $msg) = $self->SUPER::_Set(@_);
    RT->Config->ApplyConfigChangeToAllServerProcesses;
    return ($ok, $msg);
}

=head2 _Value

Checks L</CurrentUserCanSee> before calling C<SUPER::_Value>.

=cut

sub _Value {
    my $self = shift;
    return unless $self->CurrentUserCanSee;
    return $self->SUPER::_Value(@_);
}

sub _SerializeContent {
    my $self = shift;
    my $content = shift;
    require Data::Dumper;
    local $Data::Dumper::Terse = 1;
    local $Data::Dumper::Sortkeys = 1;
    my $frozen = Data::Dumper::Dumper($content);
    chomp $frozen;
    return $frozen;
}

sub _DeserializeContent {
    my $self = shift;
    my $content = shift;

    my $thawed = eval "$content";
    if (my $error = $@) {
        $RT::Logger->error("Perl deserialization of database setting " . $self->Name . " failed: $error");
        return (undef, $self->loc("Perl deserialization of database setting [_1] failed: [_2]", $self->Name, $error));
    }

    return $thawed;
}

sub _DeJSONContent {
    my $self = shift;
    my $content = shift;

    my $thawed = eval { JSON::from_json($content) };
    if (my $error = $@) {
        $RT::Logger->error("JSON deserialization of database setting " . $self->Name . " failed: $error");
        return (undef, $self->loc("JSON deserialization of database setting [_1] failed: [_2]", $self->Name, $error));
    }

    return $thawed;
}

sub Table { "Configurations" }

sub _CoreAccessible {
    {
        id            => { read => 1, type => 'int(11)',        default => '' },
        Name          => { read => 1, sql_type => 12, length => 255,  is_blob => 0,  is_numeric => 0,  type => 'varchar(255)', default => ''},
        Content       => { read => 1, write => 1, sql_type => -4, length => 0,  is_blob => 1,  is_numeric => 0,  type => 'blob', default => ''},
        ContentType   => { read => 1, write => 1, sql_type => 12, length => 16,  is_blob => 0,  is_numeric => 0,  type => 'varchar(16)', default => ''},
        Disabled      => { read => 1, write => 1, sql_type => 5, length => 6,  is_blob => 0,  is_numeric => 1,  type => 'smallint(6)', default => '0'},
        Creator       => { read => 1, type => 'int(11)',        default => '0', auto => 1 },
        Created       => { read => 1, type => 'datetime',       default => '',  auto => 1 },
        LastUpdatedBy => { read => 1, type => 'int(11)',        default => '0', auto => 1 },
        LastUpdated   => { read => 1, type => 'datetime',       default => '',  auto => 1 },
    }
}

1;

