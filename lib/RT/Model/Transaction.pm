use strict;
use warnings;

=head1 NAME

RT::Model::Transaction


=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 METHODS

=cut

package RT::Model::Transaction;
use RT::Record; 


use base qw/RT::Record/;

use Jifty::DBI::Schema;
use Jifty::DBI::Record schema {

    column ObjectType => max_length is 64, type is 'varchar(64)', default is '';
    column ObjectId   => max_length is 11, type is 'int(11)',     default is '0';
    column TimeTaken  => max_length is 11, type is 'int(11)',     default is '0';
    column Type       => max_length is 20, type is 'varchar(20)', default is '';
    column Field     => max_length is 40, type is 'varchar(40)', default is '';
    column OldValue => max_length is 255, type is 'varchar(255)', default is '';
    column NewValue => max_length is 255, type is 'varchar(255)', default is '';
    column ReferenceType => max_length is 255, type is 'varchar(255)', default is '';
    column OldReference => max_length is 11, type is 'int(11)', default is '';
    column NewReference => max_length is 11, type is 'int(11)', default is '';
    column Data    => max_length is 255, type is 'varchar(255)', default is '';
    column Creator => max_length is 11,  type is 'int(11)',      default is '0';
    column Created =>  type is 'datetime',     default is '';

};





=head2 ObjectType

Returns the current value of ObjectType. 
(In the database, ObjectType is stored as varchar(64).)



=head2 SetObjectType value


Set ObjectType to value. 
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, ObjectType will be stored as a varchar(64).)


=cut


=head2 ObjectId

Returns the current value of ObjectId. 
(In the database, ObjectId is stored as int(11).)



=head2 SetObjectId value


Set ObjectId to value. 
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, ObjectId will be stored as a int(11).)


=cut


=head2 TimeTaken

Returns the current value of TimeTaken. 
(In the database, TimeTaken is stored as int(11).)



=head2 SetTimeTaken value


Set TimeTaken to value. 
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, TimeTaken will be stored as a int(11).)


=cut


=head2 Type

Returns the current value of Type. 
(In the database, Type is stored as varchar(20).)



=head2 SetType value


Set Type to value. 
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, Type will be stored as a varchar(20).)


=cut


=head2 Field

Returns the current value of Field. 
(In the database, Field is stored as varchar(40).)



=head2 SetField value


Set Field to value. 
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, Field will be stored as a varchar(40).)


=cut


=head2 OldValue

Returns the current value of OldValue. 
(In the database, OldValue is stored as varchar(255).)



=head2 SetOldValue value


Set OldValue to value. 
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, OldValue will be stored as a varchar(255).)


=cut


=head2 NewValue

Returns the current value of NewValue. 
(In the database, NewValue is stored as varchar(255).)



=head2 SetNewValue value


Set NewValue to value. 
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, NewValue will be stored as a varchar(255).)


=cut


=head2 ReferenceType

Returns the current value of ReferenceType. 
(In the database, ReferenceType is stored as varchar(255).)



=head2 SetReferenceType value


Set ReferenceType to value. 
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, ReferenceType will be stored as a varchar(255).)


=cut


=head2 OldReference

Returns the current value of OldReference. 
(In the database, OldReference is stored as int(11).)



=head2 SetOldReference value


Set OldReference to value. 
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, OldReference will be stored as a int(11).)


=cut


=head2 NewReference

Returns the current value of NewReference. 
(In the database, NewReference is stored as int(11).)



=head2 SetNewReference value


Set NewReference to value. 
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, NewReference will be stored as a int(11).)


=cut


=head2 Data

Returns the current value of Data. 
(In the database, Data is stored as varchar(255).)



=head2 SetData value


Set Data to value. 
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, Data will be stored as a varchar(255).)


=cut


=head2 Creator

Returns the current value of Creator. 
(In the database, Creator is stored as int(11).)


=cut


=head2 Created

Returns the current value of Created. 
(In the database, Created is stored as datetime.)


