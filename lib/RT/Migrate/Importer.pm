# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2016 Best Practical Solutions, LLC
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

package RT::Migrate::Importer;

use strict;
use warnings;

use Storable qw//;
use File::Spec;
use Carp qw/carp/;

=head1 NAME

RT::Migrate::Importer - 

=head1 SYNOPSIS



=head1 DESCRIPTION



=cut

sub new {
    my $class = shift;
    my $self = bless {}, $class;
    $self->Init(@_);
    return $self;
}

sub Init {
    my $self = shift;
    my %args = (
        OriginalId          => undef,
        Progress            => undef,
        Statefile           => undef,
        DumpObjects         => undef,
        HandleError         => undef,
        ExcludeOrganization => undef,
        @_,
    );

    # Should we attempt to preserve record IDs as they are created?
    $self->{OriginalId} = $args{OriginalId};

    $self->{ExcludeOrganization} = $args{ExcludeOrganization};

    $self->{Progress} = $args{Progress};

    $self->{HandleError} = sub { 0 };
    $self->{HandleError} = $args{HandleError}
        if $args{HandleError} and ref $args{HandleError} eq 'CODE';

    if ($args{DumpObjects}) {
        require Data::Dumper;
        $self->{DumpObjects} = { map { $_ => 1 } @{$args{DumpObjects}} };
    }

    # Objects we've created
    $self->{UIDs} = {};

    # Columns we need to update when an object is later created
    $self->{Pending} = {};

    # Objects missing from the source database before serialization
    $self->{Invalid} = [];

    # What we created
    $self->{ObjectCount} = {};

    # To know what global CFs need to be unglobal'd and applied to what
    $self->{NewQueues} = [];
    $self->{NewCFs} = [];
}

sub Import {
    die "Abstract base class; use RT::Migrate::Importer::File";
}

=head2 Metadata

Returns metadata (e.g. C<Organization>, C<Clone>, C<Incremental>) about the import
stream as a hash reference.

=cut

sub Metadata {
    my $self = shift;
    return $self->{Metadata};
}

=head2 LoadMetadata C<DATA>

Reads important metadata from the import stream from C<DATA> and validates
that its version is compatible. See L</Metadata>.

=cut

sub LoadMetadata {
    my $self = shift;
    my ($data) = @_;

    return if $self->{Metadata};
    $self->{Metadata} = $data;

    die "Incompatible format version: ".$data->{Format}
        if $data->{Format} ne "0.8";

    $self->{Organization} = $data->{Organization};
    $self->{Clone}        = $data->{Clone};
    $self->{Incremental}  = $data->{Incremental};
    $self->{Files}        = $data->{Files} if $data->{Final};
}

=head2 InitStream

Sets up the initial state to begin importing data.

=cut

sub InitStream {
    my $self = shift;

    die "Stream initialized after objects have been recieved!"
        if keys %{ $self->{UIDs} };

    die "Cloning does not support importing the Original Id separately\n"
        if $self->{OriginalId} and $self->{Clone};

    die "RT already contains data; overwriting will not work\n"
        if ($self->{Clone} and not $self->{Incremental})
            and RT->SystemUser->Id;

    # Basic facts of life, as a safety net
    $self->Resolve( RT->System->UID => ref RT->System, RT->System->Id );
    $self->SkipTransactions( RT->System->UID );

    if ($self->{OriginalId}) {
        # Where to shove the original ticket ID
        my $cf = RT::CustomField->new( RT->SystemUser );
        $cf->LoadByName( Name => $self->{OriginalId}, LookupType => RT::Ticket->CustomFieldLookupType, ObjectId => 0 );
        unless ($cf->Id) {
            warn "Failed to find global CF named $self->{OriginalId} -- creating one";
            $cf->Create(
                Queue => 0,
                Name  => $self->{OriginalId},
                Type  => 'FreeformSingle',
            );
        }
    }
}

=head2 Resolve C<UID>, C<CLASS>, C<ID>

Called when an object has been successfully created in the database, and
thus the C<UID> has been locally resolved to the given C<CLASS> and
C<ID>.  Calling this automatically triggers any pending column updates
that were waiting on the C<UID> to be completely resolved.

=cut

