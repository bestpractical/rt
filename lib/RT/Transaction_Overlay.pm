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


package RT::Transaction;

use strict;
no warnings qw(redefine);

use vars qw( %_BriefDescriptions $PreferredContentType );

use RT::Attachments;
use RT::Scrips;

use HTML::FormatText;
use HTML::TreeBuilder;


# {{{ sub Create 

=head2 Create

Create a new transaction.

This routine should _never_ be called by anything other than RT::Ticket. 
It should not be called 
from client code. Ever. Not ever.  If you do this, we will hunt you down and break your kneecaps.
Then the unpleasant stuff will start.

TODO: Document what gets passed to this

=cut

sub Create {
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
	ObjectType => 'RT::Ticket',
	ObjectId => 0,
	ReferenceType => undef,
        OldReference       => undef,
        NewReference       => undef,
        @_
    );

    $args{ObjectId} ||= $args{Ticket};

    #if we didn't specify a ticket, we need to bail
    unless ( $args{'ObjectId'} && $args{'ObjectType'}) {
        return ( 0, $self->loc( "Transaction->Create couldn't, as you didn't specify an object type and id"));
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
 
    my $id = $self->SUPER::Create(%params);
    $self->Load($id);
    if ( defined $args{'MIMEObj'} ) {
        my ($id, $msg) = $self->_Attach( $args{'MIMEObj'} );
        unless ( $id ) {
            $RT::Logger->error("Couldn't add attachment: $msg");
            return ( 0, $self->loc("Couldn't add attachment") );
        }
    }


    #Provide a way to turn off scrips if we need to
        $RT::Logger->debug('About to think about scrips for transaction #' .$self->Id);
    if ( $args{'ActivateScrips'} and $args{'ObjectType'} eq 'RT::Ticket' ) {
       $self->{'scrips'} = RT::Scrips->new($RT::SystemUser);

        $RT::Logger->debug('About to prepare scrips for transaction #' .$self->Id); 

        $self->{'scrips'}->Prepare(
            Stage       => 'TransactionCreate',
            Type        => $args{'Type'},
            Ticket      => $args{'ObjectId'},
            Transaction => $self->id,
        );
        if ($args{'CommitScrips'} ) {
            $RT::Logger->debug('About to commit scrips for transaction #' .$self->Id);
            $self->{'scrips'}->Commit();
        }
    }

    return ( $id, $self->loc("Transaction Created") );
}

# }}}

=head2 Scrips

Returns the Scrips object for this transaction.
This routine is only useful on a freshly created transaction object.
Scrips do not get persisted to the database with transactions.


=cut


sub Scrips {
    my $self = shift;
    return($self->{'scrips'});
}


# {{{ sub Delete

=head2 Delete

Delete this transaction. Currently DOES NOT CHECK ACLS

=cut