=cut



     

sub table {'Transactions'}


use vars qw( %_BriefDescriptions );

use RT::Model::Attachments;
use RT::Model::Scrips;

use HTML::FormatText;
use HTML::TreeBuilder;


# {{{ sub create 

=head2 Create

Create a new transaction.

This routine should _never_ be called by anything other than RT::Model::Ticket. 
It should not be called 
from client code. Ever. Not ever.  If you do this, we will hunt you down and break your kneecaps.
Then the unpleasant stuff will start.

TODO: Document what gets passed to this

=cut

sub create {
    my $self = shift;
    my %args = (
        id             => undef,
        TimeTaken      => 0,
        Type           => 'undefined',
        Data           => '',
        Field          => undef,
        OldValue       => undef,
        NewValue       => undef,
        MIMEObj        => undef,
        ActivateScrips => 1,
        CommitScrips => 1,
	ObjectType => 'RT::Model::Ticket',
	ObjectId => 0,
	ReferenceType => undef,
        OldReference       => undef,
        NewReference       => undef,
        @_
    );


    $args{ObjectId} ||= $args{Ticket};

    #if we didn't specify a ticket, we need to bail
    unless ( $args{'ObjectId'} && $args{'ObjectType'}) {
        return ( 0, $self->loc( "Transaction->create couldn't, as you didn't specify an object type and id"));
    }



    #lets create our transaction
    my %params = (
        Type      => $args{'Type'},
        Data      => $args{'Data'},
        Field     => $args{'Field'},
        OldValue  => $args{'OldValue'},
        NewValue  => $args{'NewValue'},
        Created   => $args{'Created'},
	ObjectType => $args{'ObjectType'},
	ObjectId => $args{'ObjectId'},
	ReferenceType => $args{'ReferenceType'},
	OldReference => $args{'OldReference'},
	NewReference => $args{'NewReference'},
    );

    # Parameters passed in during an import that we probably don't want to touch, otherwise
    foreach my $attr qw(id Creator Created LastUpdated TimeTaken LastUpdatedBy) {
        $params{$attr} = $args{$attr} if ($args{$attr});
    }
 
    my $id = $self->SUPER::create(%params);
    $self->load($id);
    if ( defined $args{'MIMEObj'} ) {
        my ($id, $msg) = $self->_Attach( $args{'MIMEObj'} );
        unless ( $id ) {
            $RT::Logger->error("Couldn't add attachment: $msg");
            return ( 0, $self->loc("Couldn't add attachment") );
        }
    }


    #Provide a way to turn off scrips if we need to
        $RT::Logger->debug('About to think about scrips for transaction #' .$self->id);
    if ( $args{'ActivateScrips'} and $args{'ObjectType'} eq 'RT::Model::Ticket' ) {
       $self->{'scrips'} = RT::Model::Scrips->new($RT::SystemUser);

        $RT::Logger->debug('About to prepare scrips for transaction #' .$self->id); 
        $self->{'scrips'}->prepare(
            Stage       => 'TransactionCreate',
            Type        => $args{'Type'},
            Ticket      => $args{'ObjectId'},
            Transaction => $self->id,
        );
        if ($args{'CommitScrips'} ) {
            $RT::Logger->debug('About to commit scrips for transaction #' .$self->id);
            $self->{'scrips'}->commit();
        }
    }

    return ( $id, $self->loc("Transaction Created") );
}

# }}}

=head2 Scrips

Returns the Scrips object for this transaction.
This routine is only useful on a freshly Created transaction object.
Scrips do not get persisted to the database with transactions.


=cut


sub Scrips {
    my $self = shift;
    return($self->{'scrips'});
}


# {{{ sub delete

=head2 Delete

Delete this transaction. Currently DOES NOT CHECK ACLS

=cut