sub Resolve {
    my $self = shift;
    my ($uid, $class, $id) = @_;
    $self->{UIDs}{$uid} = [ $class, $id ];
    return unless $self->{Pending}{$uid};

    for my $ref (@{$self->{Pending}{$uid}}) {
        my ($pclass, $pid) = @{ $self->Lookup( $ref->{uid} ) };
        my $obj = $pclass->new( RT->SystemUser );
        $obj->LoadByCols( Id => $pid );
        $obj->__Set(
            Field => $ref->{column},
            Value => $id,
        ) if defined $ref->{column};
        $obj->__Set(
            Field => $ref->{classcolumn},
            Value => $class,
        ) if defined $ref->{classcolumn};
        $obj->__Set(
            Field => $ref->{uri},
            Value => $self->LookupObj($uid)->URI,
        ) if defined $ref->{uri};
        if (my $method = $ref->{method}) {
            $obj->$method($self, $ref, $class, $id);
        }
    }
    delete $self->{Pending}{$uid};
}

=head2 Lookup C<UID>

Returns an array reference of C<[ CLASS, ID ]> if the C<UID> has been
resolved, or undefined if it has not yet been created locally.

=cut

sub Lookup {
    my $self = shift;
    my ($uid) = @_;
    unless (defined $uid) {
        carp "Tried to lookup an undefined UID";
        return;
    }
    return $self->{UIDs}{$uid};
}

=head2 LookupObj C<UID>

Returns an object if the C<UID> has been resolved locally, or undefined
if it has not been.

=cut

sub LookupObj {
    my $self = shift;
    my ($uid) = @_;
    my $ref = $self->Lookup( $uid );
    return unless $ref;
    my ($class, $id) = @{ $ref };

    my $obj = $class->new( RT->SystemUser );
    $obj->Load( $id );
    return $obj;
}

=head2 Postpone

Takes the following arguments:

=over

=item C<for>

This should be a UID which is not yet resolved.  When this UID is
resolved locally, its information will be used.

=item C<uid>

When the C<for> UID is resolved, the object with this UID (which must be
resolved prior to the C<Postpone> call) will be updated using
information from C<for>.

=item C<column>, C<classcolumn>, C<uri>, or C<method>

One or more of these must be specified, and determine how the C<uid> object is
updated with the C<for> object's information.

The C<uid> object's C<column> will be set to the C<for> object's id.

The C<uid> object's column named C<classcolumn> will be set to the C<for>
object's class.

The C<uid> object's column named C<uri> will be set to the internal URI of the
C<for> object.

The method named by C<method> will be called on the C<uid> object, passing
parameters for this importer instance, the hashref of arguments passed to
L</Postpone>, the C<for> object's class, and the C<for> object's id.

=back

=cut

sub Postpone {
    my $self = shift;
    my %args = (
        for         => undef,
        uid         => undef,
        column      => undef,
        classcolumn => undef,
        uri         => undef,
        @_,
    );
    my $uid = delete $args{for};

    if (defined $uid) {
        warn "The 'for' argument to Postpone ($uid) should still be unresolved!"
            if $self->Lookup($uid);
        warn "The 'uid' argument to Postpone ($args{uid}) should already be resolved!"
            unless $self->Lookup($args{uid});
        push @{$self->{Pending}{$uid}}, \%args;
    } else {
        push @{$self->{Invalid}}, \%args;
    }
}

=head2 SkipTransactions C<UID>

Flags this C<UID> such that transactions on this record should not be
imported. This is typically used for duplicate records (e.g. users, groups,
L<RT::System>) since we use the original record.

This has no effect for clones, as we want a pristine copy.

=cut

sub SkipTransactions {
    my $self = shift;
    my ($uid) = @_;
    return if $self->{Clone};
    $self->{SkipTransactions}{$uid} = 1;
}

=head2 ShouldSkipTransaction C<UID>

Returns a boolean indicating whether L</SkipTransactions> has been invoked for
this C<UID>.

=cut

sub ShouldSkipTransaction {
    my $self = shift;
    my ($uid) = @_;
    return exists $self->{SkipTransactions}{$uid};
}

=head2 MergeValues C<OBJECT>, C<DATA>

Updates each unset column in C<OBJECT> with each value in C<DATA>. Any
references will be resolved, if needed, using L</Postpone>.

=cut

sub MergeValues {
    my $self = shift;
    my ($obj, $data) = @_;
    for my $col (keys %{$data}) {
        next if defined $obj->__Value($col) and length $obj->__Value($col);
        next unless defined $data->{$col} and length $data->{$col};

        if (ref $data->{$col}) {
            my $uid = ${ $data->{$col} };
            my $ref = $self->Lookup( $uid );
            if ($ref) {
                $data->{$col} = $ref->[1];
            } else {
                $self->Postpone(
                    for => $obj->UID,
                    uid => $uid,
                    column => $col,
                );
                next;
            }
        }
        $obj->__Set( Field => $col, Value => $data->{$col} );
    }
}

