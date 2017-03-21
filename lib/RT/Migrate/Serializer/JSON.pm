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

package RT::Migrate::Serializer::JSON;

use strict;
use warnings;
use JSON qw//;

use base 'RT::Migrate::Serializer';

sub Init {
    my $self = shift;

    my %args = (
        Directory   => undef,
        Force       => undef,

        @_,
    );

    # Set up the output directory we'll be writing to
    my ($y,$m,$d) = (localtime)[5,4,3];
    $args{Directory} = $RT::Organization .
        sprintf(":%d-%02d-%02d",$y+1900,$m+1,$d)
        unless defined $args{Directory};
    system("rm", "-rf", $args{Directory}) if $args{Force};
    die "Output directory $args{Directory} already exists"
        if -d $args{Directory};
    mkdir $args{Directory}
        or die "Can't create output directory $args{Directory}: $!\n";
    $self->{Directory} = delete $args{Directory};

    $self->{Records} = {};

    $self->SUPER::Init(@_);
}

sub Export {
    my $self = shift;

    # Write the initial metadata
    $self->InitStream;

    # Walk the objects
    $self->Walk( @_ );

    # Set up our output file
    $self->OpenFile;

    # Write out the initialdata
    $self->WriteFile;

    # Close everything back up
    $self->CloseFile;

    return $self->ObjectCount;
}

sub Files {
    my $self = shift;
    return ($self->Filename);
}

sub Filename {
    my $self = shift;
    return sprintf(
        "%s/initialdata.json",
        $self->{Directory},
    );
}

sub Directory {
    my $self = shift;
    return $self->{Directory};
}

sub Observe {
    my $self = shift;
    my %args = @_;

    my $obj = $args{object};

    # avoid serializing ACLEquivalence, etc
    if ($obj->isa("RT::Group")) {
        return 0 unless $obj->Domain eq 'UserDefined';
    }
    if ($obj->isa("RT::GroupMember")) {
        return 0 unless $obj->GroupObj->Object->Domain eq 'UserDefined';
    }

    return $self->SUPER::Observe(%args);
}

sub PushBasics {
    my $self = shift;
    $self->SUPER::PushBasics(@_);

    # we want to include all CFs, scrips, etc, not just the reachable ones
    $self->PushCollections(qw(CustomFields CustomRoles));
    $self->PushCollections(qw(Scrips)) if $self->{FollowScrips};
}

sub JSON {
    my $self = shift;
    return $self->{JSON} ||= JSON->new->pretty->canonical;
}

sub OpenFile {
    my $self = shift;
    open($self->{Filehandle}, ">", $self->Filename)
        or die "Can't write to file @{[$self->Filename]}: $!";
}

sub CloseFile {
    my $self = shift;
    close($self->{Filehandle})
        or die "Can't close @{[$self->Filename]}: $!";
}

sub WriteMetadata {
    my $self = shift;
    my $meta = shift;

    # no need to write metadata
    return;
}

sub WriteRecord {
    my $self = shift;
    my $record = shift;

    $self->{Records}{ $record->[0] }{ $record->[1] } = $record->[2];
}

my %initialdataType = (
    ACE => 'ACL',
    Class => 'Classes',
    GroupMember => 'Members',
);

sub _GetObjectByRef {
    my $self = shift;
    my $ref  = shift;

    $ref = $$ref if ref($ref) eq 'SCALAR';

    return RT->System if $ref eq 'RT::System';
    return RT->SystemUser if $ref eq 'RT::User-RT_System';

    my ($class, $id) = $ref =~ /^([\w:]+)-.*-(\d+)$/
        or do { warn "Unable to canonicalize ref '$ref'"; return undef };

    my $obj = $class->new(RT->SystemUser);
    $obj->Load($id);
    return $obj;
}

sub _GetSerializedByRef {
    my $self = shift;
    my $ref  = shift;

    $ref = $$ref if ref($ref) eq 'SCALAR';

    my ($class) = $ref =~ /^([\w:]+)-/
        or return undef;

    return $self->{Records}{$class}{$ref};
}

sub CanonicalizeReference {
    my $self    = shift;
    my $ref     = ${ shift(@_) };
    my $context = shift;
    my $for_key = shift;

    my $record = $self->_GetSerializedByRef($ref)
        or return $ref;

    return $record->{Name} || $ref;
}

sub _CanonicalizeManyToMany {
    my $self = shift;
    my %args = (
        object_class => '',
        object_primary_ref => '',
        primary_class => '',
        primary_key => 'ApplyTo',
        add_to_primary => undef,
        canonicalize_object => sub { $_->{ObjectId} },
        @_,
    );

    my $object_class = $args{object_class};
    my $object_primary_ref = $args{object_primary_ref};
    my $primary_class = $args{primary_class};
    my $primary_key = $args{primary_key};
    my %add_to_primary = %{ $args{add_to_primary} || {} };
    my $canonicalize_object = $args{canonicalize_object};

    if (my $objects = delete $self->{Records}{$object_class}) {
        for my $object (values %$objects) {
            my $primary = $self->{Records}{$primary_class}{ ${ $object->{$object_primary_ref} } };
            push @{ $primary->{$primary_key} }, $object;
        }

        for my $primary (values %{ $self->{Records}{$primary_class} }) {
            @{ $primary->{$primary_key} }
                = map &$canonicalize_object,
                  sort { $a->{SortOrder} <=> $b->{SortOrder} }
                  @{ $primary->{$primary_key} || [] };

            %$primary = (%$primary, %add_to_primary);
        }
    }
}

