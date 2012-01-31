# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2011 Best Practical Solutions, LLC
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

sub new {
    my $class = shift;
    my $self = bless {}, $class;
    $self->Init(@_);
    return $self;
}

sub Init {
    my $self = shift;
    my %args = (
        Overwrite   => 0,
        OriginalId  => undef,
        Progress    => undef,
        Statefile   => undef,
        @_,
    );

    # Should we attempt to preserve record IDs as they are created?
    if ($self->{Overwrite} = $args{Overwrite}) {
        my $tickets = RT::Tickets->new( RT->SystemUser );
        $tickets->UnLimit;
        warn "RT already contains tickets; preserving ticket IDs is unlikely to work"
            if $tickets->Count;
    }

    # Where to shove the original ticket ID
    if ($self->{OriginalId} = $args{OriginalId}) {
        my $cf = RT::CustomField->new( RT->SystemUser );
        $cf->LoadByName( Queue => 0, Name => $self->{OriginalId} );
        unless ($cf->Id) {
            warn "Failed to find global CF named $self->{OriginalId} -- creating one";
            $cf->Create(
                Queue => 0,
                Name  => $self->{OriginalId},
                Type  => 'FreeformSingle',
            );
        }
    }

    $self->{Progress}  = $args{Progress};
    $self->{Statefile} = $args{Statefile};

    # Objects we've created
    $self->{UIDs} = {};

    # Columns we need to update when an object is later created
    $self->{Pending} = {};

    # What we created
    $self->{ObjectCount} = {};

    # To know what global CFs need to be unglobal'd and applied to what
    $self->{NewQueues} = [];
    $self->{NewCFs} = [];

    # Basic facts of life, as a safety net
    $self->Resolve( RT->System->UID => ref RT->System, RT->System->Id );
    $self->SkipTransactions( RT->System->UID );
}

sub Resolve {
    my $self = shift;
    my ($uid, $class, $id) = @_;
    $self->{UIDs}{$uid} = [ $class, $id ];
    return unless $self->{Pending}{$uid};

    for my $ref (@{$self->{Pending}{$uid}}) {
        my ($pclass, $pid) = @{ $self->{UIDs}{ $ref->{uid} } };
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
    }
    delete $self->{Pending}{$uid};
}

sub Lookup {
    my $self = shift;
    my ($uid) = @_;
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
    push @{$self->{Pending}{$uid}}, \%args;
}

sub SkipTransactions {
    my $self = shift;
    my ($uid) = @_;
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
    return $string if $self->{PreserveTicketIds};
    return $string if not defined $self->{Organization};
    return $self->{Organization}.": $string";
}

sub Create {
    my $self = shift;
    my ($class, $uid, $data) = @_;
    return unless $class->PreInflate( $self, $uid, $data );

    # Remove the ticket id, unless we specifically want it kept
    delete $data->{id} unless $self->{Overwrite};

    my $obj = $class->new( RT->SystemUser );
    my ($id, $msg) = $obj->DBIx::SearchBuilder::Record::Create(
        %{$data}
    );
    die "Failed to create $uid: $msg\n" . Data::Dumper::Dumper($data) . "\n"
        unless $id;

    $self->{ObjectCount}{$class}++;
    $self->Resolve( $uid => $class, $id );

    # Load it back to get real values into the columns
    $obj = $class->new( RT->SystemUser );
    $obj->Load( $id );
    $obj->PostInflate( $self );

    return $obj;
}