sub delete {
    my $self = shift;


    $RT::Handle->begin_transaction();

    my $attachments = $self->Attachments;

    while (my $attachment = $attachments->next) {
        my ($id, $msg) = $attachment->delete();
        unless ($id) {
            $RT::Handle->rollback();
            return($id, $self->loc("System Error: [_1]", $msg));
        }
    }
    my ($id,$msg) = $self->SUPER::delete();
        unless ($id) {
            $RT::Handle->rollback();
            return($id, $self->loc("System Error: [_1]", $msg));
        }
    $RT::Handle->commit();
    return ($id,$msg);
}

# }}}

# {{{ Routines dealing with Attachments

# {{{ sub Message 

=head2 Message

Returns the L<RT::Model::Attachments> Object which contains the "top-level" object
attachment for this transaction.

=cut

sub Message {
    my $self = shift;

    # XXX: Where is ACL check?
    
    if ( !defined( $self->{'message'} ) ) {

        $self->{'message'} = new RT::Model::Attachments( $self->CurrentUser );
        $self->{'message'}->limit(
            column => 'TransactionId',
            value => $self->id
        );

        $self->{'message'}->ChildrenOf(0);
    }
    return ( $self->{'message'} );
}

# }}}

# {{{ sub Content

=head2 Content PARAMHASH

If this transaction has attached mime objects, returns the first text/plain part.
Otherwise, returns undef.

Takes a paramhash.  If the $args{'Quote'} parameter is set, wraps this message 
at $args{'Wrap'}.  $args{'Wrap'} defaults to 70.


=cut

sub Content {
    my $self = shift;
    my %args = (
        Quote => 0,
        Wrap  => 70,
        @_
    );

    my $content;
    if ( my $content_obj = $self->ContentObj ) {
        $content = $content_obj->Content ||'';

        if ( lc $content_obj->ContentType eq 'text/html' ) {
            $content = HTML::FormatText->new(
                leftmargin  => 0,
                rightmargin => 78,
            )->format( HTML::TreeBuilder->new_from_content( $content ) );
        }
    }

    # If all else fails, return a message that we couldn't find any content
    else {
        $content = $self->loc('This transaction appears to have no content');
    }

    if ( $args{'Quote'} ) {

        # Remove quoted signature.
        $content =~ s/\n-- \n(.*?)$//s;

        # What's the longest line like?
        my $max = 0;
        foreach ( split ( /\n/, $content ) ) {
            $max = length if length > $max;
        }

        if ( $max > 76 ) {
            require Text::Wrapper;
            my $wrapper = new Text::Wrapper(
                columns    => $args{'Wrap'},
                body_start => ( $max > 70 * 3 ? '   ' : '' ),
                par_start  => ''
            );
            $content = $wrapper->wrap($content);
        }

        $content =~ s/^/> /gm;
        $content = $self->loc("On [_1], [_2] wrote:", $self->CreatedAsString, $self->CreatorObj->Name)
          . "\n$content\n\n";
    }

    return ($content);
}

# }}}


=head2 Addresses

Returns a hashref of addresses related to this transaction. See L<RT::Model::Attachment/Addresses> for details.

=cut

sub Addresses {
	my $self = shift;

	if (my $attach = $self->Attachments->first) {	
		return $attach->Addresses;
	}
	else {
		return {};
	}

}


# {{{ ContentObj

=head2 ContentObj 

Returns the RT::Model::Attachment object which contains the content for this Transaction

=cut


sub ContentObj {
    my $self = shift;

    # If we don't have any content, return undef now.
    # Get the set of toplevel attachments to this transaction.
    return undef unless my $Attachment = $self->Attachments->first;

    # If it's a message or a plain part, just return the
    # body.
    if ( $Attachment->ContentType =~ '^(?:text/plain$|text/html|message/)' ) {
        return ($Attachment);
    }

    # If it's a multipart object, first try returning the first
    # text/plain part.

    elsif ( $Attachment->ContentType =~ '^multipart/' ) {
        my $plain_parts = $Attachment->Children;
        $plain_parts->ContentType( value => 'text/plain' );
        $plain_parts->LimitNotEmpty;

        # If we actully found a part, return its content
        if ( my $first = $plain_parts->first ) {
            return $first;
        }

        # If that fails, return the first text/plain or message/... part
        # which has some content.
        my $all_parts = $self->Attachments;
        while ( my $part = $all_parts->next ) {
            next unless $part->ContentType =~ '^(text/plain$|message/)'
                        && $part->Content;
            return $part;
        }
    }

    # We found no content. suck
    return (undef);
}

