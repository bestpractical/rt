# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2025 Best Practical Solutions, LLC
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

  RT::ScripCondition - RT scrip conditional

=head1 SYNOPSIS

  use RT::ScripCondition;


=head1 DESCRIPTION

This module should never be called directly by client code. it's an internal module which
should only be accessed through exported APIs in other modules.



=head1 METHODS

=cut


package RT::ScripCondition;

use strict;
use warnings;

use base 'RT::Record';
use Role::Basic 'with';
with "RT::Record::Role::LookupType";

sub Table {'ScripConditions'}

sub _Accessible  {
    my $self = shift;
    my %Cols = ( Name  => 'read',
                 Description => 'read',
                 ApplicableTransTypes => 'read',
                 ExecModule  => 'read',
                 Argument  => 'read',
                 LookupType => 'read',
                 Creator => 'read/auto',
                 Created => 'read/auto',
                 LastUpdatedBy => 'read/auto',
                 LastUpdated => 'read/auto'
               );
    return($self->SUPER::_Accessible(@_, %Cols));
}


=head2 Create
  
  Takes a hash. Creates a new Condition entry.
  should be better documented.

=cut

sub Create {
    my $self = shift;
    my %args = (
        LookupType => 'RT::Queue-RT::Ticket',
        @_
    );

    my ( $val, $msg ) = $self->ValidateName( $args{'Name'}, $args{LookupType} );
    return ( 0, $msg ) unless $val;

    ( $val, $msg ) = $self->ValidateExecModule( $args{ExecModule}, $args{LookupType} );
    return ( 0, $msg ) unless $val;

    return $self->SUPER::Create(%args);
}

=head2 SetName

Check to make sure name is not already in use

=cut

sub SetName {
    my $self  = shift;
    my $Value = shift;

    my ( $val, $message ) = $self->ValidateName($Value, $self->LookupType);
    if ($val) {
        return $self->_Set( Field => 'Name', Value => $Value );
    }
    else {
        return ( 0, $message );
    }
}

=head2 ValidateName STRING LOOKUPTYPE

Returns either (0, "failure reason") or 1 depending on whether the given
name is valid.

=cut

sub ValidateName {
    my $self = shift;
    my $name = shift;
    my $type = shift || $self->LookupType || 'RT::Queue-RT::Ticket';

    return ( 0, $self->loc('empty name') ) unless defined $name && length $name;

    my $TempCondition = RT::ScripCondition->new( RT->SystemUser );
    $TempCondition->LoadByCols( Name => $name, LookupType => $type );

    if ( $TempCondition->id && ( !$self->id || $TempCondition->id != $self->id ) ) {
        return ( 0, $self->loc('Name in use') );
    }
    else {
        return 1;
    }
}


=head2 SetExecModule MODULE

Update ExecModule to MODULE if it's valid.

=cut

sub SetExecModule {
    my $self   = shift;
    my $module = shift;

    my ( $val, $message ) = $self->ValidateExecModule($module);
    if ($val) {
        return $self->_Set( Field => 'ExecModule', Value => $module );
    }
    else {
        return ( 0, $message );
    }
}


=head2 ValidateExecModule MODULE

Returns either (0, "failure reason") or 1 depending on whether the given
MODULE is valid.

=cut

sub ValidateExecModule {
    my $self   = shift;
    my $module = shift;
    return ( 0, $self->loc('Empty module') ) unless defined $module && length $module;

    my $class = 'RT::Condition::' . $module;
    my $type  = shift || $self->LookupType || 'RT::Queue-RT::Ticket';

    if ( RT::StaticUtil::RequireModule($class) ) {
        return ( 0, $self->loc( 'Condition module [_1] does not support LookupType [_2]', $module, $type ) )
            unless $class->SupportsLookupType($type);
    }
    else {
        RT->Logger->warning("Require of condition module $module failed: $@");
        return ( 0, $self->loc( "Require of condition module [_1] failed", $module ) );
    }

    return 1;
}

=head2 Delete

No API available for deleting things just yet.

=cut

sub Delete {
    my $self = shift;

    unless ( $self->CurrentUser->HasRight( Object => RT->System, Right => 'ModifyScrips' ) ) {
        return ( 0, $self->loc('Permission Denied') );
    }

    my $scrips = RT::Scrips->new( RT->SystemUser );
    $scrips->Limit( FIELD => 'ScripCondition', VALUE => $self->id );
    if ( $scrips->Count ) {
        return ( 0, $self->loc('Condition is in use') );
    }

    return $self->SUPER::Delete(@_);
}

sub UsedBy {
    my $self = shift;

    my $scrips = RT::Scrips->new( $self->CurrentUser );
    $scrips->Limit( FIELD => 'ScripCondition', VALUE => $self->Id );
    return $scrips;
}


=head2 Load IDENTIFIER

Loads a condition takes a name or ScripCondition id.

=cut

sub Load  {
    my $self = shift;
    my $identifier = shift;

    unless (defined $identifier) {
        return (undef);
    }

    if ($identifier !~ /\D/) {
        return ($self->SUPER::LoadById($identifier));
    }
    else {
        return ($self->LoadByCol('Name', $identifier));
    }
}


=head2 LoadCondition  HASH

takes a hash which has the following elements:  TransactionObj and TicketObj.
Loads the Condition module in question.

=cut


