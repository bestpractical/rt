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
use List::MoreUtils 'uniq';

use base 'RT::Migrate::Serializer';

sub Init {
    my $self = shift;

    my %args = (
        Directory           => undef,
        Force               => undef,
        FollowTickets       => 0,
        FollowTransactions  => 0,
        FollowScrips        => 1,
        FollowACL           => 1,

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

    $self->{Sync} = $args{Sync};

    $self->SUPER::Init(%args);
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

    if ($obj->isa("RT::Group")) {
        return 0 if $obj->Domain eq 'ACLEquivalence';
    }
    if ($obj->isa("RT::GroupMember")) {
        my $domain = $obj->GroupObj->Object->Domain;
        return 0 if $domain eq 'ACLEquivalence'
                 || $domain eq 'SystemInternal';
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
        object_sorter => '',
        primary_class => '',
        primary_key => 'ApplyTo',
        add_to_primary => undef,
        sort_uniq => 0,
        delete_empty => 0,
        finalize => undef,
        canonicalize_object => sub { $_->{ObjectId} },
        @_,
    );

    my $object_class = $args{object_class};
    my $object_primary_ref = $args{object_primary_ref};
    my $object_sorter = $args{object_sorter};
    my $primary_class = $args{primary_class};
    my $primary_key = $args{primary_key};
    my $add_to_primary = $args{add_to_primary};
    my $sort_uniq = $args{sort_uniq};
    my $delete_empty = $args{delete_empty};
    my $finalize = $args{finalize};
    my $canonicalize_object = $args{canonicalize_object};

    my $primary_records = $self->{Records}{$primary_class};
    if (my $objects = delete $self->{Records}{$object_class}) {
        for my $object (values %$objects) {
            my $primary = $primary_records->{ ${ $object->{$object_primary_ref} } };
            push @{ $primary->{$primary_key} }, $object;
        }

        for my $primary (values %$primary_records) {
            @{ $primary->{$primary_key} }
                = grep defined,
                  map &$canonicalize_object,
                  sort { ($a->{SortOrder}||0) <=> ($b->{SortOrder}||0)
                  || ($object_sorter ? $a->{$object_sorter} cmp $b->{$object_sorter} : 0) }
                  @{ $primary->{$primary_key} || [] };

            if ($sort_uniq) {
                @{ $primary->{$primary_key} }
                    = uniq sort
                      @{ $primary->{$primary_key} };
            }

            if ($delete_empty) {
                delete $primary->{$primary_key} if !@{ $primary->{$primary_key} };
            }

            if ($finalize) {
                $finalize->($primary);
            }

            if (ref($add_to_primary) eq 'CODE') {
                $add_to_primary->($primary);
            }
        }
    }
}

sub CanonicalizeACLs {
    my $self = shift;

    for my $ace (values %{ $self->{Records}{'RT::ACE'} }) {
        delete $ace->{PrincipalType};
        my $principal = $self->_GetObjectByRef(delete $ace->{PrincipalId});
        my $object = $self->_GetObjectByRef(delete $ace->{Object});

        if ($principal->IsGroup) {
            my $group = $principal->Object;
            my $domain = $group->Domain;
            if ($domain eq 'ACLEquivalence') {
                $ace->{UserId} = $group->InstanceObj->Name;
            }
            else {
                $ace->{GroupDomain} = $domain;
                if ($domain eq 'UserDefined') {
                    $ace->{GroupId} = $group->Name;
                }
                if ($domain eq 'SystemInternal' || $domain =~ /-Role$/) {
                    $ace->{GroupType} = $group->Name;
                }
            }
        }
        else {
            $ace->{UserId} = $principal->Object->Name;
        }

        unless ($object->isa('RT::System')) {
            $ace->{ObjectType} = ref($object);
            $ace->{ObjectId} = \($object->UID);
        }
    }
}

sub CanonicalizeUsers {
    my $self = shift;

    for my $user (values %{ $self->{Records}{'RT::User'} }) {
        delete $user->{Principal};
        delete $user->{PrincipalId};

        delete $user->{Password};
        delete $user->{AuthToken};

        my $object = RT::User->new(RT->SystemUser);
        $object->Load($user->{id});

        for my $key (keys %$user) {
            my $value = $user->{$key};
            delete $user->{$key} if !defined($value) || !length($value);
        }

        $user->{Privileged} = $object->Privileged ? JSON::true : JSON::false;
    }
}

sub CanonicalizeGroups {
    my $self = shift;

    my $records = $self->{Records}{'RT::Group'};
    for my $id (keys %$records) {
        my $group = $records->{$id};

        # no need to serialize this because role groups are automatically
        # created; but we can't exclude this in ->Observe because then we
        # lose out on the group members
        if ($group->{Domain} =~ /-Role$/) {
            delete $records->{$id};
            next;
        }

        delete $group->{Principal};
        delete $group->{PrincipalId};

        delete $group->{Instance} if $group->{Domain} eq 'UserDefined'
                                  || $group->{Domain} eq 'SystemInternal';
    }
}

sub CanonicalizeGroupMembers {
    my $self = shift;

    my $records = $self->{Records}{'RT::GroupMember'};
    for my $id (keys %$records) {
        my $record = $records->{$id};
        my $group = $self->_GetObjectByRef(delete $record->{GroupId})->Object;
        my $member = $self->_GetObjectByRef(delete $record->{MemberId})->Object;
        my $domain = $group->Domain;

        # no need to explicitly include a Nobody member
        if ($member->isa('RT::User') && $member->Name eq 'Nobody' && $group->SingleMemberRoleGroup) {
            delete $records->{$id};
            next;
        }


        $record->{Group} = $group->Name;
        $record->{GroupDomain} = $domain
            unless $domain eq 'UserDefined';
        $record->{GroupInstance} = \($group->InstanceObj->UID)
            if $domain =~ /-Role$/;

        $record->{Class} = ref($member);
        $record->{Name} = $member->Name;
    }
}

sub CanonicalizeCustomFields {
    my $self = shift;

    for my $record (values %{ $self->{Records}{'RT::CustomField'} }) {
        delete $record->{Pattern} if ($record->{Pattern}||'') eq "";
        delete $record->{UniqueValues} if !$record->{UniqueValues};
    }
}

sub CanonicalizeObjectCustomFieldValues {
    my $self = shift;

    my $records = delete $self->{Records}{'RT::ObjectCustomFieldValue'};
    for my $id ( sort { $records->{$a}{id} <=> $records->{$b}{id} } keys %$records ) {
        my $record = $records->{$id};

        if ($record->{Disabled} && !$self->{FollowDisabled}) {
            delete $records->{$id};
            next;
        }

        my $object = $self->_GetSerializedByRef(delete $record->{Object});

        my $cf = $self->_GetSerializedByRef(delete $record->{CustomField});
        next unless $cf && $cf->{Name}; # disabled CF on live object
        $record->{CustomField} = $cf->{Name};

        if ( $cf->{Type} =~ /^(?:Binary|Image)$/ && $record->{LargeContent} ) {
            $record->{ContentEncoding} = 'base64';
            $record->{LargeContent} = MIME::Base64::encode_base64($record->{LargeContent} );
        }

        delete $record->{id} unless $self->{Sync};

        push @{ $object->{CustomFields} }, $record;
    }
}

sub CanonicalizeObjectTopics {
    my $self = shift;

    my $records = delete $self->{Records}{'RT::ObjectTopic'};
    for my $id ( sort { $records->{$a}{id} <=> $records->{$b}{id} } keys %$records ) {
        my $record = $records->{$id};

        my $object = $self->_GetSerializedByRef(delete $record->{ObjectId});

        my $topic = $self->_GetSerializedByRef(delete $record->{Topic});
        $record->{Topic} = $topic->{Name};

        delete $record->{id} unless $self->{Sync};

        delete $record->{ObjectType}; # unnecessary as it's always RT::Article for now
        push @{ $object->{Topics} }, $record;
    }
}

sub CanonicalizeArticles {
    my $self = shift;

    for my $record (values %{ $self->{Records}{'RT::Article'} }) {
        delete $record->{URI};
    }
}

sub CanonicalizeAttributes {
    my $self = shift;

    for my $record (values %{ $self->{Records}{'RT::Attribute'} }) {
        if ( ( $record->{ContentType} // '' ) eq 'storable' ) {
            eval { $record->{Content} = RT::Attribute->_DeserializeContent( $record->{Content} ) };
            if ( $@ ) {
                $RT::Logger->error(
                    "Deserialization of content for attribute $record->{id} failed. Attribute was: $record->{Content}"
                );
            }
            else {
                if ( $record->{Name} =~ /HomepageSettings$/ ) {
                    my $content = $record->{Content};
                    for my $type ( qw/body sidebar/ ) {
                        if ( $content->{$type} && ref $content->{$type} eq 'ARRAY' ) {
                            for my $item ( @{ $content->{$type} } ) {
                                if ( $item->{type} eq 'saved' && $item->{name} =~ /RT::\w+-\d+-SavedSearch-(\d+)/ ) {
                                    my $id        = $1;
                                    my $attribute = RT::Attribute->new( RT->SystemUser );
                                    $attribute->Load( $id );
                                    if ( $attribute->id ) {
                                        $item->{ObjectType}  = $attribute->ObjectType;
                                        $item->{ObjectId}    = $attribute->Object->Name;
                                        $item->{Description} = $attribute->Description;
                                        delete $item->{name};
                                    }
                                }
                                delete $item->{uid};
                            }
                        }
                    }
                }
                elsif ( $record->{Name} eq 'Dashboard' ) {
                    my $content = $record->{Content}{Panes};
                    for my $type ( qw/body sidebar/ ) {
                        if ( $content->{$type} && ref $content->{$type} eq 'ARRAY' ) {
                            for my $item ( @{ $content->{$type} } ) {
                                if ( my $id = $item->{id} ) {
                                    my $attribute = RT::Attribute->new( RT->SystemUser );
                                    $attribute->Load( $id );
                                    if ( $attribute->id ) {
                                        $item->{ObjectType}  = $attribute->ObjectType;
                                        $item->{ObjectId}    = $attribute->Object->Name;
                                        $item->{Description} = $attribute->Description;
                                        delete $item->{$_} for qw/id privacy/;
                                    }
                                }
                                delete $item->{uid};
                            }
                        }
                    }
                }
                elsif ( $record->{Name} eq 'Pref-DashboardsInMenu' ) {
                    my @dashboards;
                    for my $item ( @{ $record->{Content}{dashboards} } ) {
                        if ( ref $item eq 'SCALAR' && $$item =~ /(\d+)$/ ) {
                            my $id        = $1;
                            my $attribute = RT::Attribute->new( RT->SystemUser );
                            $attribute->Load( $id );
                            my $dashboard = {};
                            if ( $attribute->id ) {
                                $dashboard->{ObjectType}  = $attribute->ObjectType;
                                $dashboard->{ObjectId}    = $attribute->Object->Name;
                                $dashboard->{Description} = $attribute->Description;
                            }
                            push @dashboards, $dashboard;
                        }
                    }
                    $record->{Content}{dashboards} = \@dashboards;
                }
            }
        }

        if ( ${$record->{Object}} =~ /^(RT::\w+)-/ ) {
            $record->{ObjectType} = $1;
        }
    }
    for my $key ( keys %{ $self->{Records}{'RT::Attribute'} } ) {
        delete $self->{Records}{'RT::Attribute'}{$key}
          if $self->{Records}{'RT::Attribute'}{$key}{Name} =~
          /^(?:UpgradeHistory|QueueCacheNeedsUpdate|CatalogCacheNeedsUpdate|CustomRoleCacheNeedsUpdate|RecentlyViewedTickets)$/;
    }
}

sub CanonicalizeObjects {
    my $self = shift;

    $self->_CanonicalizeManyToMany(
        object_class        => 'RT::ObjectCustomField',
        object_primary_ref  => 'CustomField',
        primary_class       => 'RT::CustomField',
        sort_uniq           => 1,
        canonicalize_object => sub {
            my $id = $_->{ObjectId};
            return $id if !ref($id);
            my $serialized = $self->_GetSerializedByRef($id);
            return $serialized ? $serialized->{Name} : undef;
        },
    );

    $self->_CanonicalizeManyToMany(
        object_class        => 'RT::CustomFieldValue',
        object_primary_ref  => 'CustomField',
        object_sorter       => 'Name',
        primary_class       => 'RT::CustomField',
        primary_key         => 'Values',
        delete_empty        => 1,
        canonicalize_object => sub {
            my %object = %$_;
            return if $object{Disabled} && !$self->{FollowDisabled};

            delete $object{CustomField};
            delete $object{id} unless $self->{Sync};
            delete $object{Category} if !length($object{Category});
            delete $object{Description} if !length($object{Description});
            return \%object;
        },
    );

    $self->_CanonicalizeManyToMany(
        object_class       => 'RT::ObjectClass',
        object_primary_ref => 'Class',
        primary_class      => 'RT::Class',
        sort_uniq           => 1,
        canonicalize_object => sub {
            my $id = $_->{ObjectId};
            return $id if !ref($id);
            my $serialized = $self->_GetSerializedByRef($id);
            return $serialized ? $serialized->{Name} : undef;
        },
    );

    $self->_CanonicalizeManyToMany(
        object_class       => 'RT::ObjectCustomRole',
        object_primary_ref => 'CustomRole',
        primary_class      => 'RT::CustomRole',
        sort_uniq           => 1,
        canonicalize_object => sub {
            my $id = $_->{ObjectId};
            return $id if !ref($id);
            my $serialized = $self->_GetSerializedByRef($id);
            return $serialized ? $serialized->{Name} : undef;
        },
    );

    $self->_CanonicalizeManyToMany(
        object_class        => 'RT::ObjectScrip',
        object_primary_ref  => 'Scrip',
        primary_class       => 'RT::Scrip',
        primary_key         => 'Queue',
        add_to_primary      => sub {
            my $primary = shift;
            $primary->{NoAutoGlobal} = 1 if @{ $primary->{Queue} || [] } == 0;
        },
        canonicalize_object => sub {
            my %object = %$_;
            delete $object{Scrip};
            delete $object{id} unless $self->{Sync};

            if (ref($_->{ObjectId})) {
                my $serialized = $self->_GetSerializedByRef($_->{ObjectId});
                return undef if !$serialized;
                $object{ObjectId} = $serialized->{Name};
            }

            return \%object;
        },
        finalize => sub {
            my $scrip = shift;
            @{ $scrip->{Queue} } = sort { $a->{ObjectId} cmp $b->{ObjectId} } @{ $scrip->{Queue} };
        },
    );
}

# Exclude critical system objects that should already be present in the importing side
sub ShouldExcludeObject {
    my $self = shift;
    my $class = shift;
    my $id = shift;
    my $record = shift;

    if ($class eq 'RT::User') {
        return 1 if $record->{Name} eq 'RT_System'
                 || $record->{Name} eq 'Nobody';
    }
    elsif ($class eq 'RT::ACE') {
        return 1 if ($record->{UserId}||'') eq 'Nobody' && $record->{RightName} eq 'OwnTicket';
        return 1 if ($record->{UserId}||'') eq 'RT_System' && $record->{RightName} eq 'SuperUser';
    }
    elsif ($class eq 'RT::Group') {
        return 1 if $record->{Domain} eq 'RT::System-Role'
                 || $record->{Domain} eq 'SystemInternal';
    }
    elsif ($class eq 'RT::Queue') {
        return 1 if $record->{Name} eq '___Approvals';
    }
    elsif ($class eq 'RT::GroupMember') {
        return 1 if $record->{Group} eq 'Owner'
                 && $record->{GroupDomain} =~ /-Role$/
                 && $record->{Class} eq 'RT::User'
                 && $record->{Name} eq 'Nobody';
    }

    return 0;
}

sub WriteFile {
    my $self = shift;
    my %output;

    for my $record (map { values %$_ } values %{ $self->{Records} }) {
        delete @$record{qw/Creator Created LastUpdated LastUpdatedBy/};
    }

    $self->CanonicalizeObjects;
    $self->CanonicalizeObjectCustomFieldValues;
    $self->CanonicalizeObjectTopics;
    $self->CanonicalizeACLs;
    $self->CanonicalizeUsers;
    $self->CanonicalizeGroups;
    $self->CanonicalizeGroupMembers;
    $self->CanonicalizeCustomFields;
    $self->CanonicalizeArticles;
    $self->CanonicalizeAttributes;

    my $all_records = $self->{Records};
    my $sync = $self->{Sync};

    for my $intype (keys %$all_records) {
        my $outtype = $intype;
        $outtype =~ s/^RT:://;
        $outtype = $initialdataType{$outtype} || ($outtype . 's');

        my $records = $all_records->{$intype};

        # sort by database id then serializer id for stability
        for my $id (sort {
            ($records->{$a}{id} || 0) <=> ($records->{$b}{id} || 0)
            || $a cmp $b
        } keys %$records) {
            my $record = $records->{$id};

            next if $self->ShouldExcludeObject($intype, $id, $record);

            for my $key (keys %$record) {
                if (ref($record->{$key}) eq 'SCALAR') {
                    $record->{$key} = $self->CanonicalizeReference($record->{$key}, $record, $key);
                }
            }
            delete $record->{id} unless $sync;
            delete $record->{Disabled} if !$record->{Disabled};

            push @{ $output{$outtype} }, $record;
        }
    }

    print { $self->{Filehandle} } $self->JSON->encode(\%output);
}

1;