# }}}

# {{{ sub Subject

=head2 Subject

If this transaction has attached mime objects, returns the first one's subject
Otherwise, returns null
  
=cut

sub Subject {
    my $self = shift;
    return undef unless my $first = $self->Attachments->first;
    return $first->Subject;
}

# }}}

# {{{ sub Attachments 

=head2 Attachments

  Returns all the RT::Model::Attachment objects which are attached
to this transaction. Takes an optional parameter, which is
a ContentType that Attachments should be restricted to.

=cut

sub Attachments {
    my $self = shift;

    if ( $self->{'attachments'} ) {
        $self->{'attachments'}->goto_first_item;
        return $self->{'attachments'};
    }

    $self->{'attachments'} = RT::Model::Attachments->new( $self->CurrentUser );

    unless ( $self->CurrentUserCanSee ) {
        $self->{'attachments'}->limit(column => 'id', value => '0');
        return $self->{'attachments'};
    }

    $self->{'attachments'}->limit( column => 'TransactionId', value => $self->id );

    # Get the self->{'attachments'} in the order they're put into
    # the database.  Arguably, we should be returning a tree
    # of self->{'attachments'}, not a set...but no current app seems to need
    # it.

    $self->{'attachments'}->order_by( column => 'id', order => 'ASC' );

    return $self->{'attachments'};
}

# }}}

# {{{ sub _Attach 

=head2 _Attach

A private method used to attach a mime object to this transaction.

=cut

sub _Attach {
    my $self       = shift;
    my $MIMEObject = shift;

    unless ( defined $MIMEObject ) {
        $RT::Logger->error("We can't attach a mime object if you don't give us one.");
        return ( 0, $self->loc("[_1]: no attachment specified", $self) );
    }

    my $Attachment = RT::Model::Attachment->new( $self->CurrentUser );
    my ($id, $msg) = $Attachment->create(
        TransactionId => $self->id,
        Attachment    => $MIMEObject
    );
    return ( $Attachment, $msg || $self->loc("Attachment Created") );
}

# }}}

# }}}

# {{{ Routines dealing with Transaction Attributes

# {{{ sub Description 

=head2 Description

Returns a text string which describes this transaction

=cut

sub Description {
    my $self = shift;

    unless ( $self->CurrentUserCanSee ) {
        return ( $self->loc("Permission Denied") );
    }

    unless ( defined $self->Type ) {
        return ( $self->loc("No transaction type specified"));
    }

    return $self->loc("[_1] by [_2]", $self->BriefDescription , $self->CreatorObj->Name );
}

# }}}

# {{{ sub BriefDescription 

=head2 BriefDescription

Returns a text string which briefly describes this transaction

=cut

