# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2017 Best Practical Solutions, LLC
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

=head1 NAME

  RT::Link - an RT Link object

=head1 SYNOPSIS

  use RT::Link;

=head1 DESCRIPTION

This module should never be called directly by client code. it's an internal module which
should only be accessed through exported APIs in Ticket other similar objects.

=head1 METHODS



=cut


package RT::Link;

use strict;
use warnings;



use base 'RT::Record';

sub Table {'Links'}
use Carp;
use RT::URI;



=head2 Create PARAMHASH

Create a new link object. Takes 'Base', 'Target' and 'Type'.
Returns undef on failure or a Link Id on success.

=cut

sub Create {
    my $self = shift;
    my %args = ( Base   => undef,
                 Target => undef,
                 Type   => undef,
                 @_ );

    my $base = RT::URI->new( $self->CurrentUser );
    unless ($base->FromURI( $args{'Base'} )) {
        my $msg = $self->loc("Couldn't resolve base '[_1]' into a URI.", $args{'Base'});
        $RT::Logger->warning( "$self $msg" );
        return wantarray ? (undef, $msg) : undef;
    }

    my $target = RT::URI->new( $self->CurrentUser );
    unless ($target->FromURI( $args{'Target'} )) {
        my $msg = $self->loc("Couldn't resolve target '[_1]' into a URI.", $args{'Target'});
        $RT::Logger->warning( "$self $msg" );
        return wantarray ? (undef, $msg) : undef;
    }

    my $base_id   = 0;
    my $target_id = 0;




    if ( $base->IsLocal ) {
        my $object = $base->Object;
        unless (UNIVERSAL::can($object, 'Id')) {
            return (undef, $self->loc("[_1] appears to be a local object, but can't be found in the database", $args{'Base'}));
        
        }
        $base_id = $object->Id if UNIVERSAL::isa($object, 'RT::Ticket');
    }
    if ( $target->IsLocal ) {
        my $object = $target->Object;
        unless (UNIVERSAL::can($object, 'Id')) {
            return (undef, $self->loc("[_1] appears to be a local object, but can't be found in the database", $args{'Target'}));
        
        }
        $target_id = $object->Id if UNIVERSAL::isa($object, 'RT::Ticket');
    }

    # We don't want references to ourself
    if ( $base->URI eq $target->URI ) {
        return ( 0, $self->loc("Can't link a ticket to itself") );
    }

    # }}}

    my ( $id, $msg ) = $self->SUPER::Create( Base        => $base->URI,
                                             Target      => $target->URI,
                                             LocalBase   => $base_id,
                                             LocalTarget => $target_id,
                                             Type        => $args{'Type'} );
    return ( $id, $msg );
}

 # sub LoadByParams

=head2 LoadByParams

  Load an RT::Link object from the database.  Takes three parameters
  
  Base => undef,
  Target => undef,
  Type =>undef
 
  Base and Target are expected to be integers which refer to Tickets or URIs
  Type is the link type

=cut

sub LoadByParams {
    my $self = shift;
    my %args = ( Base   => undef,
                 Target => undef,
                 Type   => undef,
                 @_ );

    my $base = RT::URI->new($self->CurrentUser);
    $base->FromURI( $args{'Base'} )
        or return (0, $self->loc("Couldn't parse Base URI: [_1]", $args{Base}));

    my $target = RT::URI->new($self->CurrentUser);
    $target->FromURI( $args{'Target'} )
        or return (0, $self->loc("Couldn't parse Target URI: [_1]", $args{Target}));

    my ( $id, $msg ) = $self->LoadByCols( Base   => $base->URI,
                                          Type   => $args{'Type'},
                                          Target => $target->URI );

    unless ($id) {
        return ( 0, $self->loc("Couldn't load link: [_1]", $msg) );
    } else {
        return ($id, $msg);
    }
}


=head2 Load

  Load an RT::Link object from the database.  Takes one parameter, the id of an entry in the links table.


=cut

sub Load {
    my $self       = shift;
    my $identifier = shift;




    if ( $identifier !~ /^\d+$/ ) {
        return ( 0, $self->loc("That's not a numerical id") );
    }
    else {
        my ( $id, $msg ) = $self->LoadById($identifier);
        unless ( $self->Id ) {
            return ( 0, $self->loc("Couldn't load link") );
        }
        return ( $id, $msg );
    }
}




