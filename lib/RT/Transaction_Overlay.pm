# BEGIN BPS TAGGED BLOCK {{{
# 
# COPYRIGHT:
# 
# This software is Copyright (c) 1996-2009 Best Practical Solutions, LLC
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

  RT::Transaction - RT\'s transaction object

=head1 SYNOPSIS

  use RT::Transaction;


=head1 DESCRIPTION


Each RT::Transaction describes an atomic change to a ticket object 
or an update to an RT::Ticket object.
It can have arbitrary MIME attachments.


=head1 METHODS


=cut


package RT::Transaction;

use strict;
no warnings qw(redefine);

use vars qw( %_BriefDescriptions $PreferredContentType );

use RT::Attachments;
use RT::Scrips;
use RT::Ruleset;

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

       # Entry point of the rule system
       my $ticket = RT::Ticket->new($RT::SystemUser);
       $ticket->Load($args{'ObjectId'});
       my $rules = RT::Ruleset->FindAllRules(
            Stage       => 'TransactionCreate',
            Type        => $args{'Type'},
            TicketObj   => $ticket,
            TransactionObj => $self,
       );

        if ($args{'CommitScrips'} ) {
            $RT::Logger->debug('About to commit scrips for transaction #' .$self->Id);
            $self->{'scrips'}->Commit();
            RT::Ruleset->CommitRules($rules);
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

Returns the L<RT::Attachments> object which contains the "top-level" object
attachment for this transaction.

=cut

sub Message {
    my $self = shift;

    # XXX: Where is ACL check?
    
    unless ( defined $self->{'message'} ) {

        $self->{'message'} = RT::Attachments->new( $self->CurrentUser );
        $self->{'message'}->Limit(
            FIELD => 'TransactionId',
            VALUE => $self->Id
        );
        $self->{'message'}->ChildrenOf(0);
    } else {
        $self->{'message'}->GotoFirstItem;
    }
    return $self->{'message'};
}

# }}}

# {{{ sub Content

=head2 Content PARAMHASH

If this transaction has attached mime objects, returns the body of the first
textual part (as defined in RT::I18N::IsTextualContentType).  Otherwise,
returns undef.

Takes a paramhash.  If the $args{'Quote'} parameter is set, wraps this message 
at $args{'Wrap'}.  $args{'Wrap'} defaults to 70.

If $args{'Type'} is set to C<text/html>, this will return an HTML 
part of the message, if available.  Otherwise it looks for a text/plain
part. If $args{'Type'} is missing, it defaults to the value of 
C<$RT::Transaction::PreferredContentType>, if that's missing too, 
defaults to 'text/plain'.

=cut

sub Content {
    my $self = shift;
    my %args = (
        Type  => $PreferredContentType || 'text/plain',
        Quote => 0,
        Wrap  => 70,
        @_
    );

    my $content;
    if ( my $content_obj = $self->ContentObj( Type => $args{Type} ) ) {
        $content = $content_obj->Content ||'';

        if ( lc $content_obj->ContentType eq 'text/html' ) {
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

Returns a hashref of addresses related to this transaction. See L<RT::Attachment/Addresses> for details.

=cut

sub Addresses {
	my $self = shift;

	if (my $attach = $self->Attachments->First) {	
		return $attach->Addresses;
	}
	else {
		return {};
	}

}


# {{{ ContentObj

=head2 ContentObj 

Returns the RT::Attachment object which contains the content for this Transaction

=cut


sub ContentObj {
    my $self = shift;
    my %args = ( Type => $PreferredContentType || 'text/plain',
                 @_ );

    # If we don't have any content, return undef now.
    # Get the set of toplevel attachments to this transaction.
    return undef unless my $Attachment = $self->Attachments->First;

    # If it's a textual part, just return the body.
    if ( RT::I18N::IsTextualContentType($Attachment->ContentType) ) {
        return ($Attachment);
    }

    # If it's a multipart object, first try returning the first part with preferred
    # MIME type ('text/plain' by default).

    elsif ( $Attachment->ContentType =~ '^multipart/' ) {
        my $plain_parts = $Attachment->Children;
        $plain_parts->ContentType( VALUE => $args{Type} );
        $plain_parts->LimitNotEmpty;

        # If we actully found a part, return its content
        if ( my $first = $plain_parts->First ) {
            return $first;
        }

        # If that fails, return the first textual part which has some content.
        my $all_parts = $self->Attachments;
        while ( my $part = $all_parts->Next ) {
            next unless RT::I18N::IsTextualContentType($part->ContentType)
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
    return undef unless my $first = $self->Attachments->First;
    return $first->Subject;
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

    if ( $self->{'attachments'} ) {
        $self->{'attachments'}->GotoFirstItem;
        return $self->{'attachments'};
    }

    $self->{'attachments'} = RT::Attachments->new( $self->CurrentUser );

    unless ( $self->CurrentUserCanSee ) {
        $self->{'attachments'}->Limit(FIELD => 'id', VALUE => '0');
        return $self->{'attachments'};
    }

    $self->{'attachments'}->Limit( FIELD => 'TransactionId', VALUE => $self->Id );

    # Get the self->{'attachments'} in the order they're put into
    # the database.  Arguably, we should be returning a tree
    # of self->{'attachments'}, not a set...but no current app seems to need
    # it.

    $self->{'attachments'}->OrderBy( FIELD => 'id', ORDER => 'ASC' );

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

    my $Attachment = RT::Attachment->new( $self->CurrentUser );
    my ($id, $msg) = $Attachment->Create(
        TransactionId => $self->Id,
        Attachment    => $MIMEObject
    );
    return ( $Attachment, $msg || $self->loc("Attachment created") );
}

# }}}

# }}}

sub ContentAsMIME {
    my $self = shift;

    my $main_content = $self->ContentObj;
    my $entity = $main_content->ContentAsMIME;

    if ( $main_content->Parent ) {
        # main content is not top most entity, we shouldn't loose
        # From/To/Cc headers that are on a top part
        my $attachments = RT::Attachments->new( $self->CurrentUser );
        $attachments->Columns(qw(id Parent TransactionId Headers));
        $attachments->Limit( FIELD => 'TransactionId', VALUE => $self->id );
        $attachments->Limit( FIELD => 'Parent', VALUE => 0 );
        $attachments->Limit( FIELD => 'Parent', OPERATOR => 'IS', VALUE => 'NULL', QUOTEVALUE => 0 );
        $attachments->OrderBy( FIELD => 'id', ORDER => 'ASC' );
        my $tmp = $attachments->First;
        if ( $tmp && $tmp->id ne $main_content->id ) {
            $entity->make_multipart;
            $entity->head->add( split /:/, $_, 2 ) foreach $tmp->SplitHeaders;
            $entity->make_singlepart;
        }
    }

    my $attachments = RT::Attachments->new( $self->CurrentUser );
    $attachments->Limit( FIELD => 'TransactionId', VALUE => $self->id );
    $attachments->Limit(
        FIELD => 'id',
        OPERATOR => '!=',
        VALUE => $main_content->id,
    );
    $attachments->Limit(
        FIELD => 'ContentType',
        OPERATOR => 'NOT STARTSWITH',
        VALUE => 'multipart/',
    );
    $attachments->Limit(
        FIELD => 'Content',
        OPERATOR => '!=',
        VALUE => '',
    );
    while ( my $a = $attachments->Next ) {
        $entity->make_multipart unless $entity->is_multipart;
        $entity->add_part( $a->ContentAsMIME );
    }
    return $entity;
}

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
        return ( $self->loc( "[_1] created", $obj_type ) );
    }
    elsif ( $type eq 'Enabled' ) {
        return ( $self->loc( "[_1] enabled", $obj_type ) );
    }
    elsif ( $type eq 'Disabled' ) {
        return ( $self->loc( "[_1] disabled", $obj_type ) );
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

        if ( ! defined $self->OldValue || $self->OldValue eq '' ) {
            return ( $self->loc("[_1] [_2] added", $field, $self->NewValue) );
        }
        elsif ( !defined $self->NewValue || $self->NewValue eq '' ) {
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
    Told => sub {
        my $self = shift;
        if ( $self->Field eq 'Told' ) {
            my $t1 = new RT::Date($self->CurrentUser);
            $t1->Set(Format => 'ISO', Value => $self->NewValue);
            my $t2 = new RT::Date($self->CurrentUser);
            $t2->Set(Format => 'ISO', Value => $self->OldValue);
            return $self->loc( "[_1] changed from [_2] to [_3]", $self->loc($self->Field), $t2->AsString, $t1->AsString );
        }
        else {
            return $self->loc( "[_1] changed from [_2] to [_3]",
                               $self->loc($self->Field),
                               ($self->OldValue? "'".$self->OldValue ."'" : $self->loc("(no value)")) , "'". $self->NewValue."'" );
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
            return $self->loc("[_1] changed from [_2] to [_3]",
                              $self->loc($self->Field) , $q1->Name , $q2->Name);
        }

        # Write the date/time change at local time:
        elsif ($self->Field =~  /Due|Starts|Started|Told/) {
            my $t1 = new RT::Date($self->CurrentUser);
            $t1->Set(Format => 'ISO', Value => $self->NewValue);
            my $t2 = new RT::Date($self->CurrentUser);
            $t2->Set(Format => 'ISO', Value => $self->OldValue);
            return $self->loc( "[_1] changed from [_2] to [_3]", $self->loc($self->Field), $t2->AsString, $t1->AsString );
        }
        else {
            return $self->loc( "[_1] changed from [_2] to [_3]",
                               $self->loc($self->Field),
                               ($self->OldValue? "'".$self->OldValue ."'" : $self->loc("(no value)")) , "'". $self->NewValue."'" );
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
        return $self->SUPER::_Value( $field );
    }

    unless ( $self->CurrentUserCanSee ) {
        return undef;
    }

    return $self->SUPER::_Value( $field );
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
    return $self->CurrentUser->HasRight(
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
    my $type = $self->__Value('Type');
    if ( $type eq 'Comment' ) {
        unless ( $self->CurrentUserHasRight('ShowTicketComments') ) {
            return 0;
        }
    }
    elsif ( $type eq 'CommentEmailRecord' ) {
        unless ( $self->CurrentUserHasRight('ShowTicketComments')
            && $self->CurrentUserHasRight('ShowOutgoingEmail') ) {
            return 0;
        }
    }
    elsif ( $type eq 'EmailRecord' ) {
        unless ( $self->CurrentUserHasRight('ShowOutgoingEmail') ) {
            return 0;
        }
    }
    # Make sure the user can see the custom field before showing that it changed
    elsif ( $type eq 'CustomField' and my $cf_id = $self->__Value('Field') ) {
        my $cf = RT::CustomField->new( $self->CurrentUser );
        $cf->SetContextObject( $self->Object );
        $cf->Load( $cf_id );
        return 0 unless $cf->CurrentUserHasRight('SeeCustomField');
    }
    #if they ain't got rights to see, don't let em
    elsif ( $self->__Value('ObjectType') eq "RT::Ticket" ) {
        unless ( $self->CurrentUserHasRight('ShowTicket') ) {
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

        # XXX: $field could be undef when we want fetch values for all CFs
        #      do we want to cover this situation somehow here?
        unless ( defined $field && $field =~ /^\d+$/o ) {
            my $CFs = RT::CustomFields->new( $self->CurrentUser );
            $CFs->Limit( FIELD => 'Name', VALUE => $field );
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


=head2 DeferredRecipients($freq, $include_sent )

Takes the following arguments:

=over

=item * a string to indicate the frequency of digest delivery.  Valid values are "daily", "weekly", or "susp".

=item * an optional argument which, if true, will return addresses even if this notification has been marked as 'sent' for this transaction.

=back

Returns an array of users who should now receive the notification that
was recorded in this transaction.  Returns an empty array if there were
no deferred users, or if $include_sent was not specified and the deferred
notifications have been sent.

=cut

sub DeferredRecipients {
    my $self = shift;
    my $freq = shift;
    my $include_sent = @_? shift : 0;

    my $attr = $self->FirstAttribute('DeferredRecipients');

    return () unless ($attr);

    my $deferred = $attr->Content;

    return () unless ( ref($deferred) eq 'HASH' && exists $deferred->{$freq} );

    # Skip it.
   
    for my $user (keys %{$deferred->{$freq}}) {
        if ($deferred->{$freq}->{$user}->{_sent} && !$include_sent) { 
            delete $deferred->{$freq}->{$user} 
        }
    }
    # Now get our users.  Easy.
    
    return keys %{ $deferred->{$freq} };
}



# Transactions don't change. by adding this cache config directive, we don't lose pathalogically on long tickets.
sub _CacheConfig {
  {
     'cache_p'        => 1,
     'fast_update_p'  => 1,
     'cache_for_sec'  => 6000,
  }
}
1;