sub BriefDescription {
    my $self = shift;

    unless ( $self->CurrentUserCanSee ) {
        return ( $self->loc("Permission Denied") );
    }

    my $type = $self->Type;    #cache this, rather than calling it 30 times

    unless ( defined $type ) {
        return $self->loc("No transaction type specified");
    }

    my $obj_type = $self->FriendlyObjectType;

    if ( $type eq 'Create' ) {
        return ( $self->loc( "[_1] Created", $obj_type ) );
    }
    elsif ( $type =~ /Status/ ) {
        if ( $self->Field eq 'Status' ) {
            if ( $self->NewValue eq 'deleted' ) {
                return ( $self->loc( "[_1] deleted", $obj_type ) );
            }
            else {
                return (
                    $self->loc(
                        "Status changed from [_1] to [_2]",
                        "'" . $self->loc( $self->OldValue ) . "'",
                        "'" . $self->loc( $self->NewValue ) . "'"
                    )
                );

            }
        }

        # Generic:
        my $no_value = $self->loc("(no value)");
        return (
            $self->loc(
                "[_1] changed from [_2] to [_3]",
                $self->Field,
                ( $self->OldValue ? "'" . $self->OldValue . "'" : $no_value ),
                "'" . $self->NewValue . "'"
            )
        );
    }

    if ( my $code = $_BriefDescriptions{$type} ) {
        return $code->($self);
    }

    return $self->loc(
        "Default: [_1]/[_2] changed from [_3] to [_4]",
        $type,
        $self->Field,
        (
            $self->OldValue
            ? "'" . $self->OldValue . "'"
            : $self->loc("(no value)")
        ),
        "'" . $self->NewValue . "'"
    );
}

