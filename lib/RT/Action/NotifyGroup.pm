=head1 NAME

RT::Action::NotifyGroup - RT Action that sends notifications to groups and/or users

=head1 DESCRIPTION

RT action module that allow you to notify particular groups and/or users.
Distribution is shipped with C<rt-notify-group-admin> script that
is command line tool for managing NotifyGroup scrip actions. For more
more info see its documentation.

=cut

package RT::Action::NotifyGroup;

use strict;
use warnings;
use base qw(RT::Action::Notify);

require RT::User;
require RT::Group;

=head1 METHODS

=head2 SetRecipients

Sets the recipients of this message to Groups and/or Users.

=cut

sub SetRecipients {
    my $self = shift;

    my $arg = $self->Argument;

    my $old_arg = eval { Storable::thaw( $arg ) };
    unless( $@ ) {
        $arg = $self->__ConvertOldArg( $old_arg );
    }

    foreach( $self->__SplitArg( $arg ) ) {
        $self->_HandleArgument( $_ );
    }

    my $creator = $self->TransactionObj->CreatorObj->EmailAddress();
    unless( $RT::NotifyActor ) {
        @{ $self->{'To'} } = grep ( !/^\Q$creator\E$/, @{ $self->{'To'} } );
    }

    $self->{'seen_ueas'} = {};

    return 1;
}

sub _HandleArgument {
    my $self = shift;
    my $instance = shift;
    
    my $obj = RT::Principal->new( $RT::SystemUser );
    $obj->Load( $instance );
    unless( $obj->id ) {
        $RT::Logger->error( "Couldn't load principal #$instance" );
        return;
    }
    if( $obj->Disabled ) {
        $RT::Logger->info( "Principal #$instance is disabled => skip" );
        return;
    }
    if( !$obj->PrincipalType ) {
        $RT::Logger->crit( "Principal #$instance has empty type" );
    } elsif( lc $obj->PrincipalType eq 'user' ) {
        $self->__HandleUserArgument( $obj->Object );
    } elsif( lc $obj->PrincipalType eq 'group' ) {
        $self->__HandleGroupArgument( $obj->Object );
    } else {
        $RT::Logger->info( "Principal #$instance has unsupported type" );
    }
    return;
}

sub __HandleUserArgument {
    my $self = shift;
    my $obj = shift;
    
    my $uea = $obj->EmailAddress;
    unless( $uea ) {
        $RT::Logger->warning( "User #". $obj->id ." has no email address" );
        return;
    }
    $self->__PushUserAddress( $uea );
}

sub __HandleGroupArgument {
    my $self = shift;
    my $obj = shift;

    my $members = $obj->UserMembersObj;
    while( my $m = $members->Next ) {
        $self->__HandleUserArgument( $m );
    }
}

sub __SplitArg {
    return split /[^0-9]+/, $_[1];
}

sub __ConvertOldArg {
    my $self = shift;
    my $arg = shift;
    my @res;
    foreach my $r ( @{ $arg } ) {
        my $obj;
        next unless $r->{'Type'};
        if( lc $r->{'Type'} eq 'user' ) {
            $obj = RT::User->new( $RT::SystemUser );
        } elsif ( lc $r->{'Type'} eq 'user' ) {
            $obj = RT::Group->new( $RT::SystemUser );
        } else {
            next;
        }
        $obj->Load( $r->{'Instance'} );
        my $id = $obj->id;
        next unless( $id );

        push @res, $id;
    }

    return join ';', @res;
}

sub __PushUserAddress {
    my $self = shift;
    my $uea = shift;
    push @{ $self->{'To'} }, $uea unless $self->{'seen_ueas'}{ $uea }++;
    return;
}


=head1 AUTHOR

Ruslan U. Zakirov E<lt>ruz@bestpractical.comE<gt>

L<RT::Action::NotifyGroupAsComment>, F<rt-notify-group-admin>

=cut

1;
