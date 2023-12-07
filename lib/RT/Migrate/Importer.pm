# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2023 Best Practical Solutions, LLC
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
        AutoCommit          => 1,
        BatchUserPrincipals  => 0,
        BatchGroupPrincipals => 0,
        BatchSize            => 0,
        MaxProcesses         => 10,
        @_,
    );

    # Should we attempt to preserve record IDs as they are created?
    $self->{OriginalId} = $args{OriginalId};

    $self->{ExcludeOrganization} = $args{ExcludeOrganization};

    $self->{Progress} = $args{Progress};

    $self->{AutoCommit} = $args{AutoCommit};

    $self->{$_} = $args{$_} for qw/BatchUserPrincipals BatchGroupPrincipals/;
    $self->{BatchSize}    = $args{BatchSize};
    $self->{MaxProcesses} = $args{MaxProcesses} || 10;

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

sub Metadata {
    my $self = shift;
    return $self->{Metadata};
}

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
    $self->{All}          = $data->{All};

    $self->{Files}        = $data->{Files} if $data->{Final};
}

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
        $self->{OriginalId} = $cf->Id;
    }

    if ( !$self->{Clone} ) {
        for my $type ( qw/User Group/ ) {
            if ( my $count = $self->{"Batch${type}Principals"} ) {
                my $principal = RT::Principal->new( RT->SystemUser );
                my ($id)      = $principal->Create( PrincipalType => $type, Disabled => 0 );

                my $left = $count - 1; # already created one

                # Insert 100k each time, to avoid too much memory assumption.
                while ( $left > 0 ) {
                    if ( $left > 100_000 ) {
                        my $sql = 'INSERT INTO Principals (PrincipalType, Disabled) VALUES ' . join ',',
                            ("('$type', 0)") x ( 100_000 );
                        $self->RunSQL($sql);
                        $left -= 100_000;
                    }
                    else {
                        my $sql = 'INSERT INTO Principals (PrincipalType, Disabled) VALUES ' . join ',',
                            ("('$type', 0)") x $left;
                        $self->RunSQL($sql);
                        last;
                    }
                }

                push @{ $self->{_principals}{$type} }, $id .. ( $count - 1 + $id );
            }
        }
    }
}

sub NextPrincipalId {
    my $self = shift;
    my %args = @_;
    my $id;
    if ( $args{PrincipalType} eq 'User' ) {
        $id = shift @{$self->{_principals}{User} || []};
    }
    else {
        $id = shift @{$self->{_principals}{Group} || []};
    }

    if ( !$id ) {
        my $principal = RT::Principal->new( RT->SystemUser );
        ($id) = $principal->Create(%args);
    }

    if ( $args{Disabled} ) {
        $self->RunSQL("UPDATE Principals SET Disabled=1 WHERE id=$id");
    }

    return $id;
}

sub NextId {
    my $self  = shift;
    my $class = shift;
    my $id    = shift;

    if ( $id ) {
        $self->{_next_id}{$class} = $id;
        return $id;
    }

    if ( defined $self->{_next_id}{$class} ) {
        return $self->{_next_id}{$class}++;
    }
    return;
}

sub HasNextId {
    my $self  = shift;
    my $class = shift;

    return defined $self->{_next_id}{$class} ? 1 : 0;
}

sub Resolve {
    my $self = shift;
    my ($uid, $class, $id) = @_;

    # If we can infer from uid, do not store class/id to save memory usage.
    if ( $uid eq join '-', $class, $self->{Organization}, $id ) {
        $self->{UIDs}{$uid} = undef;
    }
    else {
        $self->{UIDs}{$uid} = "$class-$id";
    }

    return unless $self->{Pending}{$uid};

    my @left;
    for my $ref (@{$self->{Pending}{$uid}}) {
        if ( my $lookup = $self->Lookup( $ref->{uid} ) ) {
            my ( $pclass, $pid ) = @{$lookup};
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
            if ( my $method = $ref->{method} ) {
                $obj->$method( $self, $ref, $class, $id );
            }
        }
        else {
            push @left, $ref;
        }
    }

    if ( @left ) {
        $self->{Pending}{$uid} = \@left;
    }
    else {
        delete $self->{Pending}{$uid};
    }
}