%_BriefDescriptions = (
    CommentEmailRecord => sub {
        my $self = shift;
        return $self->loc("Outgoing email about a comment recorded");
    },
    EmailRecord => sub {
        my $self = shift;
        return $self->loc("Outgoing email recorded");
    },
    Correspond => sub {
        my $self = shift;
        return $self->loc("Correspondence added");
    },
    Comment => sub {
        my $self = shift;
        return $self->loc("Comments added");
    },
    CustomField => sub {
        my $self = shift;
        my $field = $self->loc('CustomField');

        if ( $self->Field ) {
            my $cf = RT::Model::CustomField->new( $self->CurrentUser );
            $cf->load( $self->Field );
            $field = $cf->Name();
        }

        if ( ! defined $self->OldValue || $self->OldValue eq '' ) {
            return ( $self->loc("[_1] [_2] added", $field, $self->NewValue) );
        }
        elsif ( $self->NewValue eq '' ) {
            return ( $self->loc("[_1] [_2] deleted", $field, $self->OldValue) );

        }
        else {
            return $self->loc("[_1] [_2] changed to [_3]", $field, $self->OldValue, $self->NewValue );
        }
    },
    Untake => sub {
        my $self = shift;
        return $self->loc("Untaken");
    },
    Take => sub {
        my $self = shift;
        return $self->loc("Taken");
    },
    Force => sub {
        my $self = shift;
        my $Old = RT::Model::User->new( $self->CurrentUser );
        $Old->load( $self->OldValue );
        my $New = RT::Model::User->new( $self->CurrentUser );
        $New->load( $self->NewValue );

        return $self->loc("Owner forcibly changed from [_1] to [_2]" , $Old->Name , $New->Name);
    },
    Steal => sub {
        my $self = shift;
        my $Old = RT::Model::User->new( $self->CurrentUser );
        $Old->load( $self->OldValue );
        return $self->loc("Stolen from [_1]",  $Old->Name);
    },
    Give => sub {
        my $self = shift;
        my $New = RT::Model::User->new( $self->CurrentUser );
        $New->load( $self->NewValue );
        return $self->loc( "Given to [_1]",  $New->Name );
    },
    AddWatcher => sub {
        my $self = shift;
        my $principal = RT::Model::Principal->new($self->CurrentUser);
        $principal->load($self->NewValue);
        return $self->loc( "[_1] [_2] added", $self->Field, $principal->Object->Name);
    },
    DelWatcher => sub {
        my $self = shift;
        my $principal = RT::Model::Principal->new($self->CurrentUser);
        $principal->load($self->OldValue);
        return $self->loc( "[_1] [_2] deleted", $self->Field, $principal->Object->Name);
    },
    Subject => sub {
        my $self = shift;
        return $self->loc( "Subject changed to [_1]", $self->Data );
    },
    AddLink => sub {
        my $self = shift;
        my $value;
        if ( $self->NewValue ) {
            my $URI = RT::URI->new( $self->CurrentUser );
            $URI->FromURI( $self->NewValue );
            if ( $URI->Resolver ) {
                $value = $URI->Resolver->AsString;
            }
            else {
                $value = $self->NewValue;
            }
            if ( $self->Field eq 'DependsOn' ) {
                return $self->loc( "Dependency on [_1] added", $value );
            }
            elsif ( $self->Field eq 'DependedOnBy' ) {
                return $self->loc( "Dependency by [_1] added", $value );

            }
            elsif ( $self->Field eq 'RefersTo' ) {
                return $self->loc( "Reference to [_1] added", $value );
            }
            elsif ( $self->Field eq 'ReferredToBy' ) {
                return $self->loc( "Reference by [_1] added", $value );
            }
            elsif ( $self->Field eq 'MemberOf' ) {
                return $self->loc( "Membership in [_1] added", $value );
            }
            elsif ( $self->Field eq 'has_member' ) {
                return $self->loc( "Member [_1] added", $value );
            }
            elsif ( $self->Field eq 'MergedInto' ) {
                return $self->loc( "Merged into [_1]", $value );
            }
        }
        else {
            return ( $self->Data );
        }
    },
    delete_link => sub {
        my $self = shift;
        my $value;
        if ( $self->OldValue ) {
            my $URI = RT::URI->new( $self->CurrentUser );
            $URI->FromURI( $self->OldValue );
            if ( $URI->Resolver ) {
                $value = $URI->Resolver->AsString;
            }
            else {
                $value = $self->OldValue;
            }

            if ( $self->Field eq 'DependsOn' ) {
                return $self->loc( "Dependency on [_1] deleted", $value );
            }
            elsif ( $self->Field eq 'DependedOnBy' ) {
                return $self->loc( "Dependency by [_1] deleted", $value );

            }
            elsif ( $self->Field eq 'RefersTo' ) {
                return $self->loc( "Reference to [_1] deleted", $value );
            }
            elsif ( $self->Field eq 'ReferredToBy' ) {
                return $self->loc( "Reference by [_1] deleted", $value );
            }
            elsif ( $self->Field eq 'MemberOf' ) {
                return $self->loc( "Membership in [_1] deleted", $value );
            }
            elsif ( $self->Field eq 'has_member' ) {
                return $self->loc( "Member [_1] deleted", $value );
            }
        }
        else {
            return ( $self->Data );
        }
    },
    Set => sub {
        my $self = shift;
        if ( $self->Field eq 'Password' ) {
            return $self->loc('Password changed');
        }
        elsif ( $self->Field eq 'Queue' ) {
            my $q1 = new RT::Model::Queue( $self->CurrentUser );
            $q1->load( $self->OldValue );
            my $q2 = new RT::Model::Queue( $self->CurrentUser );
            $q2->load( $self->NewValue );
            return $self->loc("[_1] changed from [_2] to [_3]", $self->Field , $q1->Name , $q2->Name);
        }

        # Write the date/time change at local time:
        elsif ($self->Field =~  /Due|Starts|Started|Told/) {
            my $t1 = new RT::Date($self->CurrentUser);
            $t1->set(Format => 'ISO', value => $self->NewValue);
            my $t2 = new RT::Date($self->CurrentUser);
            $t2->set(Format => 'ISO', value => $self->OldValue);
            return $self->loc( "[_1] changed from [_2] to [_3]", $self->Field, $t2->AsString, $t1->AsString );
        }
        else {
            return $self->loc( "[_1] changed from [_2] to [_3]", $self->Field, ($self->OldValue? "'".$self->OldValue ."'" : $self->loc("(no value)")) , "'". $self->NewValue."'" );
        }
    },
    PurgeTransaction => sub {
        my $self = shift;
        return $self->loc("Transaction [_1] purged", $self->Data);
    },
    AddReminder => sub {
        my $self = shift;
        my $ticket = RT::Model::Ticket->new($self->CurrentUser);
        $ticket->load($self->NewValue);
        return $self->loc("Reminder '[_1]' added", $ticket->Subject);
    },
    OpenReminder => sub {
        my $self = shift;
        my $ticket = RT::Model::Ticket->new($self->CurrentUser);
        $ticket->load($self->NewValue);
        return $self->loc("Reminder '[_1]' reopened", $ticket->Subject);
    
    },
    ResolveReminder => sub {
        my $self = shift;
        my $ticket = RT::Model::Ticket->new($self->CurrentUser);
        $ticket->load($self->NewValue);
        return $self->loc("Reminder '[_1]' completed", $ticket->Subject);
    
    
    }
);

