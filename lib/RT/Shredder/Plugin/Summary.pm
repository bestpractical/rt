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

package RT::Shredder::Plugin::Summary;

use strict;
use warnings FATAL => 'all';

use base qw(RT::Shredder::Plugin::SQLDump);

sub AppliesToStates { return 'before any action' }

sub TestArgs
{
    my $self = shift;
    my %args = (file_name => '', @_);
    unless( $args{'file_name'} ) {
        require POSIX;
        $args{'file_name'} = POSIX::strftime( "summary-%Y%m%dT%H%M%S.XXXX.txt", gmtime );
    }
    return $self->SUPER::TestArgs( %args );
}

sub Run
{
    my $self = shift;
    my %args = ( Object => undef, @_ );
    my $class = ref $args{'Object'};
    $class =~ s/^RT:://;
    $class =~ s/:://g;
    my $method = 'WriteDown'. $class;
    $method = 'WriteDownDefault' unless $self->can($method);
    return $self->$method( %args );
}

my %skip_refs_to = ();

sub WriteDownDefault {
    my $self = shift;
    my %args = ( Object => undef, @_ );
    return $self->_WriteDownHash(
        $args{'Object'},
        $self->_MakeHash( $args{'Object'} ),
    );
}

# TODO: cover other objects
# ACE.pm
# Attachment.pm
# CustomField.pm
# CustomFieldValue.pm
# GroupMember.pm
# Group.pm
# Link.pm
# ObjectCustomFieldValue.pm
# Principal.pm
# Queue.pm
# Ticket.pm
# User.pm

# ScripAction.pm - works fine with defaults
# ScripCondition.pm - works fine with defaults
# Template.pm - works fine with defaults

sub WriteDownCachedGroupMember { return 1 }
sub WriteDownPrincipal { return 1 }

sub WriteDownGroup {
    my $self = shift;
    my %args = ( Object => undef, @_ );
    if ( $args{'Object'}->RoleClass ) {
        return $skip_refs_to{ $args{'Object'}->UID } = 1;
    }
    return $self->WriteDownDefault( %args );
}

sub WriteDownTransaction {
    my $self = shift;
    my %args = ( Object => undef, @_ );

    my $props = $self->_MakeHash( $args{'Object'} );
    $props->{'Object'} = delete $props->{'ObjectType'};
    $props->{'Object'} .= '-'. delete $props->{'ObjectId'}
        if $props->{'ObjectId'};
    return 1 if $skip_refs_to{ $props->{'Object'} };

    delete $props->{$_} foreach grep
        !defined $props->{$_} || $props->{$_} eq '', keys %$props;

    return $self->_WriteDownHash( $args{'Object'}, $props );
}

sub WriteDownScrip {
    my $self = shift;
    my %args = ( Object => undef, @_ );
    my $props = $self->_MakeHash( $args{'Object'} );
    $props->{'Action'} = $args{'Object'}->ActionObj->Name;
    $props->{'Condition'} = $args{'Object'}->ConditionObj->Name;
    $props->{'Template'} = $args{'Object'}->Template;
    $props->{'Queue'} = $args{'Object'}->QueueObj->Name || 'global';

    return $self->_WriteDownHash( $args{'Object'}, $props );
}

sub _MakeHash {
    my ($self, $obj) = @_;
    my $hash = $self->__MakeHash( $obj );
    foreach (grep exists $hash->{$_}, qw(Creator LastUpdatedBy)) {
        my $method = $_ .'Obj';
        my $u = $obj->$method();
        $hash->{ $_ } = $u->EmailAddress || $u->Name || $u->UID;
    }
    return $hash;
}

sub __MakeHash {
    my ($self, $obj) = @_;
    my %hash;
    $hash{ $_ } = $obj->$_()
        foreach sort keys %{ $obj->_ClassAccessible };
    return \%hash;
}

sub _WriteDownHash {
    my ($self, $obj, $hash) = @_;
    return (0, 'no handle') unless my $fh = $self->{'opt'}{'file_handle'};

    print $fh "=== ". $obj->UID ." ===\n"
        or return (0, "Couldn't write to filehandle");

    foreach my $key( sort keys %$hash ) {
        my $val = $hash->{ $key };
        next unless defined $val;
        $val =~ s/\n/\n /g;
        print $fh $key .': '. $val ."\n"
            or return (0, "Couldn't write to filehandle");
    }
    print $fh "\n" or return (0, "Couldn't write to filehandle");
    return 1;
}

1;
