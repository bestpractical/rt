# $Header: /raid/cvsroot/rt/lib/RT/Template.pm,v 1.4 2002/01/24 15:34:30 jesse Exp $
# Copyright 1996-2002 Jesse Vincent <jesse@bestpractical.com>
# Portions Copyright 2000 Tobias Brox <tobix@cpan.org> 
# Released under the terms of the GNU General Public License

=head1 NAME

  RT::Template - RT's template object

=head1 SYNOPSIS

  use RT::Template;

=head1 DESCRIPTION


=head1 METHODS

=begin testing

ok(require RT::Template);

=end testing

=cut

no warnings qw(redefine);


use MIME::Entity;
use MIME::Parser;

# {{{ sub _Accessible 

sub _Accessible {
    my $self = shift;
    my %Cols = (
        id            => 'read',
        Name          => 'read/write',
        Description   => 'read/write',
        Type          => 'read/write',    #Type is one of Action or Message
        Content       => 'read/write',
        Queue         => 'read/write',
        Creator       => 'read/auto',
        Created       => 'read/auto',
        LastUpdatedBy => 'read/auto',
        LastUpdated   => 'read/auto'
    );
    return $self->SUPER::_Accessible( @_, %Cols );
}

# }}}

# {{{ sub _Set

sub _Set {
    my $self = shift;

    # use super::value or we get acl blocked
    if ( ( defined $self->SUPER::_Value('Queue') )
        && ( $self->SUPER::_Value('Queue') == 0 ) )
    {
        unless ( $self->CurrentUser->HasSystemRight('ModifyTemplate') ) {
            return ( 0, $self->loc('Permission Denied') );
        }
    }
    else {

        unless ( $self->CurrentUserHasQueueRight('ModifyTemplate') ) {
            return ( 0, $self->loc('Permission Denied') );
        }
    }
    return ( $self->SUPER::_Set(@_) );

}

# }}}

# {{{ sub _Value 

=head2 _Value

Takes the name of a table column.
Returns its value as a string, if the user passes an ACL check

=cut

sub _Value {

    my $self  = shift;
    my $field = shift;

    #If the current user doesn't have ACLs, don't let em at it.  
    #use super::value or we get acl blocked
    if ( ( !defined $self->__Value('Queue') )
        || ( $self->__Value('Queue') == 0 ) )
    {
        unless ( $self->CurrentUser->HasSystemRight('ShowTemplate') ) {
            return (undef);
        }
    }
    else {
        unless ( $self->CurrentUserHasQueueRight('ShowTemplate') ) {
            return (undef);
        }
    }
    return ( $self->__Value($field) );

}

# }}}

# {{{ sub Load

=head2 Load <identifer>

Load a template, either by number or by name

=cut

sub Load {
    my $self       = shift;
    my $identifier = shift;

    if ( !$identifier ) {
        return (undef);
    }

    if ( $identifier !~ /\D/ ) {
        $self->SUPER::LoadById($identifier);
    }
    else {
        $self->LoadByCol( 'Name', $identifier );

    }
}

# }}}

# {{{ sub LoadGlobalTemplate

=head2 LoadGlobalTemplate NAME

Load the global tempalte with the name NAME

=cut

sub LoadGlobalTemplate {
    my $self = shift;
    my $id   = shift;

    return ( $self->LoadQueueTemplate( Queue => 0, Name => $id ) );
}

# }}}

# {{{ sub LoadQueueTemplate

=head2  LoadQueueTemplate (Queue => QUEUEID, Name => NAME)

Loads the Queue template named NAME for Queue QUEUE.

=cut

sub LoadQueueTemplate {
    my $self = shift;
    my %args = (
        Queue => undef,
        Name  => undef
    );

    return ( $self->LoadByCols( Name => $args{'Name'}, Queue => {'Queue'} ) );

}

# }}}

# {{{ sub Create

=head2 Create

Takes a paramhash of Content, Queue, Name and Description.
Name should be a unique string identifying this Template.
Description and Content should be the template's title and content.
Queue should be 0 for a global template and the queue # for a queue-specific 
template.

Returns the Template's id # if the create was successful. Returns undef for
unknown database failure.


=cut