# }}}

# {{{ Utility methods

# {{{ sub IsInbound

=head2 IsInbound

Returns true if the creator of the transaction is a requestor of the ticket.
Returns false otherwise

=cut

sub IsInbound {
    my $self = shift;
    $self->ObjectType eq 'RT::Model::Ticket' or return undef;
    return ( $self->TicketObj->IsRequestor( $self->CreatorObj->PrincipalId ) );
}

# }}}

# }}}

sub _OverlayAccessible {
    {

          ObjectType => { public => 1},
          ObjectId => { public => 1},

    }
};

# }}}

# }}}

# {{{ sub _set

sub _set {
    my $self = shift;
    return ( 0, $self->loc('Transactions are immutable') );
}

# }}}

# {{{ sub _value 

=head2 _value

Takes the name of a table column.
Returns its value as a string, if the user passes an ACL check

=cut

sub _value {
    my $self  = shift;
    my $field = shift;

    #if the field is public, return it.
    if ( 0) {# $self->_Accessible( $field, 'public' ) ) {
        return $self->SUPER::_value( $field );
    }

    unless ( $self->CurrentUserCanSee ) {
        return undef;
    }

    return $self->SUPER::_value( $field );
}

# }}}

# {{{ sub current_user_has_right

=head2 current_user_has_right RIGHT

Calls $self->CurrentUser->HasQueueRight for the right passed in here.
passed in here.

=cut

sub current_user_has_right {
    my $self  = shift;
    my $right = shift;
    return $self->CurrentUser->has_right(
        Right  => $right,
        Object => $self->Object
    );
}

=head2 CurrentUserCanSee

Returns true if current user has rights to see this particular transaction.

This fact depends on type of the transaction, type of an object the transaction
is attached to and may be other conditions, so this method is prefered over
custom implementations.

=cut

sub CurrentUserCanSee {
    my $self = shift;

    # If it's a comment, we need to be extra special careful
    my $type = $self->__value('Type');
    if ( $type eq 'Comment' ) {
        unless ( $self->current_user_has_right('ShowTicketComments') ) {
            return 0;
        }
    }
    elsif ( $type eq 'CommentEmailRecord' ) {
        unless ( $self->current_user_has_right('ShowTicketComments')
            && $self->current_user_has_right('ShowOutgoingEmail') ) {
            return 0;
        }
    }
    elsif ( $type eq 'EmailRecord' ) {
        unless ( $self->current_user_has_right('ShowOutgoingEmail') ) {
            return 0;
        }
    }
    # Make sure the user can see the custom field before showing that it changed
    elsif ( $type eq 'CustomField' and my $cf_id = $self->__value('Field') ) {
        my $cf = RT::Model::CustomField->new( $self->CurrentUser );
        $cf->load( $cf_id );
        return 0 unless $cf->current_user_has_right('SeeCustomField');
    }
    #if they ain't got rights to see, don't let em
    elsif ( $self->__value('ObjectType') eq "RT::Model::Ticket" ) {
        unless ( $self->current_user_has_right('ShowTicket') ) {
            return 0;
        }
    }

    return 1;
}

# }}}

sub Ticket {
    my $self = shift;
    return $self->ObjectId;
}

sub TicketObj {
    my $self = shift;
    return $self->Object;
}

