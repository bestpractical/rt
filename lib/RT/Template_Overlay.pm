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
# Portions Copyright 2000 Tobias Brox <tobix@cpan.org> 

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


package RT::Template;

use strict;
no warnings qw(redefine);

use Text::Template;
use MIME::Entity;
use MIME::Parser;
use File::Temp qw /tempdir/;


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
    
    unless ( $self->CurrentUserHasQueueRight('ModifyTemplate') ) {
        return ( 0, $self->loc('Permission Denied') );
    }
    return $self->SUPER::_Set( @_ );
}

# }}}

# {{{ sub _Value 

=head2 _Value

Takes the name of a table column.
Returns its value as a string, if the user passes an ACL check


=begin testing

my $t = RT::Template->new($RT::SystemUser);
$t->Create(Name => "Foo", Queue => 1);
my $t2 = RT::Template->new($RT::Nobody);
$t2->Load($t->Id);
ok($t2->QueueObj->id, "Got the template's queue objet");

=end testing



=cut

sub _Value {
    my $self  = shift;

    unless ( $self->CurrentUserHasQueueRight('ShowTemplate') ) {
        return undef;
    }
    return $self->__Value( @_ );

}

# }}}

# {{{ sub Load

=head2 Load <identifer>

Load a template, either by number or by name

=cut

sub Load {
    my $self       = shift;
    my $identifier = shift;
    return undef unless $identifier;

    if ( $identifier =~ /\D/ ) {
        return $self->LoadByCol( 'Name', $identifier );
    }
    return $self->LoadById( $identifier );
}

# }}}

# {{{ sub LoadGlobalTemplate

=head2 LoadGlobalTemplate NAME

Load the global template with the name NAME

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
        Name  => undef,
        @_
    );

    return ( $self->LoadByCols( Name => $args{'Name'}, Queue => $args{'Queue'} ) );

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
        Type        => 'Action', #By default, template are 'Action' templates
        Name        => undef,
        @_
    );

    unless ( $args{'Queue'} ) {
        unless ( $self->CurrentUser->HasRight(Right =>'ModifyTemplate', Object => $RT::System) ) {
            return ( undef, $self->loc('Permission denied') );
        }
        $args{'Queue'} = 0;
    }
    else {
        my $QueueObj = new RT::Queue( $self->CurrentUser );
        $QueueObj->Load( $args{'Queue'} ) || return ( undef, $self->loc('Invalid queue') );
    
        unless ( $QueueObj->CurrentUserHasRight('ModifyTemplate') ) {
            return ( undef, $self->loc('Permission denied') );
        }
        $args{'Queue'} = $QueueObj->Id;
    }

    my $result = $self->SUPER::Create(
        Content     => $args{'Content'},
        Queue       => $args{'Queue'},
        Description => $args{'Description'},
        Name        => $args{'Name'},
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

    unless ( $self->CurrentUserHasQueueRight('ModifyTemplate') ) {
        return ( 0, $self->loc('Permission Denied') );
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

=head2 Parse

 This routine performs Text::Template parsing on the template and then
 imports the results into a MIME::Entity so we can really use it

 Takes a hash containing Argument, TicketObj, and TransactionObj. TicketObj
 and TransactionObj are not mandatory, but highly recommended.

 It returns a tuple of (val, message)
 If val is 0, the message contains an error message

=cut

sub Parse {
    my $self = shift;

    #We're passing in whatever we were passed. it's destined for _ParseContent
    my ($content, $msg) = $self->_ParseContent(@_);
    return ( 0, $msg ) unless defined $content;

    #Lets build our mime Entity

    my $parser = MIME::Parser->new();

    # On some situations TMPDIR is non-writable. sad but true.
    $parser->output_to_core(1);
    $parser->tmp_to_core(1);

    #If someone includes a message, don't extract it
    $parser->extract_nested_messages(1);

    # Set up the prefix for files with auto-generated names:
    $parser->output_prefix("part");

    # If content length is <= 50000 bytes, store each msg as in-core scalar;
    # Else, write to a disk file (the default action):
    $parser->output_to_core(50000);

    ### Should we forgive normally-fatal errors?
    $parser->ignore_errors(1);
    $self->{'MIMEObj'} = eval { $parser->parse_data($content) };
    if ( my $error = $@ || $parser->last_error ) {
        $RT::Logger->error( "$error" );
        return ( 0, $error );
    }

    # Unfold all headers
    $self->{'MIMEObj'}->head->unfold;

    return ( 1, $self->loc("Template parsed") );

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

    no warnings 'redefine';
    local $T::Ticket      = $args{'TicketObj'};
    local $T::Transaction = $args{'TransactionObj'};
    local $T::Argument    = $args{'Argument'};
    local $T::Requestor   = eval { $T::Ticket->Requestors->UserMembersObj->First->Name } if $T::Ticket;
    local $T::rtname      = $RT::rtname;

    local *T::loc         = sub {
        $T::Ticket ? $T::Ticket->loc(@_)
                   : $self->CurrentUser->loc(@_)
    };

    my $content = $self->Content;
    unless ( defined $content ) {
        return ( undef, $self->loc("Permissions denied") );
    }

    # We need to untaint the content of the template, since we'll be working
    # with it
    $content =~ s/^(.*)$/$1/;
    my $template = Text::Template->new(
        TYPE   => 'STRING',
        SOURCE => $content
    );

    my $is_broken = 0;
    my $retval = $template->fill_in( PACKAGE => 'T', BROKEN => sub {
        my (%args) = @_;
        $RT::Logger->error("Template parsing error: $args{error}")
            unless $args{error} =~ /^Died at /; # ignore intentional die()
        $is_broken++;
        return undef;
    } );
    return ( undef, $self->loc('Template parsing error') ) if $is_broken;

    # MIME::Parser has problems dealing with high-bit utf8 data.
    Encode::_utf8_off($retval);
    return ($retval);
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
