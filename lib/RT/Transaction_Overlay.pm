# BEGIN LICENSE BLOCK
# 
# Copyright (c) 1996-2003 Jesse Vincent <jesse@bestpractical.com>
# 
# (Except where explictly superceded by other copyright notices)
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
# Unless otherwise specified, all modifications, corrections or
# extensions to this work which alter its source code become the
# property of Best Practical Solutions, LLC when submitted for
# inclusion in the work.
# 
# 
# END LICENSE BLOCK
=head1 NAME

  RT::Transaction - RT\'s transaction object

=head1 SYNOPSIS

  use RT::Transaction;


=head1 DESCRIPTION


Each RT::Transaction describes an atomic change to a ticket object 
or an update to an RT::Ticket object.
It can have arbitrary MIME attachments.


=head1 METHODS

=begin testing

ok(require RT::Transaction);

=end testing

=cut

use strict;
no warnings qw(redefine);

use RT::Attachments;

# {{{ sub Create 

=head2 Create

Create a new transaction.

This routine should _never_ be called anything other Than RT::Ticket. It should not be called 
from client code. Ever. Not ever.  If you do this, we will hunt you down. and break your kneecaps.
Then the unpleasant stuff will start.

TODO: Document what gets passed to this

=cut

sub Create {
    my $self = shift;
    my %args = (
        id             => undef,
        TimeTaken      => 0,
        Ticket         => 0,
        Type           => 'undefined',
        Data           => '',
        Field          => undef,
        OldValue       => undef,
        NewValue       => undef,
        MIMEObj        => undef,
        ActivateScrips => 1,
        @_
    );

    #if we didn't specify a ticket, we need to bail
    unless ( $args{'Ticket'} ) {
        return ( 0, $self->loc( "Transaction->Create couldn't, as you didn't specify a ticket id"));
    }



    #lets create our transaction
    my %params = (Ticket    => $args{'Ticket'},
        Type      => $args{'Type'},
        Data      => $args{'Data'},
        Field     => $args{'Field'},
        OldValue  => $args{'OldValue'},
        NewValue  => $args{'NewValue'},
        Created   => $args{'Created'}
    );

    # Parameters passed in during an import that we probably don't want to touch, otherwise
    foreach my $attr qw(id Creator Created LastUpdated TimeTaken LastUpdatedBy) {
        $params{$attr} = $args{$attr} if ($args{$attr});
    }
 
    my $id = $self->SUPER::Create(%params);
    $self->Load($id);
    $self->_Attach( $args{'MIMEObj'} )
      if defined $args{'MIMEObj'};

    #Provide a way to turn off scrips if we need to
    if ( $args{'ActivateScrips'} ) {

        #We're really going to need a non-acled ticket for the scrips to work
        my $TicketAsSystem = RT::Ticket->new($RT::SystemUser);
        $TicketAsSystem->Load( $args{'Ticket'} )
          || $RT::Logger->err("$self couldn't load ticket $args{'Ticket'}\n");

        my $TransAsSystem = RT::Transaction->new($RT::SystemUser);
        $TransAsSystem->Load( $self->id )
          || $RT::Logger->err(
            "$self couldn't load a copy of itself as superuser\n"); 
        # {{{ Deal with Scrips

        use RT::Scrips;
        my $PossibleScrips = RT::Scrips->new($RT::SystemUser);

        $PossibleScrips->LimitToQueue( $TicketAsSystem->QueueObj->Id )
          ;                                  #Limit it to  $Ticket->QueueObj->Id
        $PossibleScrips->LimitToGlobal()
	    unless $TicketAsSystem->QueueObj->Disabled;    # or to "global"


        $PossibleScrips->Limit(FIELD => "Stage", VALUE => "TransactionCreate");


        my $ConditionsAlias = $PossibleScrips->NewAlias('ScripConditions');

        $PossibleScrips->Join(
            ALIAS1 => 'main',
            FIELD1 => 'ScripCondition',
            ALIAS2 => $ConditionsAlias,
            FIELD2 => 'id'
        );

        #We only want things where the scrip applies to this sort of transaction
        $PossibleScrips->Limit(
            ALIAS           => $ConditionsAlias,
            FIELD           => 'ApplicableTransTypes',
            OPERATOR        => 'LIKE',
            VALUE           => $args{'Type'},
            ENTRYAGGREGATOR => 'OR',
        );

        # Or where the scrip applies to any transaction
        $PossibleScrips->Limit(
            ALIAS           => $ConditionsAlias,
            FIELD           => 'ApplicableTransTypes',
            OPERATOR        => 'LIKE',
            VALUE           => "Any",
            ENTRYAGGREGATOR => 'OR',
        );

        #Iterate through each script and check it's applicability.

        while ( my $Scrip = $PossibleScrips->Next() ) {
            $Scrip->Apply (TicketObj => $TicketAsSystem,
                           TransactionObj => $TransAsSystem);
        }

        # }}}

    }

    return ( $id, $self->loc("Transaction Created") );
}