sub OldValue {
    my $self = shift;
    if ( my $type = $self->__value('ReferenceType')
         and my $id = $self->__value('OldReference') )
    {
        my $Object = $type->new($self->CurrentUser);
        $Object->load( $id );
        return $Object->Content;
    }
    else {
        return $self->__value('OldValue');
    }
}

sub NewValue {
    my $self = shift;
    if ( my $type = $self->__value('ReferenceType')
         and my $id = $self->__value('NewReference') )
    {
        my $Object = $type->new($self->CurrentUser);
        $Object->load( $id );
        return $Object->Content;
    }
    else {
        return $self->__value('NewValue');
    }
}

sub Object {
    my $self  = shift;
    my $Object = $self->__value('ObjectType')->new($self->CurrentUser);
    $Object->load($self->__value('ObjectId'));
    return $Object;
}

sub FriendlyObjectType {
    my $self = shift;
    my $type = $self->ObjectType or return undef;
    $type =~ s/^RT:://;
    return $self->loc($type);
}

=head2 UpdateCustomFields
    
    Takes a hash of 

    CustomField-<<Id>> => Value
        or 

    Object-RT::Model::Transaction-CustomField-<<Id>> => Value parameters to update
    this transaction's custom fields

=cut

sub UpdateCustomFields {
    my $self = shift;
    my %args = (@_);

    # This method used to have an API that took a hash of a single
    # value "ARGSRef", which was a reference to a hash of arguments.
    # This was insane. The next few lines of code preserve that API
    # while giving us something saner.

    # TODO: 3.6: DEPRECATE OLD API

    my $args; 

    if ($args{'ARGSRef'}) { 
        $args = $args{ARGSRef};
    } else {
        $args = \%args;
    }

    foreach my $arg ( keys %$args ) {
        next
          unless ( $arg =~
            /^(?:Object-RT::Model::Transaction--)?CustomField-(\d+)/ );
	next if $arg =~ /-Magic$/;
        my $cfid   = $1;
        my $values = $args->{$arg};
        foreach
          my $value ( UNIVERSAL::isa( $values, 'ARRAY' ) ? @$values : $values )
        {
            next unless length($value);
            $self->_AddCustomFieldValue(
                Field             => $cfid,
                Value             => $value,
                RecordTransaction => 0,
            );
        }
    }
}



=head2 CustomFieldValues

 Do name => id mapping (if needed) before falling back to RT::Record's CustomFieldValues

 See L<RT::Record>

=cut

sub CustomFieldValues {
    my $self  = shift;
    my $field = shift;

    if ( UNIVERSAL::can( $self->Object, 'QueueObj' ) ) {

        # XXX: $field could be undef when we want fetch values for all CFs
        #      do we want to cover this situation somehow here?
        unless ( defined $field && $field =~ /^\d+$/o ) {
            my $CFs = RT::Model::CustomFields->new( $self->CurrentUser );
            $CFs->limit( column => 'Name', value => $field );
            $CFs->LimitToLookupType($self->CustomFieldLookupType);
            $CFs->LimitToGlobalOrObjectId($self->Object->QueueObj->id);
            $field = $CFs->first->id if $CFs->first;
        }
    }
    return $self->SUPER::CustomFieldValues($field);
}

# }}}

# {{{ sub CustomFieldLookupType

=head2 CustomFieldLookupType

Returns the RT::Model::Transaction lookup type, which can 
be passed to RT::Model::CustomField->create() via the 'LookupType' hash key.

=cut

# }}}

sub CustomFieldLookupType {
    "RT::Model::Queue-RT::Model::Ticket-RT::Model::Transaction";
}

# Transactions don't change. by adding this cache congif directiove, we don't lose pathalogically on long tickets.
sub _CacheConfig {
  {
     'cache_p'        => 1,
     'fast_update_p'  => 1,
     'cache_for_sec'  => 6000,
  }
}
1;
