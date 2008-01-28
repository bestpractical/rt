# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2007 Best Practical Solutions, LLC
#                                          <jesse@bestpractical.com>
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
# http://www.gnu.org/copyleft/gpl.html.
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

sub applies_to_states { return 'before any action' }

sub TestArgs {
    my $self = shift;
    my %args = ( file_name => '', @_ );
    unless ( $args{'file_name'} ) {
        require POSIX;
        $args{'file_name'}
            = POSIX::strftime( "summary-%Y%m%dT%H%M%S.XXXX.txt", gmtime );
    }
    return $self->SUPER::TestArgs(%args);
}

sub Run {
    my $self  = shift;
    my %args  = ( Object => undef, @_ );
    my $class = ref $args{'Object'};
    $class =~ s/^RT:://;
    $class =~ s/:://g;
    my $method = 'WriteDown' . $class;
    $method = 'WriteDownDefault' unless $self->can($method);
    return $self->$method(%args);
    return 1;
}

my %skip_refs_to = ();

sub write_down_default {
    my $self = shift;
    my %args = ( Object => undef, @_ );
    return $self->_write_down_hash( $args{'Object'},
        $self->_make_hash( $args{'Object'} ),
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

sub write_down_cached_group_member { return 1 }
sub write_down_principal           { return 1 }

sub write_down_group {
    my $self = shift;
    my %args = ( Object => undef, @_ );
    if ( $args{'Object'}->Domain =~ /-Role$/ ) {
        return $skip_refs_to{ $args{'Object'}->_as_string } = 1;
    }
    return $self->write_down_default(%args);
}

sub write_down_transaction {
    my $self = shift;
    my %args = ( Object => undef, @_ );

    my $props = $self->_make_hash( $args{'Object'} );
    $props->{'Object'} = delete $props->{'object_type'};
    $props->{'Object'} .= '-' . delete $props->{'object_id'}
        if $props->{'object_id'};
    return 1 if $skip_refs_to{ $props->{'Object'} };

    delete $props->{$_}
        foreach grep !defined $props->{$_} || $props->{$_} eq '',
        keys %$props;

    return $self->_write_down_hash( $args{'Object'}, $props );
}

sub write_down_scrip {
    my $self  = shift;
    my %args  = ( Object => undef, @_ );
    my $props = $self->_make_hash( $args{'Object'} );
    $props->{'Action'}    = $args{'Object'}->action_obj->name;
    $props->{'Condition'} = $args{'Object'}->condition_obj->name;
    $props->{'Template'}  = $args{'Object'}->template_obj->name;
    $props->{'Queue'}     = $args{'Object'}->queue_obj->name || 'global';

    return $self->_write_down_hash( $args{'Object'}, $props );
}

sub _make_hash {
    my ( $self, $obj ) = @_;
    my $hash = $self->__make_hash($obj);
    foreach ( grep exists $hash->{$_}, qw(Creator LastUpdatedBy) ) {
        my $method = $_ . 'Obj';
        my $u      = $obj->$method();
        $hash->{$_} = $u->email || $u->name || $u->_as_string;
    }
    return $hash;
}

sub __make_hash {
    my ( $self, $obj ) = @_;
    my %hash;
    $hash{$_} = $obj->$_() foreach sort keys %{ $obj->_ClassAccessible };
    return \%hash;
}

sub _write_down_hash {
    my ( $self, $obj, $hash ) = @_;
    return ( 0, 'no handle' ) unless my $fh = $self->{'opt'}{'file_handle'};

    print $fh "=== " . $obj->_as_string . " ===\n"
        or return ( 0, "Couldn't write to filehandle" );

    foreach my $key ( sort keys %$hash ) {
        my $val = $hash->{$key};
        next unless defined $val;
        $val =~ s/\n/\n /g;
        print $fh $key . ': ' . $val . "\n"
            or return ( 0, "Couldn't write to filehandle" );
    }
    print $fh "\n" or return ( 0, "Couldn't write to filehandle" );
    return 1;
}

1;