=head2 SkipBy C<COLUMN>, C<CLASS>, C<UID>, C<DATA>

This is used to skip records that already exist. If there is an instance of
C<CLASS> whose value for C<COLUMN> is the same as what is in C<DATA>, then
the existing record is used instead of the record being imported. No values
are merged into the existing record; for that, see L</MergeBy>.

=cut

sub SkipBy {
    my $self = shift;
    my ($column, $class, $uid, $data) = @_;

    my $obj = $class->new( RT->SystemUser );
    $obj->Load( $data->{$column} );
    return unless $obj->Id;

    $self->SkipTransactions( $uid );

    $self->Resolve( $uid => $class => $obj->Id );
    return $obj;
}

=head2 MergeBy C<COLUMN>, C<CLASS>, C<UID>, C<DATA>

This is used to skip records that already exist. If there is an instance of
C<CLASS> whose value for C<COLUMN> is the same as what is in C<DATA>, then
the existing record is used instead of the record being imported. Values
from C<DATA> are merged into the existing record.

=cut

sub MergeBy {
    my $self = shift;
    my ($column, $class, $uid, $data) = @_;

    my $obj = $self->SkipBy(@_);
    return unless $obj;
    $self->MergeValues( $obj, $data );
    return 1;
}

=head2 Qualify C<NAME>

Returns the passed-in name with the organization and a colon prepended, if
needed. The name is instead returned as-is for clones, imports without an
organization, imports with C<--exclude-organization>, or imports where the
organization is the same as the current RT.

This is meant to disambiguate records (e.g. queues) that would otherwise
violate uniqueness constraints.

=cut

sub Qualify {
    my $self = shift;
    my ($string) = @_;
    return $string if $self->{Clone};
    return $string if not defined $self->{Organization};
    return $string if $self->{ExcludeOrganization};
    return $string if $self->{Organization} eq $RT::Organization;
    return $self->{Organization}.": $string";
}

=head2 Create C<CLASS>, C<UID>, C<DATA>

Creates a record of class C<CLASS> for identifier C<UID> using the provided
C<DATA>. This will invoke the record's PreInflate and PostInflate for
massaging data before and after creation. As part of this process,
L</Resolve> will be invoked to finalize the class and id for this C<UID>.

=cut

sub Create {
    my $self = shift;
    my ($class, $uid, $data) = @_;

    # Use a simpler pre-inflation if we're cloning
    if ($self->{Clone}) {
        $class->RT::Record::PreInflate( $self, $uid, $data );
    } else {
        # Non-cloning always wants to make its own id
        delete $data->{id};
        return unless $class->PreInflate( $self, $uid, $data );
    }

    my $obj = $class->new( RT->SystemUser );
    my ($id, $msg) = eval {
        # catch and rethrow on the outside so we can provide more info
        local $SIG{__DIE__};
        $obj->DBIx::SearchBuilder::Record::Create(
            %{$data}
        );
    };
    if (not $id or $@) {
        $msg ||= ''; # avoid undef
        my $err = "Failed to create $uid: $msg $@\n" . Data::Dumper::Dumper($data) . "\n";
        if (not $self->{HandleError}->($self, $err)) {
            die $err;
        } else {
            return;
        }
    }

    $self->{ObjectCount}{$class}++;
    $self->Resolve( $uid => $class, $id );

    # Load it back to get real values into the columns
    $obj = $class->new( RT->SystemUser );
    $obj->Load( $id );
    $obj->PostInflate( $self, $uid );

    return $obj;
}

=head2 ReadStream C<FH>

Takes a L<Storable>-encoded stream and imports the
L<RT::Migrate::Serializer>-generated records from it.

=cut