sub Delete {
    my $self = shift;


    $RT::Handle->BeginTransaction();

    my $attachments = $self->Attachments;

    while (my $attachment = $attachments->Next) {
        my ($id, $msg) = $attachment->Delete();
        unless ($id) {
            $RT::Handle->Rollback();
            return($id, $self->loc("System Error: [_1]", $msg));
        }
    }
    my ($id,$msg) = $self->SUPER::Delete();
        unless ($id) {
            $RT::Handle->Rollback();
            return($id, $self->loc("System Error: [_1]", $msg));
        }
    $RT::Handle->Commit();
    return ($id,$msg);
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

If this transaction has attached mime objects, returns the body of the first
textual part (as defined in RT::I18N::IsTextualContentType).  Otherwise,
returns undef.

Takes a paramhash.  If the $args{'Quote'} parameter is set, wraps this message 
at $args{'Wrap'}.  $args{'Wrap'} defaults to 70.

If $args{'Type'} is set to C<text/html>, plain texts are upgraded to HTML.
Otherwise, HTML texts are downgraded to plain text.  If $args{'Type'} is
missing, it defaults to the value of C<$RT::Transaction::PreferredContentType>.

=cut

sub Content {
    my $self = shift;
    my %args = (
        Type  => $PreferredContentType,
        Quote => 0,
        Wrap  => 70,
        @_
    );

    my $content;
    if (my $content_obj = $self->ContentObj) {
        $content = $content_obj->Content;

	if ($content_obj->ContentType =~ m{^text/html$}i) {
            $content =~ s/<p>--\s+<br \/>.*?$//s if $args{'Quote'};

            if ($args{Type} ne 'text/html') {
                $content = HTML::FormatText->new(
                    leftmargin  => 0,
                    rightmargin => 78,
                )->format(
                    HTML::TreeBuilder->new_from_content( $content )
                );
            }
	}
        else {
            $content =~ s/\n-- \n.*?$//s if $args{'Quote'};

            if ($args{Type} eq 'text/html') {
                # Extremely simple text->html converter
                $content =~ s/&/&#38;/g;
                $content =~ s/</&lt;/g;
                $content =~ s/>/&gt;/g;
                $content = "<pre>$content</pre>";
            }
        }
    }

    # If all else fails, return a message that we couldn't find any content
    else {
        $content = $self->loc('This transaction appears to have no content');
    }

    if ( $args{'Quote'} ) {

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

        $content =~ s/^/> /gm;
        $content = $self->loc("On [_1], [_2] wrote:", $self->CreatedAsString(), $self->CreatorObj->Name())
          . "\n$content\n\n";
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

    # If it's a textual part, just return the body.
    if ( RT::I18N::IsTextualContentType($Attachment->ContentType) ) {
        return ($Attachment);
    }

    # If it's a multipart object, first try returning the first part with preferred
    # MIME type ('text/plain' by default).

    elsif ( $Attachment->ContentType() =~ '^multipart/' ) {
        my $plain_parts = $Attachment->Children();
        $plain_parts->ContentType( VALUE => ($PreferredContentType || 'text/plain') );

        # If we actully found a part, return its content
        if ( $plain_parts->First && $plain_parts->First->Content ne '' ) {
            return ( $plain_parts->First );
        }


        # If that fails, return the first textual part which has some content.

        else {
            my $all_parts = $self->Attachments();
            while ( my $part = $all_parts->Next ) {
                if ( ( RT::I18N::IsTextualContentType($part->ContentType) ) and ( $part->Content() ne '' ) ) {
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
        elsif ($self->__Value('ObjectType') eq "RT::Ticket") {
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
    my ($id, $msg) = $Attachment->Create(
        TransactionId => $self->Id,
        Attachment    => $MIMEObject
    );
    return ( $Attachment, $msg || $self->loc("Attachment created") );

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
    #If it's a comment or a comment email record,
    #  we need to be extra special careful

    if ( $self->__Value('Type') =~ /^Comment/ ) {
        unless ( $self->CurrentUserHasRight('ShowTicketComments') ) {
            return ( $self->loc("Permission Denied") );
        }
    }

    #if they ain't got rights to see, don't let em
    elsif ($self->__Value('ObjectType') eq "RT::Ticket") {
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

    #If it's a comment or a comment email record,
    #  we need to be extra special careful
    if ( $self->__Value('Type') =~ /^Comment/ ) {
        unless ( $self->CurrentUserHasRight('ShowTicketComments') ) {
            return ( $self->loc("Permission Denied") );
        }
    }

    #if they ain't got rights to see, don't let em
    elsif ( $self->__Value('ObjectType') eq "RT::Ticket" ) {
        unless ( $self->CurrentUserHasRight('ShowTicket') ) {
            return ( $self->loc("Permission Denied") );
        }
    }

    my $type = $self->Type;    #cache this, rather than calling it 30 times

    if ( !defined($type) ) {
        return $self->loc("No transaction type specified");
    }

    my $obj_type = $self->FriendlyObjectType;

    if ( $type eq 'Create' ) {
        return ( $self->loc( "[_1] created", $obj_type ) );
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
        my $Old = RT::User->new( $self->CurrentUser );
        $Old->Load( $self->OldValue );
        my $New = RT::User->new( $self->CurrentUser );
        $New->Load( $self->NewValue );

        return $self->loc("Owner forcibly changed from [_1] to [_2]" , $Old->Name , $New->Name);
    },
    Steal => sub {
        my $self = shift;
        my $Old = RT::User->new( $self->CurrentUser );
        $Old->Load( $self->OldValue );
        return $self->loc("Stolen from [_1]",  $Old->Name);
    },
    Give => sub {
        my $self = shift;
        my $New = RT::User->new( $self->CurrentUser );
        $New->Load( $self->NewValue );
        return $self->loc( "Given to [_1]",  $New->Name );
    },
    AddWatcher => sub {
        my $self = shift;
        my $principal = RT::Principal->new($self->CurrentUser);
        $principal->Load($self->NewValue);
        return $self->loc( "[_1] [_2] added", $self->Field, $principal->Object->Name);
    },
    DelWatcher => sub {
        my $self = shift;
        my $principal = RT::Principal->new($self->CurrentUser);
        $principal->Load($self->OldValue);
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
            elsif ( $self->Field eq 'HasMember' ) {
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
    DeleteLink => sub {
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
            elsif ( $self->Field eq 'HasMember' ) {
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
            return $self->loc( "[_1] changed from [_2] to [_3]", $self->Field, ($self->OldValue? "'".$self->OldValue ."'" : $self->loc("(no value)")) , "'". $self->NewValue."'" );
        }
    },
    PurgeTransaction => sub {
        my $self = shift;
        return $self->loc("Transaction [_1] purged", $self->Data);
    },
    AddReminder => sub {
        my $self = shift;
        my $ticket = RT::Ticket->new($self->CurrentUser);
        $ticket->Load($self->NewValue);
        return $self->loc("Reminder '[_1]' added", $ticket->Subject);
    },
    OpenReminder => sub {
        my $self = shift;
        my $ticket = RT::Ticket->new($self->CurrentUser);
        $ticket->Load($self->NewValue);
        return $self->loc("Reminder '[_1]' reopened", $ticket->Subject);
    
    },
    ResolveReminder => sub {
        my $self = shift;
        my $ticket = RT::Ticket->new($self->CurrentUser);
        $ticket->Load($self->NewValue);
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
    $self->ObjectType eq 'RT::Ticket' or return undef;
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
    elsif ( $self->__Value('Type') eq 'CommentEmailRecord' ) {
        unless ( $self->CurrentUserHasRight('ShowTicketComments')
            && $self->CurrentUserHasRight('ShowOutgoingEmail') ) {
            return (undef);
        }

    }
    elsif ( $self->__Value('Type') eq 'EmailRecord' ) {
        unless ( $self->CurrentUserHasRight('ShowOutgoingEmail')) {
            return (undef);
        }

    }
    # Make sure the user can see the custom field before showing that it changed
    elsif ( ( $self->__Value('Type') eq 'CustomField' ) && $self->__Value('Field') ) {
        my $cf = RT::CustomField->new( $self->CurrentUser );
        $cf->Load( $self->__Value('Field') );
        return (undef) unless ( $cf->CurrentUserHasRight('SeeCustomField') );
    }


    #if they ain't got rights to see, don't let em
    elsif ($self->__Value('ObjectType') eq "RT::Ticket") {
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
    if ( my $type = $self->__Value('ReferenceType')
         and my $id = $self->__Value('OldReference') )
    {
        my $Object = $type->new($self->CurrentUser);
        $Object->Load( $id );
        return $Object->Content;
    }
    else {
        return $self->__Value('OldValue');
    }
}

sub NewValue {
    my $self = shift;
    if ( my $type = $self->__Value('ReferenceType')
         and my $id = $self->__Value('NewReference') )
    {
        my $Object = $type->new($self->CurrentUser);
        $Object->Load( $id );
        return $Object->Content;
    }
    else {
        return $self->__Value('NewValue');
    }
}

sub Object {
    my $self  = shift;
    my $Object = $self->__Value('ObjectType')->new($self->CurrentUser);
    $Object->Load($self->__Value('ObjectId'));
    return($Object);
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

    Object-RT::Transaction-CustomField-<<Id>> => Value parameters to update
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
            /^(?:Object-RT::Transaction--)?CustomField-(\d+)/ );
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

        unless ( defined $field && $field =~ /^\d+$/o ) {
            my $CFs = RT::CustomFields->new( $self->CurrentUser );
             $CFs->Limit( FIELD => 'Name', VALUE => $field);
            $CFs->LimitToLookupType($self->CustomFieldLookupType);
            $CFs->LimitToGlobalOrObjectId($self->Object->QueueObj->id);
            $field = $CFs->First->id if $CFs->First;
        }
    }
    return $self->SUPER::CustomFieldValues($field);
}

# }}}

# {{{ sub CustomFieldLookupType

=head2 CustomFieldLookupType

Returns the RT::Transaction lookup type, which can 
be passed to RT::CustomField->Create() via the 'LookupType' hash key.

=cut

# }}}

sub CustomFieldLookupType {
    "RT::Queue-RT::Ticket-RT::Transaction";
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
