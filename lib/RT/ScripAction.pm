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

=head1 NAME

RT::ScripAction - RT Action object

=head1 DESCRIPTION

This module should never be called directly by client code. it's an
internal module which should only be accessed through exported APIs
in other modules.

=cut


package RT::ScripAction;

use strict;
use warnings;

use base 'RT::Record';


sub Table {'ScripActions'}

use RT::Template;

sub _Accessible  {
    my $self = shift;
    my %Cols = (
        Name  => 'read',
        Description => 'read',
        ExecModule  => 'read',
        Argument  => 'read',
        Creator => 'read/auto',
        Created => 'read/auto',
        LastUpdatedBy => 'read/auto',
        LastUpdated => 'read/auto'
    );
    return($self->SUPER::_Accessible(@_, %Cols));
}


=head1 METHODS

=head2 Create

Takes a hash. Creates a new Action entry.

=cut

sub Create  {
    my $self = shift;
    #TODO check these args and do smart things.
    return($self->SUPER::Create(@_));
}

sub Delete {
    my $self = shift;

    unless ( $self->CurrentUser->HasRight( Object => RT->System, Right => 'ModifyScrips' ) ) {
        return ( 0, $self->loc('Permission Denied') );
    }

    my $scrips = RT::Scrips->new( RT->SystemUser );
    $scrips->Limit( FIELD => 'ScripAction', VALUE => $self->id );
    if ( $scrips->Count ) {
        return ( 0, $self->loc('Action is in use') );
    }

    return $self->SUPER::Delete(@_);
}

sub UsedBy {
    my $self = shift;

    my $scrips = RT::Scrips->new( $self->CurrentUser );
    $scrips->Limit( FIELD => 'ScripAction', VALUE => $self->Id );
    return $scrips;
}


=head2 Load IDENTIFIER

Loads an action by its Name.

Returns: Id, Error Message

=cut

sub Load  {
    my $self = shift;
    my $identifier = shift;

    if (!$identifier) {
        return wantarray ? (0, $self->loc('Input error')) : 0;
    }

    my ($ok, $msg);
    if ($identifier !~ /\D/) {
        ($ok, $msg) = $self->SUPER::Load($identifier);
    }
    else {
        ($ok, $msg) = $self->LoadByCol('Name', $identifier);
    }

    return wantarray ? ($ok, $msg) : $ok;
}


=head2 LoadAction HASH

Takes a hash consisting of TicketObj and TransactionObj.  Loads an RT::Action:: module.

=cut

sub LoadAction  {
    my $self = shift;
    my %args = (
        TransactionObj => undef,
        TicketObj => undef,
        ScripObj => undef,
        @_
    );

    # XXX: this whole block goes with TemplateObj method
    unless ( @_ && exists $args{'TemplateObj'} ) {
        local $self->{_TicketObj} = $args{TicketObj};
        $args{'TemplateObj'} = $self->TemplateObj;
    }
    else {
        $self->{'TemplateObj'} = $args{'TemplateObj'};
    }

    my $module = $self->ExecModule;
    my $type = 'RT::Action::' . $module;
    $type->require or die "Require of $type action module failed.\n$@\n";

    return $self->{'Action'} = $type->new(
        %args,
        Argument       => $self->Argument,
        CurrentUser    => $self->CurrentUser,
        ScripActionObj => $self,
    );
}

sub Prepare  {
    my $self = shift;
    $self->{_Message_ID} = 0;
    return $self->Action->Prepare( @_ );
}

sub Commit  {
    my $self = shift;
    return $self->Action->Commit( @_ );
}

sub Describe  {
    my $self = shift;
    return $self->Action->Describe( @_ );
}

=head2 Action

Return the actual RT::Action object for this scrip.

=cut

sub Action {
    my $self = shift;
    return $self->{'Action'};
}

=head2 id

Returns the current value of id.
(In the database, id is stored as int(11).)


=head2 Name

Returns the current value of Name.
(In the database, Name is stored as varchar(200).)

=head2 SetName VALUE

Set Name to VALUE.
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, Name will be stored as a varchar(200).)


=head2 Description

Returns the current value of Description.
(In the database, Description is stored as varchar(255).)

=head2 SetDescription VALUE

Set Description to VALUE.
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, Description will be stored as a varchar(255).)


=head2 ExecModule

Returns the current value of ExecModule.
(In the database, ExecModule is stored as varchar(60).)

=head2 SetExecModule VALUE

Set ExecModule to VALUE.
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, ExecModule will be stored as a varchar(60).)


=head2 Argument

Returns the current value of Argument.
(In the database, Argument is stored as varbinary(255).)

=head2 SetArgument VALUE

Set Argument to VALUE.
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, Argument will be stored as a varbinary(255).)


=head2 Creator

Returns the current value of Creator.
(In the database, Creator is stored as int(11).)

=head2 Created

Returns the current value of Created.
(In the database, Created is stored as datetime.)

=head2 LastUpdatedBy

Returns the current value of LastUpdatedBy.
(In the database, LastUpdatedBy is stored as int(11).)

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
    $objs->Limit( FIELD => 'ScripAction', VALUE => $self->Id );
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