sub ReadStream {
    my $self = shift;
    my ($fh) = @_;

    # simplify the ticket load process to avoid loading the wrong ticket due
    # to merges
    no warnings 'redefine';
    local *RT::Ticket::Load = sub {
        my $self = shift;
        my $id   = shift;
        $self->LoadById( $id );
        return $self->Id;
    };

    my $loaded = Storable::fd_retrieve($fh);

    # Metadata is stored at the start of the stream as a hashref
    if (ref $loaded eq "HASH") {
        $self->LoadMetadata( $loaded );
        $self->InitStream;
        return;
    }

    # Data files are stored as arrayrefs
    my ($class, $uid, $data) = @{$loaded};

    if ($self->{Incremental}) {
        my $obj = $class->new( RT->SystemUser );
        $obj->Load( $data->{id} );
        if (not $uid) {
            # undef $uid means "delete it"
            $obj->Delete;
            $self->{ObjectCount}{$class}++;
        } elsif ( $obj->Id ) {
            # If it exists, update it
            $class->RT::Record::PreInflate( $self, $uid, $data );
            $obj->__Set( Field => $_, Value => $data->{$_} )
                for keys %{ $data };
            $self->{ObjectCount}{$class}++;
        } else {
            # Otherwise, make it
            $obj = $self->Create( $class, $uid, $data );
        }
        $self->{Progress}->($obj) if $obj and $self->{Progress};
        return;
    } elsif ($self->{Clone}) {
        my $obj = $self->Create( $class, $uid, $data );
        $self->{Progress}->($obj) if $obj and $self->{Progress};
        return;
    }

    # If it's a queue, store its ID away, as we'll need to know
    # it to split global CFs into non-global across those
    # fields.  We do this before inflating, so that queues which
    # got merged still get the CFs applied
    push @{$self->{NewQueues}}, $uid
        if $class eq "RT::Queue";

    my $origid = $data->{id};
    my $obj = $self->Create( $class, $uid, $data );
    return unless $obj;

    # If it's a ticket, we might need to create a
    # TicketCustomField for the previous ID
    if ($class eq "RT::Ticket" and $self->{OriginalId}) {
        my $value = $self->{ExcludeOrganization}
                  ? $origid
                  : $self->Organization . ":$origid";

        my ($id, $msg) = $obj->AddCustomFieldValue(
            Field             => $self->{OriginalId},
            Value             => $value,
            RecordTransaction => 0,
        );
        warn "Failed to add custom field to $uid: $msg"
            unless $id;
    }

    # If it's a CF, we don't know yet if it's global (the OCF
    # hasn't been created yet) to store away the CF for later
    # inspection
    push @{$self->{NewCFs}}, $uid
        if $class eq "RT::CustomField"
            and $obj->LookupType =~ /^RT::Queue/;

    $self->{Progress}->($obj) if $self->{Progress};
}

=head2 CloseStream

Finalizes this import; serves to update imported CFs that were global to
instead be applied only to the newly-imported queues.

=cut

sub CloseStream {
    my $self = shift;

    $self->{Progress}->(undef, 'force') if $self->{Progress};

    return if $self->{Clone};

    # Take global CFs which we made and make them un-global
    my @queues = grep {$_} map {$self->LookupObj( $_ )} @{$self->{NewQueues}};
    for my $obj (map {$self->LookupObj( $_ )} @{$self->{NewCFs}}) {
        my $ocf = $obj->IsGlobal or next;
        $ocf->Delete;
        $obj->AddToObject( $_ ) for @queues;
    }
    $self->{NewQueues} = [];
    $self->{NewCFs} = [];
}

=head2 ObjectCount

Returns a hash mapping each class to the number of imported objects of that
class. This may be called midstream to see how much progress has been made.

=cut

sub ObjectCount {
    my $self = shift;
    return %{ $self->{ObjectCount} };
}

=head2 Missing

Returns the list of not-yet imported UIDs which are required for other
objects using L</Postpone>.

=cut

sub Missing {
    my $self = shift;
    return wantarray ? sort keys %{ $self->{Pending} }
        : keys %{ $self->{Pending} };
}

=head2 Invalid

Returns the list of objects missing from the source database before
serialization.

=cut

sub Invalid {
    my $self = shift;
    return wantarray ? sort { $a->{uid} cmp $b->{uid} } @{ $self->{Invalid} }
                     : $self->{Invalid};
}

=head2 Organization

Returns the organization from the RT which generated the serialized data.

=cut

sub Organization {
    my $self = shift;
    return $self->{Organization};
}

=head2 Progress [C<SUBREF>]

Gets or sets the progress callback; this will be called with each object
as it is finished being imported, or with undef (and a second value of
C<force>) when the stream is finally closed.

=cut

sub Progress {
    my $self = shift;
    return defined $self->{Progress} unless @_;
    return $self->{Progress} = $_[0];
}

1;