=head2 TargetURI

returns an RT::URI object for the "Target" of this link.

=cut

sub TargetURI {
    my $self = shift;
    my $URI = RT::URI->new($self->CurrentUser);
    $URI->FromURI($self->Target);
    return ($URI);
}


=head2 TargetObj

=cut

sub TargetObj {
    my $self = shift;
    return $self->TargetURI->Object;
}


=head2 BaseURI

returns an RT::URI object for the "Base" of this link.

=cut

sub BaseURI {
    my $self = shift;
    my $URI = RT::URI->new($self->CurrentUser);
    $URI->FromURI($self->Base);
    return ($URI);
}


=head2 BaseObj

=cut

sub BaseObj {
  my $self = shift;
  return $self->BaseURI->Object;
}


=head2 id

Returns the current value of id.
(In the database, id is stored as int(11).)


=cut


=head2 Base

Returns the current value of Base.
(In the database, Base is stored as varchar(240).)



=head2 SetBase VALUE


Set Base to VALUE.
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, Base will be stored as a varchar(240).)


=cut


=head2 Target

Returns the current value of Target.
(In the database, Target is stored as varchar(240).)



=head2 SetTarget VALUE


Set Target to VALUE.
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, Target will be stored as a varchar(240).)


=cut


=head2 Type

Returns the current value of Type.
(In the database, Type is stored as varchar(20).)



=head2 SetType VALUE


Set Type to VALUE.
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, Type will be stored as a varchar(20).)


=cut


=head2 LocalTarget

Returns the current value of LocalTarget.
(In the database, LocalTarget is stored as int(11).)



=head2 SetLocalTarget VALUE


Set LocalTarget to VALUE.
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, LocalTarget will be stored as a int(11).)


=cut


=head2 LocalBase

Returns the current value of LocalBase.
(In the database, LocalBase is stored as int(11).)



=head2 SetLocalBase VALUE


Set LocalBase to VALUE.
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, LocalBase will be stored as a int(11).)


=cut


=head2 LastUpdatedBy

Returns the current value of LastUpdatedBy.
(In the database, LastUpdatedBy is stored as int(11).)


=cut


=head2 LastUpdated

Returns the current value of LastUpdated.
(In the database, LastUpdated is stored as datetime.)


=cut


=head2 Creator

Returns the current value of Creator.
(In the database, Creator is stored as int(11).)


=cut


=head2 Created

Returns the current value of Created.
(In the database, Created is stored as datetime.)


=cut



sub _CoreAccessible {
    {

        id =>
		{read => 1, sql_type => 4, length => 11,  is_blob => 0,  is_numeric => 1,  type => 'int(11)', default => ''},
        Base =>
		{read => 1, write => 1, sql_type => 12, length => 240,  is_blob => 0,  is_numeric => 0,  type => 'varchar(240)', default => ''},
        Target =>
		{read => 1, write => 1, sql_type => 12, length => 240,  is_blob => 0,  is_numeric => 0,  type => 'varchar(240)', default => ''},
        Type =>
		{read => 1, write => 1, sql_type => 12, length => 20,  is_blob => 0,  is_numeric => 0,  type => 'varchar(20)', default => ''},
        LocalTarget =>
		{read => 1, write => 1, sql_type => 4, length => 11,  is_blob => 0,  is_numeric => 1,  type => 'int(11)', default => '0'},
        LocalBase =>
		{read => 1, write => 1, sql_type => 4, length => 11,  is_blob => 0,  is_numeric => 1,  type => 'int(11)', default => '0'},
        LastUpdatedBy =>
		{read => 1, auto => 1, sql_type => 4, length => 11,  is_blob => 0,  is_numeric => 1,  type => 'int(11)', default => '0'},
        LastUpdated =>
		{read => 1, auto => 1, sql_type => 11, length => 0,  is_blob => 0,  is_numeric => 0,  type => 'datetime', default => ''},
        Creator =>
		{read => 1, auto => 1, sql_type => 4, length => 11,  is_blob => 0,  is_numeric => 1,  type => 'int(11)', default => '0'},
        Created =>
		{read => 1, auto => 1, sql_type => 11, length => 0,  is_blob => 0,  is_numeric => 0,  type => 'datetime', default => ''},

 }
};

RT::Base->_ImportOverlays();

1;
