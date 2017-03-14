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

sub CanonicalizeReference {
    my $self    = shift;
    my $ref     = ${ shift(@_) };
    my $context = shift;
    my $for_key = shift;

    my ($class, $id) = $ref =~ /^(.*?)-(.*)/
        or return $ref;
    my $record = $self->{Records}{$class}{$ref};
    return $record->{Name} || $ref;
}

sub _CanonicalizeObjectType {
    my $self = shift;
    my $object_class = shift;
    my $object_primary_ref = shift;
    my $primary_class = shift;

    if (my $objects = delete $self->{Records}{$object_class}) {
        for my $object (values %$objects) {
            my $primary = $self->{Records}{$primary_class}{ ${ $object->{$object_primary_ref} } };
            push @{ $primary->{ApplyTo} }, $object;
        }

        for my $primary (values %{ $self->{Records}{$primary_class} }) {
            @{ $primary->{ApplyTo} } = map { $_->{ObjectId} }
                                       sort { $a->{SortOrder} <=> $b->{SortOrder} }
                                       @{ $primary->{ApplyTo} || [] };
        }
    }
}

sub CanonicalizeObjects {
    my $self = shift;
    $self->_CanonicalizeObjectType('RT::ObjectCustomField' => CustomField => 'RT::CustomField');
    $self->_CanonicalizeObjectType('RT::ObjectClass' => Class => 'RT::Class');
}

sub WriteFile {
    my $self = shift;
    my %output;

    $self->CanonicalizeObjects;

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
            push @{ $output{$outtype} }, $record;
        }
    }

    print { $self->{Filehandle} } $self->JSON->encode(\%output);
}

1;
