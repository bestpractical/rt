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

=head1 name

  RT::Model::Link - an RT Link object

=head1 SYNOPSIS

  use RT::Model::Link;

=head1 DESCRIPTION

This module should never be called directly by client code. it's an internal module which
should only be accessed through exported APIs in Ticket other similar objects.

=head1 METHODS



=cut

use warnings;
use strict;

package RT::Model::Link;
use base qw/RT::Record/;
use strict;
no warnings qw(redefine);
sub table {'Links'}
use Jifty::DBI::Schema;
use Jifty::DBI::Record schema {
    column target => type is 'varchar(240)', max_length is 240, default is '';
    column Base   => type is 'varchar(240)', max_length is 240, default is '';
    column LocalTarget => type is 'int(11)', max_length is 11, default is '0';
    column Creator     => type is 'int(11)', max_length is 11, default is '0';
    column type => type is 'varchar(20)', max_length is 20, default is '';
    column
        LastUpdatedBy => type is 'int(11)',
        max_length is 11, default is '0';
    column Created => type is 'datetime', default is '';
    column LocalBase => type is 'int(11)', max_length is 11, default is '0';
    column LastUpdated => type is 'datetime', default is '';

};

use Carp;
use RT::URI;

# {{{ sub create

=head2 Create PARAMHASH

Create a new link object. Takes 'Base', 'Target' and 'type'.
Returns undef on failure or a Link id on success.

=cut

sub create {
    my $self = shift;
    my %args = (
        Base   => undef,
        Target => undef,
        type   => undef,
        @_
    );

    my $base = RT::URI->new;
    $base->from_uri( $args{'Base'} );

    unless ( $base->resolver && $base->scheme ) {
        my $msg
            = _( "Couldn't resolve base '%1' into a URI.", $args{'Base'} );
        Jifty->log->warn("$self $msg\n");

        if (wantarray) {
            return ( undef, $msg );
        } else {
            return (undef);
        }
    }

    my $target = RT::URI->new;
    $target->from_uri( $args{'Target'} );

    unless ( $target->resolver ) {
        my $msg = _( "Couldn't resolve target '%1' into a URI.",
            $args{'Target'} );
        Jifty->log->warn("$self $msg\n");

        if (wantarray) {
            return ( undef, $msg );
        } else {
            return (undef);
        }
    }

    my $base_id   = 0;
    my $target_id = 0;

    if ( $base->is_local ) {
        unless ( UNIVERSAL::can( $base->object, 'id' ) ) {
            return (
                undef,
                _(  "%1 appears to be a local object, but can't be found in the database",
                    $args{'Base'}
                )
            );

        }
        $base_id = $base->object->id;
    }
    if ( $target->is_local ) {
        unless ( UNIVERSAL::can( $target->object, 'id' ) ) {
            return (
                undef,
                _(  "%1 appears to be a local object, but can't be found in the database",
                    $args{'Target'}
                )
            );

        }
        $target_id = $target->object->id;
    }

    # {{{ We don't want references to ourself
    if ( $base->uri eq $target->uri ) {
        return ( 0, _("Can't link a ticket to itself") );
    }

    # }}}

    my ( $id, $msg ) = $self->SUPER::create(
        Base        => $base->uri,
        Target      => $target->uri,
        LocalBase   => $base_id,
        LocalTarget => $target_id,
        type        => $args{'type'}
    );
    return ( $id, $msg );
}

# }}}
# {{{ sub loadByParams

=head2 LoadByParams

  Load an RT::Model::Link object from the database.  Takes three parameters
  
  Base => undef,
  Target => undef,
  type =>undef
 
  Base and Target are expected to be integers which refer to Tickets or URIs
  type is the link type

=cut

sub load_by_params {
    my $self = shift;
    my %args = (
        Base   => undef,
        Target => undef,
        type   => undef,
        @_
    );

    my $base = RT::URI->new;
    $base->from_uri( $args{'Base'} );

    my $target = RT::URI->new;
    $target->from_uri( $args{'Target'} );

    unless ( $base->resolver && $target->resolver ) {
        return ( 0, _("Couldn't load link") );
    }

    my ( $id, $msg ) = $self->load_by_cols(
        Base   => $base->uri,
        type   => $args{'type'},
        Target => $target->uri
    );

    unless ($id) {
        return ( 0, _("Couldn't load link") );
    }
}

# }}}
# {{{ sub load

=head2 Load

  Load an RT::Model::Link object from the database.  Takes one parameter, the id of an entry in the links table.


=cut

sub load {
    my $self       = shift;
    my $identifier = shift;

    if ( $identifier !~ /^\d+$/ ) {
        return ( 0, _("That's not a numerical id") );
    } else {
        my ( $id, $msg ) = $self->load_by_id($identifier);
        unless ( $self->id ) {
            return ( 0, _("Couldn't load link") );
        }
        return ( $id, $msg );
    }
}

# }}}

# {{{ target_uri

=head2 target_uri

returns an RT::URI object for the "Target" of this link.

=cut

sub target_uri {
    my $self = shift;
    my $URI  = RT::URI->new;
    $URI->from_uri( $self->target );
    return ($URI);
}

# }}}
# {{{ sub TargetObj

=head2 TargetObj

=cut

sub target_obj {
    my $self = shift;
    return $self->target_uri->object;
}

# }}}

# {{{ base_uri

=head2 base_uri

returns an RT::URI object for the "Base" of this link.

=cut

sub base_uri {
    my $self = shift;
    my $URI  = RT::URI->new;
    $URI->from_uri( $self->base );
    return ($URI);
}

# }}}
# {{{ sub base_obj

=head2 base_obj

=cut

sub base_obj {
    my $self = shift;
    return $self->base_uri->object;
}

# }}}

1;