sub CanonicalizeACLs {
    my $self = shift;

    for my $ace (values %{ $self->{Records}{'RT::ACE'} }) {
        my $principal = $self->_GetObjectByRef(delete $ace->{PrincipalId});
        my $object = $self->_GetObjectByRef(delete $ace->{Object});

        if ($principal->IsGroup) {
            my $domain = $principal->Object->Domain;
            if ($domain eq 'ACLEquivalence') {
                $ace->{UserId} = $principal->Object->InstanceObj->Name;
            }
            else {
                $ace->{GroupDomain} = $domain;
                if ($domain eq 'SystemInternal') {
                    $ace->{GroupType} = $principal->Object->Name;
                }
                elsif ($domain eq 'RT::Queue-Role') {
                    $ace->{Queue} = $principal->Object->Instance;
                }
            }
        }
        else {
            $ace->{UserId} = $principal->Object->Name;
        }

        $ace->{ObjectType} = ref($object);
        $ace->{ObjectId} = $object->Id;
    }
}

sub CanonicalizeUsers {
    my $self = shift;

    for my $user (values %{ $self->{Records}{'RT::User'} }) {
        delete $user->{Principal};
        delete $user->{PrincipalId};

        my $object = RT::User->new(RT->SystemUser);
        $object->Load($user->{id});

        $user->{Privileged} = $object->Privileged ? JSON::true : JSON::false;
    }
}

sub CanonicalizeGroupMembers {
    my $self = shift;

    for my $record (values %{ $self->{Records}{'RT::GroupMember'} }) {
        my $group = $self->_GetObjectByRef(delete $record->{GroupId});
        $record->{Group} = $group->Object->Name;

        my $member = $self->_GetObjectByRef(delete $record->{MemberId});
        $record->{Class} = ref($member->Object);
        $record->{Name} = $member->Object->Name;
    }
}

sub CanonicalizeObjectCustomFieldValues {
    my $self = shift;

    for my $record (values %{ $self->{Records}{'RT::ObjectCustomFieldValue'} }) {
        my $object = $self->_GetSerializedByRef(delete $record->{Object});

        my $cf = $self->_GetSerializedByRef(delete $record->{CustomField});
        $record->{CustomField} = $cf->{Name};

        delete @$record{qw/id/};

        push @{ $object->{CustomFields} }, $record;
    }

    delete $self->{Records}{'RT::ObjectCustomFieldValue'};
}

sub CanonicalizeObjects {
    my $self = shift;

    $self->_CanonicalizeManyToMany(
        object_class        => 'RT::ObjectCustomField',
        object_primary_ref  => 'CustomField',
        primary_class       => 'RT::CustomField',
        canonicalize_object => sub {
            ref($_->{ObjectId})
                ? $self->_GetSerializedByRef($_->{ObjectId})->{Name}
                : $_->{ObjectId};
        },
    );

    $self->_CanonicalizeManyToMany(
        object_class        => 'RT::CustomFieldValue',
        object_primary_ref  => 'CustomField',
        primary_class       => 'RT::CustomField',
        primary_key         => 'Values',
        canonicalize_object => sub {
            my %object = %$_;
            delete @object{qw/id CustomField/};
            return \%object;
        },
    );

    $self->_CanonicalizeManyToMany(
        object_class       => 'RT::ObjectClass',
        object_primary_ref => 'Class',
        primary_class      => 'RT::Class',
    );

    $self->_CanonicalizeManyToMany(
        object_class       => 'RT::ObjectCustomRole',
        object_primary_ref => 'CustomRole',
        primary_class      => 'RT::CustomRole',
        canonicalize_object => sub {
            ref($_->{ObjectId})
                ? $self->_GetSerializedByRef($_->{ObjectId})->{Name}
                : $_->{ObjectId};
        },
    );

    $self->_CanonicalizeManyToMany(
        object_class        => 'RT::ObjectScrip',
        object_primary_ref  => 'Scrip',
        primary_class       => 'RT::Scrip',
        primary_key         => 'Queue',
        add_to_primary      => { NoAutoGlobal => 1 },
        canonicalize_object => sub {
            my %object = %$_;
            delete @object{qw/id Scrip/};
            $object{ObjectId} = $self->_GetSerializedByRef($object{ObjectId})->{Name}
                if $object{ObjectId}; # 0 meaning Global can stay 0
            return \%object;
        },
    );
}

sub WriteFile {
    my $self = shift;
    my %output;

    for my $record (map { values %$_ } values %{ $self->{Records} }) {
        delete @$record{qw/Creator Created LastUpdated LastUpdatedBy/};
    }

    $self->CanonicalizeObjects;
    $self->CanonicalizeObjectCustomFieldValues;
    $self->CanonicalizeACLs;
    $self->CanonicalizeUsers;
    $self->CanonicalizeGroupMembers;

    delete $self->{Records}{'RT::Attribute'};

    for my $intype (keys %{ $self->{Records} }) {
        my $outtype = $intype;
        $outtype =~ s/^RT:://;
        $outtype = $initialdataType{$outtype} || ($outtype . 's');

        for my $id (keys %{ $self->{Records}{$intype} }) {
            my $record = $self->{Records}{$intype}{$id};
            for my $key (keys %$record) {
                if (ref($record->{$key}) eq 'SCALAR') {
                    $record->{$key} = $self->CanonicalizeReference($record->{$key}, $record, $key);
                }
            }
            delete $record->{id};
            push @{ $output{$outtype} }, $record;
        }
    }

    print { $self->{Filehandle} } $self->JSON->encode(\%output);
}

1;