# }}}

# {{{ sub Delete

sub Delete {
    my $self = shift;
    return ( 0,
        $self->loc('Deleting this object could break referential integrity') );
}

# }}}

# {{{ Routines dealing with Attachments

# {{{ sub Message 

=head2 Message

  Returns the RT::Attachments Object which contains the "top-level"object
  attachment for this transaction

=cut

sub Message {

    my $self = shift;
    
    if ( !defined( $self->{'message'} ) ) {

        $self->{'message'} = new RT::Attachments( $self->CurrentUser );
        $self->{'message'}->Limit(
            FIELD => 'TransactionId',
            VALUE => $self->Id
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
    my $content_obj = $self->ContentObj;
    if ($content_obj) {
        $content = $content_obj->Content;
    }

    # If all else fails, return a message that we couldn't find any content
    else {
        $content = $self->loc('This transaction appears to have no content');
    }

    if ( $args{'Quote'} ) {

        # Remove quoted signature.
        $content =~ s/\n-- \n(.*)$//s;

        # What's the longest line like?
        my $max = 0;
        foreach ( split ( /\n/, $content ) ) {
            $max = length if ( length > $max );
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

        $content = '['
          . $self->CreatorObj->Name() . ' - '
          . $self->CreatedAsString() . "]:\n\n" . $content . "\n\n";
        $content =~ s/^/> /gm;

    }

    return ($content);
}

# }}}

# {{{ ContentObj

=head2 ContentObj 

Returns the RT::Attachment object which contains the content for this Transaction

=cut



sub ContentObj {

    my $self = shift;

    # If we don\'t have any content, return undef now.
    unless ( $self->Attachments->First ) {
        return (undef);
    }

    # Get the set of toplevel attachments to this transaction.
    my $Attachment = $self->Attachments->First();

    # If it's a message or a plain part, just return the
    # body.
    if ( $Attachment->ContentType() =~ '^(text/plain$|message/)' ) {
        return ($Attachment);
    }

    # If it's a multipart object, first try returning the first
    # text/plain part.

    elsif ( $Attachment->ContentType() =~ '^multipart/' ) {
        my $plain_parts = $Attachment->Children();
        $plain_parts->ContentType( VALUE => 'text/plain' );

        # If we actully found a part, return its content
        if ( $plain_parts->First && $plain_parts->First->Content ne '' ) {
            return ( $plain_parts->First );
        }

        # If that fails, return the  first text/plain or message/ part
        # which has some content.

        else {
            my $all_parts = $Attachment->Children();
            while ( my $part = $all_parts->Next ) {
                if (( $part->ContentType() =~ '^(text/plain$|message/)' ) &&  $part->Content()  ) {
                    return ($part);
                }
            }
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
    if ( $self->Attachments->First ) {
        return ( $self->Attachments->First->Subject );
    }
    else {
        return (undef);
    }
}

# }}}

# {{{ sub Attachments 

=head2 Attachments

  Returns all the RT::Attachment objects which are attached
to this transaction. Takes an optional parameter, which is
a ContentType that Attachments should be restricted to.

=cut

sub Attachments {
    my $self = shift;

    unless ( $self->{'attachments'} ) {
        $self->{'attachments'} = RT::Attachments->new( $self->CurrentUser );

        #If it's a comment, return an empty object if they don't have the right to see it
        if ( $self->Type eq 'Comment' ) {
            unless ( $self->CurrentUserHasRight('ShowTicketComments') ) {
                return ( $self->{'attachments'} );
            }
        }

        #if they ain't got rights to see, return an empty object
        else {
            unless ( $self->CurrentUserHasRight('ShowTicket') ) {
                return ( $self->{'attachments'} );
            }
        }

        $self->{'attachments'}->Limit( FIELD => 'TransactionId',
                                       VALUE => $self->Id );

        # Get the self->{'attachments'} in the order they're put into
        # the database.  Arguably, we should be returning a tree
        # of self->{'attachments'}, not a set...but no current app seems to need
        # it.

        $self->{'attachments'}->OrderBy( ALIAS => 'main',
                                         FIELD => 'id',
                                         ORDER => 'asc' );

    }
    return ( $self->{'attachments'} );

}

# }}}

# {{{ sub _Attach 

=head2 _Attach

A private method used to attach a mime object to this transaction.

=cut

sub _Attach {
    my $self       = shift;
    my $MIMEObject = shift;

    if ( !defined($MIMEObject) ) {
        $RT::Logger->error(
"$self _Attach: We can't attach a mime object if you don't give us one.\n"
        );
        return ( 0, $self->loc("[_1]: no attachment specified", $self) );
    }

    my $Attachment = new RT::Attachment( $self->CurrentUser );
    $Attachment->Create(
        TransactionId => $self->Id,
        Attachment    => $MIMEObject
    );
    return ( $Attachment, $self->loc("Attachment created") );

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

    #Check those ACLs
    #If it's a comment, we need to be extra special careful
    if ( $self->__Value('Type') eq 'Comment' ) {
        unless ( $self->CurrentUserHasRight('ShowTicketComments') ) {
            return ( $self->loc("Permission Denied") );
        }
    }

    #if they ain't got rights to see, don't let em
    else {
        unless ( $self->CurrentUserHasRight('ShowTicket') ) {
            return ($self->loc("Permission Denied") );
        }
    }

    if ( !defined( $self->Type ) ) {
        return ( $self->loc("No transaction type specified"));
    }

    return ( $self->loc("[_1] by [_2]",$self->BriefDescription , $self->CreatorObj->Name ));
}

# }}}

# {{{ sub BriefDescription 

=head2 BriefDescription

Returns a text string which briefly describes this transaction

=cut

sub BriefDescription {
    my $self = shift;


    #Check those ACLs
    #If it's a comment, we need to be extra special careful
    if ( $self->__Value('Type') eq 'Comment' ) {
        unless ( $self->CurrentUserHasRight('ShowTicketComments') ) {
            return ( $self->loc("Permission Denied") );
        }
    }

    #if they ain't got rights to see, don't let em
    else {
        unless ( $self->CurrentUserHasRight('ShowTicket') ) {
            return ( $self->loc("Permission Denied") );
        }
    }

    my $type = $self->Type; #cache this, rather than calling it 30 times

    if ( !defined( $type ) ) {
        return $self->loc("No transaction type specified");
    }

    if ( $type eq 'Create' ) {
        return ($self->loc("Ticket created"));
    }
    elsif ( $type =~ /Status/ ) {
        if ( $self->Field eq 'Status' ) {
            if ( $self->NewValue eq 'deleted' ) {
                return ($self->loc("Ticket deleted"));
            }
            else {
                return ( $self->loc("Status changed from [_1] to [_2]", $self->loc($self->OldValue), $self->loc($self->NewValue) ));

            }
        }

        # Generic:
       my $no_value = $self->loc("(no value)"); 
        return ( $self->loc( "[_1] changed from [_2] to [_3]", $self->Field , ( $self->OldValue || $no_value ) ,  $self->NewValue ));
    }

    if ( $type eq 'Correspond' ) {
        return $self->loc("Correspondence added");
    }

    elsif ( $type eq 'Comment' ) {
        return $self->loc("Comments added");
    }

    elsif ( $type eq 'CustomField' ) {

        my $field = $self->loc('CustomField');

        if ( $self->Field ) {
            my $cf = RT::CustomField->new( $self->CurrentUser );
            $cf->Load( $self->Field );
            $field = $cf->Name();
        }

        if ( $self->OldValue eq '' ) {
            return ( $self->loc("[_1] [_2] added", $field, $self->NewValue) );
        }
        elsif ( $self->NewValue eq '' ) {
            return ( $self->loc("[_1] [_2] deleted", $field, $self->OldValue) );

        }
        else {
            return $self->loc("[_1] [_2] changed to [_3]", $field, $self->OldValue, $self->NewValue );
        }
    }

    elsif ( $type eq 'Untake' ) {
        return $self->loc("Untaken");
    }

    elsif ( $type eq "Take" ) {
        return $self->loc("Taken");
    }

    elsif ( $type eq "Force" ) {
        my $Old = RT::User->new( $self->CurrentUser );
        $Old->Load( $self->OldValue );
        my $New = RT::User->new( $self->CurrentUser );
        $New->Load( $self->NewValue );

        return $self->loc("Owner forcibly changed from [_1] to [_2]" , $Old->Name , $New->Name);
    }
    elsif ( $type eq "Steal" ) {
        my $Old = RT::User->new( $self->CurrentUser );
        $Old->Load( $self->OldValue );
        return $self->loc("Stolen from [_1] ",  $Old->Name);
    }

    elsif ( $type eq "Give" ) {
        my $New = RT::User->new( $self->CurrentUser );
        $New->Load( $self->NewValue );
        return $self->loc( "Given to [_1]",  $New->Name );
    }

    elsif ( $type eq 'AddWatcher' ) {
        my $principal = RT::Principal->new($self->CurrentUser);
        $principal->Load($self->NewValue);
        return $self->loc( "[_1] [_2] added", $self->Field, $principal->Object->Name);
    }

    elsif ( $type eq 'DelWatcher' ) {
        my $principal = RT::Principal->new($self->CurrentUser);
        $principal->Load($self->OldValue);
        return $self->loc( "[_1] [_2] deleted", $self->Field, $principal->Object->Name);
    }

    elsif ( $type eq 'Subject' ) {
        return $self->loc( "Subject changed to [_1]", $self->Data );
    }

    elsif ( $type eq 'AddLink' ) {
        my $value;
	if ($self->NewValue) {
		my $URI = RT::URI->new($self->CurrentUser);
		$URI->FromURI($self->NewValue);
		if ($URI->Resolver) {
			$value = $URI->Resolver->AsString;
		} else {
			$value = $self->NewValue;
		}
	}
	if ($self->Field eq 'DependsOn') {
		return $self->loc("Dependency on [_1] added",$value);
	} elsif ($self->Field eq 'DependedOnBy') {
		return $self->loc("Dependency by [_1] added",$value);
		
	} elsif ($self->Field eq 'RefersTo') {
		return $self->loc("Reference to [_1] added",$value);
	} elsif ($self->Field eq 'ReferredToBy') {
		return $self->loc("Reference by [_1] added",$value);
	} elsif ($self->Field eq 'MemberOf') {
		return $self->loc("Membership in [_1] added",$value);
	} elsif ($self->Field eq 'HasMember') {
		return $self->loc("Member [_1] added",$value);
	} else {
        return ( $self->Data );
	}
    }
    elsif ( $type eq 'DeleteLink' ) {
    my $value;
	if ($self->OldValue) {
		my $URI = RT::URI->new($self->CurrentUser);
		$URI->FromURI($self->OldValue);
		if ($URI->Resolver) {
			$value = $URI->Resolver->AsString;
		} else {
			$value = $self->OldValue;
		}
	}

	if ($self->Field eq 'DependsOn') {
		return $self->loc("Dependency on [_1] deleted",$value);
	} elsif ($self->Field eq 'DependedOnBy') {
		return $self->loc("Dependency by [_1] deleted",$value);
		
	} elsif ($self->Field eq 'RefersTo') {
		return $self->loc("Reference to [_1] deleted",$value);
	} elsif ($self->Field eq 'ReferredToBy') {
		return $self->loc("Reference by [_1] deleted",$value);
	} elsif ($self->Field eq 'MemberOf') {
		return $self->loc("Membership in [_1] deleted",$value);
	} elsif ($self->Field eq 'HasMember') {
		return $self->loc("Member [_1] deleted",$value);
	} else {
        return ( $self->Data );
	}
    }
    elsif ( $type eq 'Set' ) {
        if ( $self->Field eq 'Queue' ) {
            my $q1 = new RT::Queue( $self->CurrentUser );
            $q1->Load( $self->OldValue );
            my $q2 = new RT::Queue( $self->CurrentUser );
            $q2->Load( $self->NewValue );
            return $self->loc("[_1] changed from [_2] to [_3]", $self->Field , $q1->Name , $q2->Name);
        }

        # Write the date/time change at local time:
    elsif ($self->Field =~  /Due|Starts|Started|Told/) {
        my $t1 = new RT::Date($self->CurrentUser);
        $t1->Set(Format => 'ISO', Value => $self->NewValue);
        my $t2 = new RT::Date($self->CurrentUser);
        $t2->Set(Format => 'ISO', Value => $self->OldValue);
        return $self->loc( "[_1] changed from [_2] to [_3]", $self->Field, $t2->AsString, $t1->AsString );
    }
        else {
            return $self->loc( "[_1] changed from [_2] to [_3]", $self->Field, $self->OldValue, $self->NewValue );
        }
    }
    elsif ( $type eq 'PurgeTransaction' ) {
        return $self->loc("Transaction [_1] purged", $self->Data);
    }
    else {
        return $self->loc( "Default: [_1]/[_2] changed from [_3] to [_4]", $type, $self->Field, $self->OldValue, $self->NewValue );

    }
}

# }}}

# {{{ Utility methods

# {{{ sub IsInbound

=head2 IsInbound

Returns true if the creator of the transaction is a requestor of the ticket.
Returns false otherwise

=cut

sub IsInbound {
    my $self = shift;
    return ( $self->TicketObj->IsRequestor( $self->CreatorObj->PrincipalId ) );
}

# }}}

# }}}

sub _ClassAccessible {
    {

        id => { read => 1, type => 'int(11)', default => '' },
          EffectiveTicket =>
          { read => 1, write => 1, type => 'int(11)', default => '' },
          Ticket =>
          { read => 1, public => 1, type => 'int(11)', default => '' },
          TimeTaken => { read => 1, type => 'int(11)',      default => '' },
          Type      => { read => 1, type => 'varchar(20)',  default => '' },
          Field     => { read => 1, type => 'varchar(40)',  default => '' },
          OldValue  => { read => 1, type => 'varchar(255)', default => '' },
          NewValue  => { read => 1, type => 'varchar(255)', default => '' },
          Data      => { read => 1, type => 'varchar(100)', default => '' },
          Creator => { read => 1, auto => 1, type => 'int(11)', default => '' },
          Created =>
          { read => 1, auto => 1, type => 'datetime', default => '' },

    }
};

# }}}

# }}}

# {{{ sub _Set

sub _Set {
    my $self = shift;
    return ( 0, $self->loc('Transactions are immutable') );
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

    #if the field is public, return it.
    if ( $self->_Accessible( $field, 'public' ) ) {
        return ( $self->__Value($field) );

    }

    #If it's a comment, we need to be extra special careful
    if ( $self->__Value('Type') eq 'Comment' ) {
        unless ( $self->CurrentUserHasRight('ShowTicketComments') ) {
            return (undef);
        }
    }

    #if they ain't got rights to see, don't let em
    else {
        unless ( $self->CurrentUserHasRight('ShowTicket') ) {
            return (undef);
        }
    }

    return ( $self->__Value($field) );

}

# }}}

# {{{ sub CurrentUserHasRight

=head2 CurrentUserHasRight RIGHT

Calls $self->CurrentUser->HasQueueRight for the right passed in here.
passed in here.

=cut

sub CurrentUserHasRight {
    my $self  = shift;
    my $right = shift;
    return (
        $self->CurrentUser->HasRight(
            Right     => "$right",
            Object => $self->TicketObj
          )
    );
}

# }}}

1;