sub Create {
    my $self = shift;
    my %args = (
        Content     => undef,
        Queue       => 0,
        Description => '[no description]',
        Type => 'Action',    #By default, template are 'Action' templates
        Name => undef,
        @_
    );

    if ( $args{'Queue'} == 0 ) {
        unless ( $self->CurrentUser->HasSystemRight('ModifyTemplate') ) {
            return (undef);
        }
    }
    else {
        my $QueueObj = new RT::Queue( $self->CurrentUser );
        $QueueObj->Load( $args{'Queue'} ) || return ( 0, 'Invalid queue' );

        unless ( $QueueObj->CurrentUserHasRight('ModifyTemplate') ) {
            return (undef);
        }
    }

    my $result = $self->SUPER::Create(
        Content => $args{'Content'},
        Queue   => $args{'Queue'},
        ,
        Description => $args{'Description'},
        Name        => $args{'Name'}
    );

    return ($result);

}

# }}}

# {{{ sub Delete

=head2 Delete

Delete this template.

=cut

sub Delete {
    my $self = shift;

    unless ( $self->CurrentUserHasRight('ModifyTemplate') ) {
        return ( 0, 'Permission Denied' );
    }

    return ( $self->SUPER::Delete(@_) );
}

# }}}

# {{{ sub MIMEObj
sub MIMEObj {
    my $self = shift;
    return ( $self->{'MIMEObj'} );
}

# }}}

# {{{ sub Parse 

=item Parse

 This routine performs Text::Template parsing on thte template and then imports the 
 results into a MIME::Entity so we can really use it
 It returns a tuple of (val, message)
 If val is 0, the message contains an error message

=cut

sub Parse {
    my $self = shift;

    #We're passing in whatever we were passed. it's destined for _ParseContent
    my $content = $self->_ParseContent(@_);

    #Lets build our mime Entity

    my $parser = MIME::Parser->new();

    ### Should we forgive normally-fatal errors?
    $parser->ignore_errors(1);
    $self->{'MIMEObj'} = eval { $parser->parse_data($content) };
    $error = ( $@ || $parser->last_error );

    if ($error) {
        $RT::Logger->error("$error");
        return ( 0, $error );
    }

    # Unfold all headers
    $self->{'MIMEObj'}->head->unfold();

    return ( 1, "Template parsed" );
   

}

# }}}

# {{{ sub _ParseContent

# Perform Template substitutions on the template

sub _ParseContent {
    my $self = shift;
    my %args = (
        Argument       => undef,
        TicketObj      => undef,
        TransactionObj => undef,
        @_
    );

    # Might be subject to change
    use Text::Template;

    $T::Ticket      = $args{'TicketObj'};
    $T::Transaction = $args{'TransactionObj'};
    $T::Argument    = $args{'Argument'};
    $T::rtname      = $RT::rtname;

    # We need to untaint the content of the template, since we'll be working
    # with it
    my $content = $self->Content();
    $content =~ s/^(.*)$/$1/;
    $template = Text::Template->new(
        TYPE   => STRING,
        SOURCE => $content
    );

    my $retval = $template->fill_in( PACKAGE => T );
    return ($retval);
}

# }}}

# {{{ sub QueueObj

=head2 QueueObj

Takes nothing. returns this ticket's queue object

=cut

sub QueueObj {
    my $self = shift;
    if ( !defined $self->{'queue'} ) {
        require RT::Queue;
        $self->{'queue'} = RT::Queue->new( $self->CurrentUser );

        unless ( $self->{'queue'} ) {
            $RT::Logger->crit(
                "RT::Queue->new(" . $self->CurrentUser . ") returned false" );
            return (undef);
        }
        my ($result) = $self->{'queue'}->Load( $self->__Value('Queue') );

    }
    return ( $self->{'queue'} );
}

# }}}

# {{{ sub CurrentUserHasQueueRight

=head2 CurrentUserHasQueueRight

Helper function to call the template's queue's CurrentUserHasQueueRight with the passed in args.

=cut

sub CurrentUserHasQueueRight {
    my $self = shift;
    return ( $self->QueueObj->CurrentUserHasRight(@_) );
}

# }}}
1;
