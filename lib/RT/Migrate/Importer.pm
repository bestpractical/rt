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
    }
}

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

sub Lookup {
    my $self = shift;
    my ($uid) = @_;
    unless (defined $uid) {
        carp "Tried to lookup an undefined UID";
        return;
    }
    return $self->{UIDs}{$uid};
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

1;