sub Import {
    my $self = shift;
    my ($dir) = @_;

    $self->{Files} = [ map {File::Spec->rel2abs($_)} <$dir/*.dat> ];

    $self->RestoreState( $self->{Statefile} );

    no warnings 'redefine';
    local *RT::Ticket::Load = sub {
        my $self = shift;
        my $id   = shift;
        $self->LoadById( $id );
        return $self->Id;
    };

    local $SIG{  INT  } = sub { $self->{INT} = 1 };
    local $SIG{__DIE__} = sub { print STDERR "\n", @_; $self->SaveState; exit 1 };

    $self->{Progress}->(undef) if $self->{Progress};
    while (@{$self->{Files}}) {
        $self->{Filename} = shift @{$self->{Files}};
        open(my $fh, "<", $self->{Filename})
            or die "Can't read $self->{Filename}: $!";
        if ($self->{Seek}) {
            seek($fh, $self->{Seek}, 0)
                or die "Can't seek to $self->{Seek} in $self->{Filename}";
            $self->{Seek} = undef;
        }
        while (not eof($fh)) {
            $self->{Position} = tell($fh);

            # Stop when we're at a good stopping point
            die "Caught interrupt, quitting.\n" if $self->{INT};

            my $loaded = Storable::fd_retrieve($fh);

            # Scalar references are the back-compat way we store the
            # organization value
            if (ref $loaded eq "SCALAR") {
                $self->{Organization} = $$loaded;
                next;
            }

            my ($class, $uid, $data) = @{$loaded};

            # If it's a queue, store its ID away, as we'll need to know
            # it to split global CFs into non-global across those
            # fields.  We do this before inflating, so that queues which
            # got merged still get the CFs applied
            push @{$self->{NewQueues}}, $uid
                if $class eq "RT::Queue";

            my $obj = $self->Create( $class, $uid, $data );
            next unless $obj;

            # If it's a ticket, we might need to create a
            # TicketCustomField for the previous ID
            if ($class eq "RT::Ticket" and $self->{OriginalId}) {
                my ($org, $origid) = $uid =~ /^RT::Ticket-(.*)-(\d+)$/;
                my ($id, $msg) = $obj->AddCustomFieldValue(
                    Field             => $self->{OriginalId},
                    Value             => "$org:$origid",
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
    }

    # Take global CFs which we made and make them un-global
    my @queues = grep {$_} map {$self->LookupObj( $_ )} @{$self->{NewQueues}};
    for my $obj (map {$self->LookupObj( $_ )} @{$self->{NewCFs}}) {
        my $ocf = $obj->IsApplied( 0 ) or next;
        $ocf->Delete;
        $obj->AddToObject( $_ ) for @queues;
    }
    $self->{NewQueues} = [];
    $self->{NewCFs} = [];


    # Return creation counts
    return $self->ObjectCount;
}

sub List {
    my $self = shift;
    my ($dir) = @_;

    my %found = ( "RT::System" => 1 );
    for my $filename (map {File::Spec->rel2abs($_)} <$dir/*.dat> ) {
        open(my $fh, "<", $filename)
            or die "Can't read $filename: $!";
        while (not eof($fh)) {
            my $loaded = Storable::fd_retrieve($fh);
            if (ref $loaded eq "SCALAR") {
                warn "Dump contains files from Multiple RT instances!\n"
                    if defined $self->{Organization}
                        and $self->{Organization} ne $$loaded;
                $self->{Organization} = $$loaded;
                next;
            }

            my ($class, $uid, $data) = @{$loaded};
            $self->{ObjectCount}{$class}++;
            $found{$uid} = 1;
            delete $self->{Pending}{$uid};
            for (grep {ref $data->{$_}} keys %{$data}) {
                my $uid_ref = ${ $data->{$_} };
                next if $found{$uid_ref};
                next if $uid_ref =~ /^RT::Principal-/;
                push @{$self->{Pending}{$uid_ref} ||= []}, {uid => $uid};
            }
        }
    }

    return $self->ObjectCount;
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

sub Organization {
    my $self = shift;
    return $self->{Organization};
}

sub RestoreState {
    my $self = shift;
    my ($statefile) = @_;
    return unless $statefile and -f $statefile;

    my $state = Storable::retrieve( $self->{Statefile} );
    $self->{$_} = $state->{$_} for keys %{$state};
    unlink $self->{Statefile};

    print STDERR "Resuming partial import...\n";
    sleep 2;
    return 1;
}

sub SaveState {
    my $self = shift;

    my %data;
    unshift @{$self->{Files}}, $self->{Filename};
    $self->{Seek} = $self->{Position};
    $data{$_} = $self->{$_} for
        qw/Filename Seek Position Files
           Organization ObjectCount
           NewQueues NewCFs
           SkipTransactions Pending
           UIDs
           OriginalId Overwrite
          /;
    Storable::nstore(\%data, $self->{Statefile});

    print STDERR <<EOT;

Importer state has been written to the file:
    $self->{Statefile}

It may be possible to resume the import by re-running rt-importer.
EOT
}

1;