sub Lookup {
    my $self = shift;
    my ($uid) = @_;
    unless (defined $uid) {
        carp "Tried to lookup an undefined UID";
        return;
    }

    return unless exists $self->{UIDs}{$uid};

    if ( ( $self->{UIDs}{$uid} // '' ) =~ /(.+)-(.+)/
        || $uid =~ /(.+)-(?:\Q$self->{Organization}\E)-(.+)/ )
    {
        return [ $1, $2 ];
    }
    return;
}

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
    return if $self->{_postponed}{ join ';', map { $_ . ':' . ( $args{$_} // '' ) } sort keys %args }++;

    my $uid = delete $args{for};

    if (defined $uid) {
        push @{$self->{Pending}{$uid}}, \%args;
    } else {
        push @{$self->{Invalid}}, \%args;
    }
}

sub SkipTransactions {
    my $self = shift;
    my ($uid) = @_;
    return if $self->{Clone};
    $self->{SkipTransactions}{$uid} = 1;
}

sub ShouldSkipTransaction {
    my $self = shift;
    my ($uid) = @_;
    return exists $self->{SkipTransactions}{$uid};
}

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

sub MergeBy {
    my $self = shift;
    my ($column, $class, $uid, $data) = @_;

    my $obj = $self->SkipBy(@_);
    return unless $obj;
    $self->MergeValues( $obj, $data );
    return 1;
}

sub Qualify {
    my $self = shift;
    my ($string) = @_;
    return $string if $self->{Clone};
    return $string if not defined $self->{Organization};
    return $string if $self->{ExcludeOrganization};
    return $string if $self->{Organization} eq $RT::Organization;
    return $self->{Organization}.": $string";
}

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

    # Unlike MySQL and Oracle, Pg stores UTF-8 strings, without this, data
    # could be be wrongly encoded on Pg.
    if ( RT->Config->Get( 'DatabaseType' ) eq 'Pg' ) {
        for my $field ( keys %$data ) {
            if ( $data->{$field} && $data->{$field} =~ /[^\x00-\x7F]/ && !utf8::is_utf8( $data->{$field} ) ) {

                # Make sure decoded data is valid UTF-8, otherwise Pg won't insert
                my $decoded;
                eval {
                    local $SIG{__DIE__};    # don't exit importer for errors happen here
                    $decoded = Encode::decode( 'UTF-8', $data->{$field}, Encode::FB_CROAK );
                };
                if ( $@ ) {
                    warn "$uid contains invalid UTF-8 data in $field: $@, will store encoded string instead\n"
                      . Data::Dumper::Dumper( $data ) . "\n";
                }
                else {
                    $data->{$field} = $decoded;
                }
            }
        }
    }

    if ( $self->{BatchSize} && ( $self->{Clone} || $self->{All} ) ) {

        # Finish up the previous class if there are any records left
        my ($previous_class) = grep { $_ ne $class && @{ $self->{_batch}{$_} } } keys %{ $self->{_batch} || {} };
        if ($previous_class) {
            $self->BatchCreate( $previous_class, $self->{_batch}{$previous_class} );
        }

        if ( $data->{id} || $self->HasNextId($class) ) {
            push @{ $self->{_batch}{$class} }, [ $uid, $data ];
            if ( @{ $self->{_batch}{$class} } == $self->{BatchSize} ) {
                $self->BatchCreate( $class, $self->{_batch}{$class} );
            }
            return;
        }
    }

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

    return $obj if $self->{Clone};

    # Users/Groups have id set in PreInflate, no need to set here
    if (   $self->{BatchSize}
        && $self->{All}
        && $class =~ /^RT::(?:Ticket|Transaction|Attachment|GroupMember|ObjectCustomFieldValue|Attribute|Link)$/ )
    {
        $self->NextId( $class, $id + 1 );
    }

    $self->{ObjectCount}{$class}++;
    $self->Resolve( $uid => $class, $id );

    # RT::User::PostInflate is just to call InitSystemObjects for RT_System user.
    # Here we treat it specially to avoid loading other user objects unnecessarily for performance.
    if ( $class eq 'RT::User' ) {
        RT->InitSystemObjects if $data->{Name} eq 'RT_System';
    }
    elsif ( $class->can('PostInflate') ne RT::Record->can('PostInflate') ) {
        # Load it back to get real values into the columns
        $obj->Load( $id );
        $obj->PostInflate( $self, $uid );
    }

    return $obj;
}

sub ReadStream {
    my $self = shift;
    my ($fh) = @_;

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
        $self->CreateOriginalIdOCFVs( { $self->Lookup($uid)->[1] => $origid } );
    }

    # If it's a CF, we don't know yet if it's global (the OCF
    # hasn't been created yet) to store away the CF for later
    # inspection
    push @{$self->{NewCFs}}, $uid
        if $class eq "RT::CustomField"
            and $data->{LookupType} =~ /^RT::Queue/; # Use $data in case $obj is not fully loaded.

    $self->{Progress}->($obj) if $self->{Progress};
}

sub CloseStream {
    my $self = shift;

    $self->{Progress}->(undef, 'force') if $self->{Progress};

    my %order = (
        'RT::Ticket'                 => 1,
        'RT::Group'                  => 2,
        'RT::GroupMember'            => 3,
        'RT::ObjectCustomFieldValue' => 4,
        'RT::Transaction'            => 5,
        'RT::Attachment'             => 6,
    );

    for my $class (
        sort { ( $order{$a} // 0 ) <=> ( $order{$b} // 0 ) }
        grep { @{ $self->{_batch}{$_} } } keys %{ $self->{_batch} || {} }
        )
    {
        $self->BatchCreate( $class, $self->{_batch}{$class} );
    }

    $self->{_pm}->wait_all_children if $self->{_pm};

    # Now have all data imported, try to resolve again.
    my @uids = grep { $self->{UIDs}{$_} } keys %{ $self->{Pending} };

    for my $uid (@uids) {
        my ( $class, $id ) = split /-/, $self->{UIDs}{$uid}, 2;
        $self->Resolve( $uid, $class, $id );
    }

    # Fill CGM

    # Groups
    $self->RunSQL(<<'EOF');
INSERT INTO CachedGroupMembers (GroupId, MemberId, Via, ImmediateParentId, Disabled)
    SELECT Groups.id, Groups.id, NULL, Groups.id, Principals.Disabled FROM Groups
    LEFT JOIN Principals ON ( Groups.id = Principals.id )
    LEFT JOIN CachedGroupMembers ON (
        Groups.id = CachedGroupMembers.GroupId
        AND CachedGroupMembers.GroupId = CachedGroupMembers.MemberId
        AND CachedGroupMembers.GroupId = CachedGroupMembers.ImmediateParentId
        )
    WHERE CachedGroupMembers.id IS NULL
EOF

    # GroupMembers
    $self->RunSQL(<<'EOF');
INSERT INTO CachedGroupMembers (GroupId, MemberId, Via, ImmediateParentId, Disabled)
    SELECT GroupMembers.GroupId, GroupMembers.MemberId, NULL, GroupMembers.GroupId, Principals.Disabled FROM GroupMembers
    LEFT JOIN Principals ON ( GroupMembers.GroupId = Principals.id )
    LEFT JOIN CachedGroupMembers ON (
        GroupMembers.GroupId = CachedGroupMembers.GroupId
        AND GroupMembers.MemberId = CachedGroupMembers.MemberId
        AND CachedGroupMembers.GroupId = CachedGroupMembers.ImmediateParentId
    )
    WHERE CachedGroupMembers.id IS NULL
EOF

    # Fixup Via
    $self->RunSQL(<<'EOF');
UPDATE CachedGroupMembers SET Via=id WHERE Via IS NULL
EOF

    # Cascaded GroupMembers, use the same SQL in rt-validator
    my $cascaded_cgm = <<'EOF';
INSERT INTO CachedGroupMembers (GroupId, MemberId, Via, ImmediateParentId, Disabled)
SELECT cgm1.GroupId, gm2.MemberId, cgm1.id AS Via,
    cgm1.MemberId AS ImmediateParentId, cgm1.Disabled
FROM
    CachedGroupMembers cgm1
    CROSS JOIN GroupMembers gm2
    LEFT JOIN CachedGroupMembers cgm3 ON (
            cgm3.GroupId           = cgm1.GroupId
        AND cgm3.MemberId          = gm2.MemberId
        AND cgm3.Via               = cgm1.id
        AND cgm3.ImmediateParentId = cgm1.MemberId )
    LEFT JOIN Groups g ON (
        cgm1.GroupId = g.id
    )
WHERE cgm1.GroupId != cgm1.MemberId
AND gm2.GroupId = cgm1.MemberId
AND cgm3.id IS NULL
AND g.Domain != 'RT::Ticket-Role'
EOF
    # Do this multiple times if needed to fill up cascaded group members
    while ( my $rv = $self->RunSQL($cascaded_cgm) ) {
        # $rv could be 0E0 that is true in bool context but 0 in numeric comparison.
        last unless $rv > 0;
    }

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


sub ObjectCount {
    my $self = shift;
    return %{ $self->{ObjectCount} };
}

sub Missing {
    my $self = shift;
    return wantarray ? sort keys %{ $self->{Pending} }
        : keys %{ $self->{Pending} };
}

sub Invalid {
    my $self = shift;
    return wantarray ? sort { $a->{uid} cmp $b->{uid} } @{ $self->{Invalid} }
                     : $self->{Invalid};
}

sub Organization {
    my $self = shift;
    return $self->{Organization};
}

sub Progress {
    my $self = shift;
    return defined $self->{Progress} unless @_;
    return $self->{Progress} = $_[0];
}

sub BatchCreate {
    my $self  = shift;
    my $class = shift;
    my $items = shift or return;

    return unless @$items;

    if ( $self->{Clone} ) {

        if ( !$self->{_pm} ) {
            require Parallel::ForkManager;
            $self->{_pm} = Parallel::ForkManager->new( $self->{MaxProcesses} );
        }

        $self->{ObjectCount}{$class} += @$items;
        my @copy = @$items;
        @$items = ();

        $RT::Handle->Commit unless $self->{AutoCommit};
        $RT::Handle->Disconnect;

        if ( $self->{_pm}->start ) {
            $RT::Handle->Connect;
            $RT::Handle->BeginTransaction unless $self->{AutoCommit};
            return 1;
        }

        $RT::Handle->Connect;
        $self->_BatchCreate( $class, \@copy );
        $self->{_pm}->finish;
    }
    else {
        # In case there are duplicates, which could happen for merged members.
        if ( $class eq 'RT::GroupMember' ) {
            my %added;
            @$items = grep { !$added{ $_->[1]{GroupId} }{ $_->[1]{MemberId} }++ } @$items;
        }

        my $map = $self->_BatchCreate( $class, $items );
        $self->{ObjectCount}{$class} += @$items;
        @$items = ();

        if ($map) {
            $self->{UIDs}{$_} = $map->{$_} for keys %$map;

            my %ticket_map;
            for my $uid ( keys %$map ) {
                my ( $class, $id ) = split /-/, $map->{$uid}, 2;

                $self->Resolve( $uid => $class, $id );
                if ( $class eq 'RT::User' ) {
                    RT->InitSystemObjects if $uid =~ /-RT_System$/;
                }
                elsif ( $class->can('PostInflate') ne RT::Record->can('PostInflate') ) {
                    my $record = $class->new( RT->SystemUser );
                    $record->Load($id);
                    $record->PostInflate( $self, $uid );
                }

                if ( $self->{OriginalId} && $class eq 'RT::Ticket' ) {
                    my ($orig_id) = ( $uid =~ /-(\d+)$/ );
                    $ticket_map{$id} = $orig_id;
                }
            }

            $self->CreateOriginalIdOCFVs( \%ticket_map ) if %ticket_map;
        }
        return 1;
    }
}

sub _BatchCreate {
    my $self  = shift;
    my $class = shift;
    my $items = shift or return;
    return unless @$items;

    my %map;

    # Do not actually insert, just get the SQL, with sorted field/value pairs
    local *RT::Handle::Insert = sub {
        my $self  = shift;
        my $table = shift;
        my %attr  = @_;
        return $self->InsertQueryString( $table, map { $_ => $attr{$_} } sort keys %attr );
    };

    my %query;
    for (@$items) {
        my ( $uid, $data ) = @$_;
        my $obj = $class->new( RT->SystemUser );

        my $id = $data->{id} || $self->NextId($class);
        my ( $sql, @bind ) = $obj->DBIx::SearchBuilder::Record::Create( %$data, id => $id );
        $map{$uid} = join '-', $class, $id unless $self->{Clone};
        push @{ $query{$sql} }, \@bind;
    }

    my $dbh = $RT::Handle->dbh;

    for my $sql ( keys %query ) {

        my $count = @{ $query{$sql} };
        my $values_paren;
        if ( $sql =~ /(\(\?.+?\))/i ) {
            $values_paren = $1;
        }

        # DBs have placeholder limitations(64k for Pg), here we replace
        # placeholders to support bigger batch sizes. The performance is similar.
        my $batch_sql
            = $RT::Handle->FillIn( $sql . ( ", $values_paren" x ( $count - 1 ) ), [ map @$_, @{ $query{$sql} } ] );
        $self->RunSQL($batch_sql);
    }

    # Clone doesn't need to return anything
    return $self->{Clone} ? () : \%map;
}

=head2 CreateOriginalIdOCFVs { NEW_ID => ORIG_ID, ... }

Create corresponding ObjectCustomFieldValues that contain tickets' original ids.

=cut

sub CreateOriginalIdOCFVs {
    my $self = shift;
    my $ticket_map = shift;
    if ( %$ticket_map ) {
        my $sql
            = 'INSERT INTO ObjectCustomFieldValues (CustomField, ObjectType, ObjectId, Content, Creator) VALUES ';
        my @values;
        if ( !$self->{ExcludeOrganization} ) {
            $ticket_map->{$_} = "$self->{Organization}:$ticket_map->{$_}" for keys %$ticket_map;
        }

        my $creator = RT->SystemUser->Id;
        for my $id ( sort { $a <=> $b } keys %$ticket_map ) {
            push @values, qq{($self->{OriginalId}, 'RT::Ticket', $id, '$ticket_map->{$id}', $creator)};
        }
        $sql .= join ',', @values;
        $self->RunSQL($sql);
    }
}

sub RunSQL {
    my $self = shift;
    my $rv;
    eval {
        local $SIG{__DIE__};
        $rv = $RT::Handle->dbh->do(@_);
    };
    if ($@) {
        my $err = "Failed to run @_: $@\n";
        if ( not $self->{HandleError}->( $self, $err ) ) {
            die $err;
        }
        else {
            return undef;
        }
    }
    return $rv;
}

1;