sub LoadCondition  {
    my $self = shift;
    my %args = ( TransactionObj => undef,
                 TicketObj => undef,
                 @_ );

    my $module = $self->ExecModule;
    my $type = 'RT::Condition::' . $module;
    RT::StaticUtil::RequireModule($type) or die "Require of $type condition module failed.\n$@\n";

    return $self->{'Condition'} = $type->new(
        ScripConditionObj => $self,
        Object => $args{'Object'},
        TicketObj => $args{'TicketObj'},
        AssetObj => $args{'AssetObj'},
        ArticleObj => $args{'ArticleObj'},
        ScripObj => $args{'ScripObj'},
        TransactionObj => $args{'TransactionObj'},
        Argument => $self->Argument,
        ApplicableTransTypes => $self->ApplicableTransTypes,
        CurrentUser => $self->CurrentUser
    );
}




=head2 Describe 

Helper method to call the condition module's Describe method.

=cut

sub Describe  {
    my $self = shift;
    return ($self->{'Condition'}->Describe());
    
}


=head2 IsApplicable

Helper method to call the condition module's IsApplicable method.

=cut

sub IsApplicable  {
    my $self = shift;
    return ($self->{'Condition'}->IsApplicable());
    
}



=head2 id

Returns the current value of id.
(In the database, id is stored as int(11).)


=cut


=head2 Name

Returns the current value of Name.
(In the database, Name is stored as varchar(200).)



=head2 SetName VALUE


Set Name to VALUE.
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, Name will be stored as a varchar(200).)


=cut


=head2 Description

Returns the current value of Description.
(In the database, Description is stored as varchar(255).)



=head2 SetDescription VALUE


Set Description to VALUE.
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, Description will be stored as a varchar(255).)


=cut


=head2 ExecModule

Returns the current value of ExecModule.
(In the database, ExecModule is stored as varchar(60).)



=head2 SetExecModule VALUE


Set ExecModule to VALUE.
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, ExecModule will be stored as a varchar(60).)


=cut


=head2 Argument

Returns the current value of Argument.
(In the database, Argument is stored as varbinary(255).)



=head2 SetArgument VALUE


Set Argument to VALUE.
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, Argument will be stored as a varbinary(255).)


=cut


=head2 ApplicableTransTypes

Returns the current value of ApplicableTransTypes.
(In the database, ApplicableTransTypes is stored as varchar(60).)



=head2 SetApplicableTransTypes VALUE


Set ApplicableTransTypes to VALUE.
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, ApplicableTransTypes will be stored as a varchar(60).)


=cut

=head2 LookupType

Returns the current value of LookupType.
(In the database, LookupType is stored as varchar(255).)

=cut

=head2 Creator

Returns the current value of Creator.
(In the database, Creator is stored as int(11).)


=cut


=head2 Created

Returns the current value of Created.
(In the database, Created is stored as datetime.)


=cut


=head2 LastUpdatedBy

Returns the current value of LastUpdatedBy.
(In the database, LastUpdatedBy is stored as int(11).)


=cut


=head2 LastUpdated

Returns the current value of LastUpdated.
(In the database, LastUpdated is stored as datetime.)


=cut



sub _CoreAccessible {
    {

        id =>
                {read => 1, sql_type => 4, length => 11,  is_blob => 0,  is_numeric => 1,  type => 'int(11)', default => ''},
        Name =>
                {read => 1, write => 1, sql_type => 12, length => 200,  is_blob => 0,  is_numeric => 0,  type => 'varchar(200)', default => ''},
        Description =>
                {read => 1, write => 1, sql_type => 12, length => 255,  is_blob => 0,  is_numeric => 0,  type => 'varchar(255)', default => ''},
        ExecModule =>
                {read => 1, write => 1, sql_type => 12, length => 60,  is_blob => 0,  is_numeric => 0,  type => 'varchar(60)', default => ''},
        Argument =>
                {read => 1, write => 1, sql_type => 12, length => 255,  is_blob => 0,  is_numeric => 0,  type => 'varbinary(255)', default => ''},
        ApplicableTransTypes =>
                {read => 1, write => 1, sql_type => 12, length => 60,  is_blob => 0,  is_numeric => 0,  type => 'varchar(60)', default => ''},
        LookupType =>
                {read => 1, write => 1, sql_type => 12, length => 255,  is_blob => 0,  is_numeric => 0,  type => 'varchar(255)', default => ''},
        Creator =>
                {read => 1, auto => 1, sql_type => 4, length => 11,  is_blob => 0,  is_numeric => 1,  type => 'int(11)', default => '0'},
        Created =>
                {read => 1, auto => 1, sql_type => 11, length => 0,  is_blob => 0,  is_numeric => 0,  type => 'datetime', default => ''},
        LastUpdatedBy =>
                {read => 1, auto => 1, sql_type => 4, length => 11,  is_blob => 0,  is_numeric => 1,  type => 'int(11)', default => '0'},
        LastUpdated =>
                {read => 1, auto => 1, sql_type => 11, length => 0,  is_blob => 0,  is_numeric => 0,  type => 'datetime', default => ''},

 }
};

sub PreInflate {
    my $class = shift;
    my ($importer, $uid, $data) = @_;

    $class->SUPER::PreInflate( $importer, $uid, $data );

    return not $importer->SkipBy( "Name", $class, $uid, $data );
}

sub __DependsOn {
    my $self = shift;
    my %args = (
        Shredder => undef,
        Dependencies => undef,
        @_,
    );
    my $deps = $args{'Dependencies'};

# Scrips
    my $objs = RT::Scrips->new( $self->CurrentUser );
    $objs->Limit( FIELD => 'ScripCondition', VALUE => $self->Id );
    $deps->_PushDependencies(
        BaseObject => $self,
        Flags => RT::Shredder::Constants::DEPENDS_ON,
        TargetObjects => $objs,
        Shredder => $args{'Shredder'}
    );

    return $self->SUPER::__DependsOn( %args );
}

RT::Base->_ImportOverlays();

1;
