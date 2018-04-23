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

  RT::Transaction - RT's transaction object

=head1 SYNOPSIS

  use RT::Transaction;


=head1 DESCRIPTION


Each RT::Transaction describes an atomic change to a ticket object 
or an update to an RT::Ticket object.
It can have arbitrary MIME attachments.


=head1 METHODS


=cut


package RT::Transaction;

use base 'RT::Record';
use strict;
use warnings;


use vars qw( %_BriefDescriptions $PreferredContentType );

use RT::Attachments;
use RT::Scrips;
use RT::Ruleset;

use HTML::FormatText::WithLinks::AndTables;
use HTML::Scrubber;

# For EscapeHTML() and decode_entities()
require RT::Interface::Web;
require HTML::Entities;

sub Table {'Transactions'}

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
        DryRun         => undef,
        ObjectType     => 'RT::Ticket',
        ObjectId       => 0,
        ReferenceType  => undef,
        OldReference   => undef,
        NewReference   => undef,
        SquelchMailTo  => undef,
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
    foreach my $attr (qw(id Creator Created LastUpdated TimeTaken LastUpdatedBy)) {
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

    $self->AddAttribute(
        Name    => 'SquelchMailTo',
        Content => RT::User->CanonicalizeEmailAddress($_)
    ) for @{$args{'SquelchMailTo'} || []};

    my @return = ( $id, $self->loc("Transaction Created") );

    return @return unless $args{'ObjectType'} eq 'RT::Ticket';

    # Provide a way to turn off scrips if we need to
    unless ( $args{'ActivateScrips'} ) {
        $RT::Logger->debug('Skipping scrips for transaction #' .$self->Id);
        return @return;
    }

    push @{$args{DryRun}}, $self if $args{DryRun};

    $self->{'scrips'} = RT::Scrips->new(RT->SystemUser);

    $RT::Logger->debug('About to prepare scrips for transaction #' .$self->Id); 

    $self->{'scrips'}->Prepare(
        Stage       => 'TransactionCreate',
        Type        => $args{'Type'},
        Ticket      => $args{'ObjectId'},
        Transaction => $self->id,
    );

   # Entry point of the rule system
   my $ticket = RT::Ticket->new(RT->SystemUser);
   $ticket->Load($args{'ObjectId'});
   my $txn = RT::Transaction->new($RT::SystemUser);
   $txn->Load($self->id);

   my $rules = $self->{rules} = RT::Ruleset->FindAllRules(
        Stage       => 'TransactionCreate',
        Type        => $args{'Type'},
        TicketObj   => $ticket,
        TransactionObj => $txn,
   );

    unless ($args{DryRun} ) {
        $RT::Logger->debug('About to commit scrips for transaction #' .$self->Id);
        $self->{'scrips'}->Commit();
        RT::Ruleset->CommitRules($rules);
    }

    return @return;
}


=head2 Scrips

Returns the Scrips object for this transaction.
This routine is only useful on a freshly created transaction object.
Scrips do not get persisted to the database with transactions.


=cut


sub Scrips {
    my $self = shift;
    return($self->{'scrips'});
}


=head2 Rules

Returns the array of Rule objects for this transaction.
This routine is only useful on a freshly created transaction object.
Rules do not get persisted to the database with transactions.


=cut


sub Rules {
    my $self = shift;
    return($self->{'rules'});
}



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



=head2 HasContent

Returns whether this transaction has attached mime objects.

=cut

sub HasContent {
    my $self = shift;
    my $type = $PreferredContentType || '';
    return !!$self->ContentObj( $type ? ( Type => $type) : () );
}



=head2 Content PARAMHASH

If this transaction has attached mime objects, returns the body of the first
textual part (as defined in RT::I18N::IsTextualContentType).  Otherwise,
returns the message "This transaction appears to have no content".

Takes a paramhash.  If the $args{'Quote'} parameter is set, wraps this message 
at $args{'Wrap'}.  $args{'Wrap'} defaults to 70.

If $args{'Type'} is set to C<text/html>, this will return an HTML 
part of the message, if available.  Otherwise it looks for a text/plain
part. If $args{'Type'} is missing, it defaults to the value of 
C<$RT::Transaction::PreferredContentType>, if that's missing too, 
defaults to textual.

=cut

sub Content {
    my $self = shift;
    my %args = (
        Type => $PreferredContentType || '',
        Quote => 0,
        Wrap  => 70,
        @_
    );

    my $content;
    if ( my $content_obj = 
        $self->ContentObj( $args{Type} ? ( Type => $args{Type}) : () ) )
    {
        $content = $content_obj->Content ||'';

        if ( lc $content_obj->ContentType eq 'text/html' ) {
            $content =~ s/(?:(<\/div>)|<p>|<br\s*\/?>|<div(\s+class="[^"]+")?>)\s*--\s+<br\s*\/?>.*?$/$1/s if $args{'Quote'};

            if ($args{Type} ne 'text/html') {
                $content = RT::Interface::Email::ConvertHTMLToText($content);
            } else {
                # Scrub out <html>, <head>, <meta>, and <body>, and
                # leave all else untouched.
                my $scrubber = HTML::Scrubber->new();
                $scrubber->rules(
                    html => 0,
                    head => 0,
                    meta => 0,
                    body => 0,
                );
                $scrubber->default( 1 => { '*' => 1 } );
                $content = $scrubber->scrub( $content );
            }
        }
        else {
            $content =~ s/\n-- \n.*?$//s if $args{'Quote'};
            if ($args{Type} eq 'text/html') {
                # Extremely simple text->html converter
                $content =~ s/&/&#38;/g;
                $content =~ s/</&lt;/g;
                $content =~ s/>/&gt;/g;
                $content = qq|<pre style="white-space: pre-wrap; font-family: monospace;">$content</pre>|;
            }
        }
    }

    # If all else fails, return a message that we couldn't find any content
    else {
        $content = $self->loc('This transaction appears to have no content');
    }

    if ( $args{'Quote'} ) {
        if ($args{Type} eq 'text/html') {
            $content = '<div class="gmail_quote">'
                . $self->QuoteHeader
                . '<br /><blockquote class="gmail_quote" type="cite">'
                . $content
                . '</blockquote></div>';
        } else {
            $content = $self->ApplyQuoteWrap(content => $content,
                                             cols    => $args{'Wrap'} );

            $content = $self->QuoteHeader . "\n$content";
        }
    }

    return ($content);
}

=head2 QuoteHeader

Returns text prepended to content when transaction is quoted
(see C<Quote> argument in L</Content>). By default returns
localized "On <date> <user name> wrote:\n".

=cut

sub QuoteHeader {
    my $self = shift;
    return $self->loc("On [_1], [_2] wrote:", $self->CreatedAsString, $self->CreatorObj->Name);
}

=head2 ApplyQuoteWrap PARAMHASH

Wrapper to calculate wrap criteria and apply quote wrapping if needed.

=cut

sub ApplyQuoteWrap {
    my $self = shift;
    my %args = @_;
    my $content = $args{content};

    # What's the longest line like?
    my $max = 0;
    foreach ( split ( /\n/, $args{content} ) ) {
        $max = length if length > $max;
    }

    if ( $max > 76 ) {
        require Text::Quoted;
        require Text::Wrapper;

        my $structure = Text::Quoted::extract($args{content});
        $content = $self->QuoteWrap(content_ref => $structure,
                                    cols        => $args{cols},
                                    max         => $max );
    }

    $content =~ s/^/> /gm;  # use regex since string might be multi-line
    return $content;
}

=head2 QuoteWrap PARAMHASH

Wrap the contents of transactions based on Wrap settings, maintaining
the quote character from the original.

=cut

sub QuoteWrap {
    my $self = shift;
    my %args = @_;
    my $ref = $args{content_ref};
    my $final_string;

    if ( ref $ref eq 'ARRAY' ){
        foreach my $array (@$ref){
            $final_string .= $self->QuoteWrap(content_ref => $array,
                                              cols        => $args{cols},
                                              max         => $args{max} );
        }
    }
    elsif ( ref $ref eq 'HASH' ){
        return $ref->{quoter} . "\n" if $ref->{empty}; # Blank line

        my $col = $args{cols} - (length $ref->{quoter});
        my $wrapper = Text::Wrapper->new( columns => $col );

        # Wrap on individual lines to honor incoming line breaks
        # Otherwise deliberate separate lines (like a list or a sig)
        # all get combined incorrectly into single paragraphs.

        my @lines = split /\n/, $ref->{text};
        my $wrap = join '', map { $wrapper->wrap($_) } @lines;
        my $quoter = $ref->{quoter};

        # Only add the space if actually quoting
        $quoter .= ' ' if length $quoter;
        $wrap =~ s/^/$quoter/mg;  # use regex since string might be multi-line

        return $wrap;
    }
    else{
        $RT::Logger->warning("Can't apply quoting with $ref");
        return;
    }
    return $final_string;
}


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



=head2 ContentObj 

Returns the RT::Attachment object which contains the content for this Transaction

=cut


sub ContentObj {
    my $self = shift;
    my %args = ( Type => $PreferredContentType, Attachment => undef, @_ );

    # If we don't have any content, return undef now.
    # Get the set of toplevel attachments to this transaction.

    my $Attachment = $args{'Attachment'};

    $Attachment ||= $self->Attachments->First;

    return undef unless ($Attachment);

    my $Attachments = $self->Attachments;
    while ( my $Attachment = $Attachments->Next ) {
        if ( my $content = _FindPreferredContentObj( %args, Attachment => $Attachment ) ) {
            return $content;
        }
    }

    # If that fails, return the first top-level textual part which has some content.
    # We probably really want this to become "recurse, looking for the other type of
    # displayable".  For now, this maintains backcompat
    my $all_parts = $self->Attachments;
    while ( my $part = $all_parts->Next ) {
        next unless _IsDisplayableTextualContentType($part->ContentType)
        && $part->Content;
        return $part;
    }

    return;
}


sub _FindPreferredContentObj {
    my %args = @_;
    my $Attachment = $args{Attachment};

    # If we don't have any content, return undef now.
    return undef unless $Attachment;

    # If it's a textual part, just return the body.
    if ( _IsDisplayableTextualContentType($Attachment->ContentType) ) {
        return ($Attachment);
    }

    # If it's a multipart object, first try returning the first part with preferred
    # MIME type ('text/plain' by default).

    elsif ( $Attachment->ContentType =~ m|^multipart/mixed|i ) {
        my $kids = $Attachment->Children;
        while (my $child = $kids->Next) {
            my $ret =  _FindPreferredContentObj(%args, Attachment => $child);
            return $ret if ($ret);
        }
    }
    elsif ( $Attachment->ContentType =~ m|^multipart/|i ) {
        if ( $args{Type} ) {
            my $plain_parts = $Attachment->Children;
            $plain_parts->ContentType( VALUE => $args{Type} );
            $plain_parts->LimitNotEmpty;

            # If we actully found a part, return its content
            if ( my $first = $plain_parts->First ) {
                return $first;
            }
        } else {
            my $parts = $Attachment->Children;
            $parts->LimitNotEmpty;

            # If we actully found a part, return its content
            while (my $part = $parts->Next) {
                next unless _IsDisplayableTextualContentType($part->ContentType);
                return $part;
            }

        }
    }

    # If this is a message/rfc822 mail, we need to dig into it in order to find 
    # the actual textual content

    elsif ( $Attachment->ContentType =~ '^message/rfc822' ) {
        my $children = $Attachment->Children;
        while ( my $child = $children->Next ) {
            if ( my $content = _FindPreferredContentObj( %args, Attachment => $child ) ) {
                return $content;
            }
        }
    }

    # We found no content. suck
    return (undef);
}

=head2 _IsDisplayableTextualContentType

We may need to pull this out to another module later, but for now, this
is better than RT::I18N::IsTextualContentType because that believes that
a message/rfc822 email is displayable, despite it having no content

=cut

sub _IsDisplayableTextualContentType {
    my $type = shift;
    ($type =~ m{^text/(?:plain|html)\b}i) ? 1 : 0;
}


=head2 Subject

If this transaction has attached mime objects, returns the first one's subject
Otherwise, returns null
  
=cut

sub Subject {
    my $self = shift;
    return undef unless my $first = $self->Attachments->First;
    return $first->Subject;
}



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
        $self->{'attachments'}->Limit(FIELD => 'id', VALUE => '0', SUBCLAUSE => 'acl');
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



sub ContentAsMIME {
    my $self = shift;

    # RT::Attachments doesn't limit ACLs as strictly as RT::Transaction does
    # since it has less information available without looking to it's parent
    # transaction.  Check ACLs here before we go any further.
    return unless $self->CurrentUserCanSee;

    my $attachments = RT::Attachments->new( $self->CurrentUser );
    $attachments->OrderBy( FIELD => 'id', ORDER => 'ASC' );
    $attachments->Limit( FIELD => 'TransactionId', VALUE => $self->id );
    $attachments->Limit( FIELD => 'Parent',        VALUE => 0 );
    $attachments->RowsPerPage(1);

    my $top = $attachments->First;
    return unless $top;

    my $entity = MIME::Entity->build(
        Type        => 'message/rfc822',
        Description => 'transaction ' . $self->id,
        Data        => $top->ContentAsMIME(Children => 1)->as_string,
    );

    return $entity;
}



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



=head2 BriefDescription

Returns a text string which briefly describes this transaction

=cut

{
    my $scrubber = HTML::Scrubber->new(default => 0); # deny everything

    sub BriefDescription {
        my $self = shift;
        my $desc = $self->BriefDescriptionAsHTML;
           $desc = $scrubber->scrub($desc);
           $desc = HTML::Entities::decode_entities($desc);
        return $desc;
    }
}

=head2 BriefDescriptionAsHTML

Returns an HTML string which briefly describes this transaction.

=cut

sub BriefDescriptionAsHTML {
    my $self = shift;

    unless ( $self->CurrentUserCanSee ) {
        return ( $self->loc("Permission Denied") );
    }

    my ($objecttype, $type, $field) = ($self->ObjectType, $self->Type, $self->Field);

    unless ( defined $type ) {
        return $self->loc("No transaction type specified");
    }

    my ($template, @params);

    my @code = grep { ref eq 'CODE' } map { $_BriefDescriptions{$_} }
        ( $field
            ? ("$objecttype-$type-$field", "$type-$field")
            : () ),
        "$objecttype-$type", $type;

    if (@code) {
        ($template, @params) = $code[0]->($self);
    }

    unless ($template) {
        ($template, @params) = (
            "Default: [_1]/[_2] changed from [_3] to [_4]", #loc
            $type,
            $field,
            (
                $self->OldValue
                ? "'" . $self->OldValue . "'"
                : $self->loc("(no value)")
            ),
            (
                $self->NewValue
                ? "'" . $self->NewValue . "'"
                : $self->loc("(no value)")
            ),
        );
    }
    return $self->loc($template, $self->_ProcessReturnValues(@params));
}

sub _ProcessReturnValues {
    my $self   = shift;
    my @values = @_;
    return map {
        if    (ref eq 'ARRAY')  { $_ = join "", $self->_ProcessReturnValues(@$_) }
        elsif (ref eq 'SCALAR') { $_ = $$_ }
        else                    { RT::Interface::Web::EscapeHTML(\$_) }
        $_
    } @values;
}

sub _FormatPrincipal {
    my $self = shift;
    my $principal = shift;
    if ($principal->IsUser) {
        return $self->_FormatUser( $principal->Object );
    } else {
        return $self->loc("group [_1]", $principal->Object->Name);
    }
}

sub _FormatUser {
    my $self = shift;
    my $user = shift;
    return [
        \'<span class="user" data-replace="user" data-user-id="', $user->id, \'">',
        $user->Format,
        \'</span>'
    ];
}

sub _CanonicalizeRoleName {
    my $self = shift;
    my $role_name = shift;

    if ($role_name =~ /^RT::CustomRole-(\d+)$/) {
        my $role = RT::CustomRole->new($self->CurrentUser);
        $role->Load($1);
        return $role->Name;
    }

    return $self->loc($role_name);
}


%_BriefDescriptions = (
    Create => sub {
        my $self = shift;
        return ( "[_1] created", $self->FriendlyObjectType );   #loc()
    },
    Enabled => sub {
        my $self = shift;
        return ( "[_1] enabled", $self->Field ? $self->loc($self->Field) : $self->FriendlyObjectType );   #loc()
    },
    Disabled => sub {
        my $self = shift;
        return ( "[_1] disabled", $self->Field ? $self->loc($self->Field) : $self->FriendlyObjectType );  #loc()
    },
    Status => sub {
        my $self = shift;
        if ( $self->Field eq 'Status' ) {
            if ( $self->NewValue eq 'deleted' ) {
                return ( "[_1] deleted", $self->FriendlyObjectType );   #loc()
            }
            else {
                my $canon = $self->Object->DOES("RT::Record::Role::Status")
                    ? sub { $self->Object->LifecycleObj->CanonicalCase(@_) }
                    : sub { return $_[0] };
                return (
                    "Status changed from [_1] to [_2]",
                    "'" . $self->loc( $canon->($self->OldValue) ) . "'",
                    "'" . $self->loc( $canon->($self->NewValue) ) . "'"
                );   # loc()
            }
        }

        # Generic:
        my $no_value = $self->loc("(no value)");
        return (
            "[_1] changed from [_2] to [_3]",
            $self->Field,
            ( $self->OldValue ? "'" . $self->OldValue . "'" : $no_value ),
            "'" . $self->NewValue . "'"
        ); #loc()
    },
    SystemError => sub {
        my $self = shift;
        return $self->Data // ("System error"); #loc()
    },
    AttachmentTruncate => sub {
        my $self = shift;
        if ( defined $self->Data ) {
            return ( "File '[_1]' truncated because its size ([_2] bytes) exceeded configured maximum size setting ([_3] bytes).",
                $self->Data, $self->OldValue, $self->NewValue ); #loc()
        }
        else {
            return ( "Content truncated because its size ([_1] bytes) exceeded configured maximum size setting ([_2] bytes).",
                $self->OldValue, $self->NewValue ); #loc()
        }
    },
    AttachmentDrop => sub {
        my $self = shift;
        if ( defined $self->Data ) {
            return ( "File '[_1]' dropped because its size ([_2] bytes) exceeded configured maximum size setting ([_3] bytes).",
                $self->Data, $self->OldValue, $self->NewValue ); #loc()
        }
        else {
            return ( "Content dropped because its size ([_1] bytes) exceeded configured maximum size setting ([_2] bytes).",
                $self->OldValue, $self->NewValue ); #loc()
        }
    },
    AttachmentError => sub {
        my $self = shift;
        if ( defined $self->Data ) {
            return ( "File '[_1]' insert failed. See error log for details.", $self->Data ); #loc()
        }
        else {
            return ( "Content insert failed. See error log for details." ); #loc()
        }
    },
    "Forward Transaction" => sub {
        my $self = shift;
        my $recipients = join ", ", map {
            RT::User->Format( Address => $_, CurrentUser => $self->CurrentUser )
        } RT::EmailParser->ParseEmailAddress($self->Data);

        return ( "Forwarded [_3]Transaction #[_1][_4] to [_2]",
            $self->Field, $recipients,
            [\'<a href="#txn-', $self->Field, \'">'], \'</a>'); #loc()
    },
    "Forward Ticket" => sub {
        my $self = shift;
        my $recipients = join ", ", map {
            RT::User->Format( Address => $_, CurrentUser => $self->CurrentUser )
        } RT::EmailParser->ParseEmailAddress($self->Data);

        return ( "Forwarded Ticket to [_1]", $recipients ); #loc()
    },
    CommentEmailRecord => sub {
        my $self = shift;
        return ("Outgoing email about a comment recorded"); #loc()
    },
    EmailRecord => sub {
        my $self = shift;
        return ("Outgoing email recorded"); #loc()
    },
    Correspond => sub {
        my $self = shift;
        return ("Correspondence added");    #loc()
    },
    Comment => sub {
        my $self = shift;
        return ("Comments added");          #loc()
    },
    CustomField => sub {
        my $self = shift;
        my $field = $self->loc('CustomField');

        my $cf;
        if ( $self->Field ) {
            $cf = RT::CustomField->new( $self->CurrentUser );
            $cf->SetContextObject( $self->Object );
            $cf->Load( $self->Field );
            $field = $cf->Name();
            $field = $self->loc('a custom field') if !defined($field);
        }

        my $new = $self->NewValue;
        my $old = $self->OldValue;

        if ( $cf ) {

            if ( $cf->Type eq 'DateTime' ) {
                if ($old) {
                    my $date = RT::Date->new( $self->CurrentUser );
                    $date->Set( Format => 'ISO', Value => $old );
                    $old = $date->AsString;
                }

                if ($new) {
                    my $date = RT::Date->new( $self->CurrentUser );
                    $date->Set( Format => 'ISO', Value => $new );
                    $new = $date->AsString;
                }
            }
            elsif ( $cf->Type eq 'Date' ) {
                if ($old) {
                    my $date = RT::Date->new( $self->CurrentUser );
                    $date->Set(
                        Format   => 'unknown',
                        Value    => $old,
                        Timezone => 'UTC',
                    );
                    $old = $date->AsString( Time => 0, Timezone => 'UTC' );
                }

                if ($new) {
                    my $date = RT::Date->new( $self->CurrentUser );
                    $date->Set(
                        Format   => 'unknown',
                        Value    => $new,
                        Timezone => 'UTC',
                    );
                    $new = $date->AsString( Time => 0, Timezone => 'UTC' );
                }
            }
        }

        if ( !defined($old) || $old eq '' ) {
            return ("[_1] [_2] added", $field, $new);   #loc()
        }
        elsif ( !defined($new) || $new eq '' ) {
            return ("[_1] [_2] deleted", $field, $old); #loc()
        }
        else {
            return ("[_1] [_2] changed to [_3]", $field, $old, $new);   #loc()
        }
    },
    Untake => sub {
        my $self = shift;
        return ("Untaken"); #loc()
    },
    Take => sub {
        my $self = shift;
        return ("Taken"); #loc()
    },
    Force => sub {
        my $self = shift;
        my $Old = RT::User->new( $self->CurrentUser );
        $Old->Load( $self->OldValue );
        my $New = RT::User->new( $self->CurrentUser );
        $New->Load( $self->NewValue );

        return ("Owner forcibly changed from [_1] to [_2]",
                map { $self->_FormatUser($_) } $Old, $New);  #loc()
    },
    Steal => sub {
        my $self = shift;
        my $Old = RT::User->new( $self->CurrentUser );
        $Old->Load( $self->OldValue );
        return ("Stolen from [_1]", $self->_FormatUser($Old));   #loc()
    },
    Give => sub {
        my $self = shift;
        my $New = RT::User->new( $self->CurrentUser );
        $New->Load( $self->NewValue );
        return ( "Given to [_1]", $self->_FormatUser($New));    #loc()
    },
    AddWatcher => sub {
        my $self = shift;
        my $principal = RT::Principal->new($self->CurrentUser);
        $principal->Load($self->NewValue);
        return ( "[_1] [_2] added", $self->_CanonicalizeRoleName($self->Field), $self->_FormatPrincipal($principal));    #loc()
    },
    DelWatcher => sub {
        my $self = shift;
        my $principal = RT::Principal->new($self->CurrentUser);
        $principal->Load($self->OldValue);
        return ( "[_1] [_2] deleted", $self->_CanonicalizeRoleName($self->Field), $self->_FormatPrincipal($principal));  #loc()
    },
    SetWatcher => sub {
        my $self = shift;
        my $principal = RT::Principal->new($self->CurrentUser);
        $principal->Load($self->NewValue);
        return ( "[_1] set to [_2]", $self->_CanonicalizeRoleName($self->Field), $self->_FormatPrincipal($principal));  #loc()
    },
    Subject => sub {
        my $self = shift;
        return ( "Subject changed to [_1]", $self->Data );  #loc()
    },
    AddLink => sub {
        my $self = shift;
        my $value;
        if ( $self->NewValue ) {
            my $URI = RT::URI->new( $self->CurrentUser );
            if ( $URI->FromURI( $self->NewValue ) ) {
                $value = [
                    \'<a href="', $URI->AsHREF, \'">',
                    $URI->AsString,
                    \'</a>'
                ];
            }
            else {
                $value = $self->NewValue;
            }

            if ( $self->Field eq 'DependsOn' ) {
                return ( "Dependency on [_1] added", $value );  #loc()
            }
            elsif ( $self->Field eq 'DependedOnBy' ) {
                return ( "Dependency by [_1] added", $value );  #loc()
            }
            elsif ( $self->Field eq 'RefersTo' ) {
                return ( "Reference to [_1] added", $value );   #loc()
            }
            elsif ( $self->Field eq 'ReferredToBy' ) {
                return ( "Reference by [_1] added", $value );   #loc()
            }
            elsif ( $self->Field eq 'MemberOf' ) {
                return ( "Membership in [_1] added", $value );  #loc()
            }
            elsif ( $self->Field eq 'HasMember' ) {
                return ( "Member [_1] added", $value );         #loc()
            }
            elsif ( $self->Field eq 'MergedInto' ) {
                return ( "Merged into [_1]", $value );          #loc()
            }
        }
        else {
            return ( "[_1]", $self->Data ); #loc()
        }
    },
    DeleteLink => sub {
        my $self = shift;
        my $value;
        if ( $self->OldValue ) {
            my $URI = RT::URI->new( $self->CurrentUser );
            if ( $URI->FromURI( $self->OldValue ) ) {
                $value = [
                    \'<a href="', $URI->AsHREF, \'">',
                    $URI->AsString,
                    \'</a>'
                ];
            }
            else {
                $value = $self->OldValue;
            }

            if ( $self->Field eq 'DependsOn' ) {
                return ( "Dependency on [_1] deleted", $value );    #loc()
            }
            elsif ( $self->Field eq 'DependedOnBy' ) {
                return ( "Dependency by [_1] deleted", $value );    #loc()
            }
            elsif ( $self->Field eq 'RefersTo' ) {
                return ( "Reference to [_1] deleted", $value );     #loc()
            }
            elsif ( $self->Field eq 'ReferredToBy' ) {
                return ( "Reference by [_1] deleted", $value );     #loc()
            }
            elsif ( $self->Field eq 'MemberOf' ) {
                return ( "Membership in [_1] deleted", $value );    #loc()
            }
            elsif ( $self->Field eq 'HasMember' ) {
                return ( "Member [_1] deleted", $value );           #loc()
            }
        }
        else {
            return ( "[_1]", $self->Data ); #loc()
        }
    },
    Told => sub {
        my $self = shift;
        if ( $self->Field eq 'Told' ) {
            my $t1 = RT::Date->new($self->CurrentUser);
            $t1->Set(Format => 'ISO', Value => $self->NewValue);
            my $t2 = RT::Date->new($self->CurrentUser);
            $t2->Set(Format => 'ISO', Value => $self->OldValue);
            return ( "[_1] changed from [_2] to [_3]", $self->loc($self->Field), $t2->AsString, $t1->AsString );    #loc()
        }
        else {
            return ( "[_1] changed from [_2] to [_3]",
                    $self->loc($self->Field),
                    ($self->OldValue? "'".$self->OldValue ."'" : $self->loc("(no value)")) , "'". $self->NewValue."'" );  #loc()
        }
    },
    Set => sub {
        my $self = shift;
        if ( $self->Field eq 'Password' ) {
            return ('Password changed');    #loc()
        }
        elsif ( $self->Field eq 'Queue' ) {
            my $q1 = RT::Queue->new( $self->CurrentUser );
            $q1->Load( $self->OldValue );
            my $q2 = RT::Queue->new( $self->CurrentUser );
            $q2->Load( $self->NewValue );
            return ("[_1] changed from [_2] to [_3]",
                    $self->loc($self->Field), $q1->Name // '#'.$q1->id, $q2->Name // '#'.$q2->id); #loc()
        }

        # Write the date/time change at local time:
        elsif ($self->Field =~ /^(?:Due|Starts|Started|Told)$/) {
            my $t1 = RT::Date->new($self->CurrentUser);
            $t1->Set(Format => 'ISO', Value => $self->NewValue);
            my $t2 = RT::Date->new($self->CurrentUser);
            $t2->Set(Format => 'ISO', Value => $self->OldValue);
            return ( "[_1] changed from [_2] to [_3]", $self->loc($self->Field), $t2->AsString, $t1->AsString );    #loc()
        }
        elsif ( $self->Field eq 'Owner' ) {
            my $Old = RT::User->new( $self->CurrentUser );
            $Old->Load( $self->OldValue );
            my $New = RT::User->new( $self->CurrentUser );
            $New->Load( $self->NewValue );

            if ( $Old->id == RT->Nobody->id ) {
                if ( $New->id == $self->Creator ) {
                    return ("Taken");   #loc()
                }
                else {
                    return ( "Given to [_1]", $self->_FormatUser($New) );    #loc()
                }
            }
            else {
                if ( $New->id == $self->Creator ) {
                    return ("Stolen from [_1]",  $self->_FormatUser($Old) );   #loc()
                }
                elsif ( $Old->id == $self->Creator ) {
                    if ( $New->id == RT->Nobody->id ) {
                        return ("Untaken"); #loc()
                    }
                    else {
                        return ( "Given to [_1]", $self->_FormatUser($New) ); #loc()
                    }
                }
                else {
                    return (
                        "Owner forcibly changed from [_1] to [_2]",
                        map { $self->_FormatUser($_) } $Old, $New
                    );   #loc()
                }
            }
        }
        else {
            return ( "[_1] changed from [_2] to [_3]",
                    $self->loc($self->Field),
                    ($self->OldValue? "'".$self->OldValue ."'" : $self->loc("(no value)")),
                    ($self->NewValue? "'".$self->NewValue ."'" : $self->loc("(no value)")));  #loc()
        }
    },
    "Set-TimeWorked" => sub {
        my $self = shift;
        my $old  = $self->OldValue || 0;
        my $new  = $self->NewValue || 0;
        my $duration = $new - $old;
        if ($duration < 0) {
            return ("Adjusted time worked by [quant,_1,minute,minutes]", $duration); # loc()
        }
        elsif ($duration < 60) {
            return ("Worked [quant,_1,minute,minutes]", $duration); # loc()
        } else {
            return ("Worked [quant,_1,hour,hours] ([quant,_2,minute,minutes])", sprintf("%.2f", $duration / 60), $duration); # loc()
        }
    },
    PurgeTransaction => sub {
        my $self = shift;
        return ("Transaction [_1] purged", $self->Data);    #loc()
    },
    AddReminder => sub {
        my $self = shift;
        my $ticket = RT::Ticket->new($self->CurrentUser);
        $ticket->Load($self->NewValue);
        if ( $ticket->CurrentUserHasRight('ShowTicket') ) {
            my $subject = [
                \'<a href="', RT->Config->Get('WebPath'),
                "/Ticket/Reminders.html?id=", $self->ObjectId,
                "#reminder-", $ticket->id, \'">', $ticket->Subject, \'</a>'
            ];
            return ("Reminder '[_1]' added", $subject); #loc()
        } else {
            return ("Reminder added"); #loc()
        }
    },
    OpenReminder => sub {
        my $self = shift;
        my $ticket = RT::Ticket->new($self->CurrentUser);
        $ticket->Load($self->NewValue);
        if ( $ticket->CurrentUserHasRight('ShowTicket') ) {
            my $subject = [
                \'<a href="', RT->Config->Get('WebPath'),
                "/Ticket/Reminders.html?id=", $self->ObjectId,
                "#reminder-", $ticket->id, \'">', $ticket->Subject, \'</a>'
            ];
            return ("Reminder '[_1]' reopened", $subject);  #loc()
        } else {
            return ("Reminder reopened");  #loc()
        }
    },
    ResolveReminder => sub {
        my $self = shift;
        my $ticket = RT::Ticket->new($self->CurrentUser);
        $ticket->Load($self->NewValue);
        if ( $ticket->CurrentUserHasRight('ShowTicket') ) {
            my $subject = [
                \'<a href="', RT->Config->Get('WebPath'),
                "/Ticket/Reminders.html?id=", $self->ObjectId,
                "#reminder-", $ticket->id, \'">', $ticket->Subject, \'</a>'
            ];
            return ("Reminder '[_1]' completed", $subject); #loc()
        } else {
            return ("Reminder completed"); #loc()
        }
    },
    'RT::Asset-Set-Catalog' => sub {
        my $self = shift;
        return ("[_1] changed from [_2] to [_3]",   #loc
                $self->loc($self->Field), map {
                    my $c = RT::Catalog->new($self->CurrentUser);
                    $c->Load($_);
                    $c->Name || $self->loc("~[a hidden catalog~]")
                } $self->OldValue, $self->NewValue);
    },
    AddMember => sub {
        my $self = shift;
        my $principal = RT::Principal->new($self->CurrentUser);
        $principal->Load($self->Field);

        if ($principal->IsUser) {
            return ("Added user '[_1]'", $principal->Object->Name); #loc()
        }
        else {
            return ("Added group '[_1]'", $principal->Object->Name); #loc()
        }
    },
    DeleteMember => sub {
        my $self = shift;
        my $principal = RT::Principal->new($self->CurrentUser);
        $principal->Load($self->Field);

        if ($principal->IsUser) {
            return ("Removed user '[_1]'", $principal->Object->Name); #loc()
        }
        else {
            return ("Removed group '[_1]'", $principal->Object->Name); #loc()
        }
    },
    AddMembership => sub {
        my $self = shift;
        my $principal = RT::Principal->new($self->CurrentUser);
        $principal->Load($self->Field);
        return ("Added to group '[_1]'", $principal->Object->Name); #loc()
    },
    DeleteMembership => sub {
        my $self = shift;
        my $principal = RT::Principal->new($self->CurrentUser);
        $principal->Load($self->Field);
        return ("Removed from group '[_1]'", $principal->Object->Name); #loc()
    },
);




=head2 IsInbound

Returns true if the creator of the transaction is a requestor of the ticket.
Returns false otherwise

=cut

sub IsInbound {
    my $self = shift;
    $self->ObjectType eq 'RT::Ticket' or return undef;
    return ( $self->TicketObj->IsRequestor( $self->CreatorObj->PrincipalId ) );
}



sub _OverlayAccessible {
    {

          ObjectType => { public => 1},
          ObjectId => { public => 1},

    }
};




sub _Set {
    my $self = shift;
    return ( 0, $self->loc('Transactions are immutable') );
}



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


=head2 CurrentUserCanSee

Returns true if current user has rights to see this particular transaction.

This fact depends on type of the transaction, type of an object the transaction
is attached to and may be other conditions, so this method is prefered over
custom implementations.

It always returns true if current user is system user.

=cut

sub CurrentUserCanSee {
    my $self = shift;

    return 1 if $self->CurrentUser->PrincipalObj->Id == RT->SystemUser->Id;

    # Make sure the user can see the custom field before showing that it changed
    my $type = $self->__Value('Type');
    if ( $type eq 'CustomField' and my $cf_id = $self->__Value('Field') ) {
        my $cf = RT::CustomField->new( $self->CurrentUser );
        $cf->SetContextObject( $self->Object );
        $cf->Load( $cf_id );
        return 0 unless $cf->CurrentUserCanSee;
    }

    # Transactions that might have changed the ->Object's visibility to
    # the current user are marked readable
    return 1 if $self->{ _object_is_readable };

    # Defer to the object in question
    return $self->Object->CurrentUserCanSee("Transaction", $self);
}


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
    if ( my $Object = $self->OldReferenceObject ) {
        return $Object->Content;
    }
    else {
        return $self->_Value('OldValue');
    }
}

sub NewValue {
    my $self = shift;
    if ( my $Object = $self->NewReferenceObject ) {
        return $Object->Content;
    }
    else {
        return $self->_Value('NewValue');
    }
}

sub Object {
    my $self  = shift;
    my $Object = $self->__Value('ObjectType')->new($self->CurrentUser);
    $Object->Load($self->__Value('ObjectId'));
    return $Object;
}

=head2 NewReferenceObject

=head2 OldReferenceObject

Returns an object of the class specified by the column C<ReferenceType> and
loaded with the id specified by the column C<NewReference> or C<OldReference>.
C<ReferenceType> is assumed to be an L<RT::Record> subclass.

The object may be unloaded (check C<< $object->id >>) if the reference is
corrupt (such as if the referenced record was improperly deleted).

Returns undef if either C<ReferenceType> or C<NewReference>/C<OldReference> is
false.

=cut

sub NewReferenceObject { $_[0]->_ReferenceObject("New") }
sub OldReferenceObject { $_[0]->_ReferenceObject("Old") }

sub _ReferenceObject {
    my $self  = shift;
    my $which = shift;
    my $type  = $self->__Value("ReferenceType");
    my $id    = $self->__Value("${which}Reference");
    return unless $type and $id;

    my $object = $type->new($self->CurrentUser);
    $object->Load( $id );
    return $object;
}

sub FriendlyObjectType {
    my $self = shift;
    return $self->loc( $self->Object->RecordType );
}

=head2 UpdateCustomFields

Takes a hash of:

    CustomField-C<Id> => Value

or:

    Object-RT::Transaction-CustomField-C<Id> => Value

parameters to update this transaction's custom fields.

=cut

sub UpdateCustomFields {
    my $self = shift;
    my %args = @_;

    foreach my $arg ( keys %args ) {
        next
          unless ( $arg =~
            /^(?:Object-RT::Transaction--)?CustomField-(\d+)/ );
        next if $arg =~ /-Magic$/;
        my $cfid   = $1;
        my $values = $args{$arg};
        my $cf = $self->LoadCustomFieldByIdentifier($cfid);
        next unless $cf->ObjectTypeFromLookupType($cf->__Value('LookupType'))->isa(ref $self);
        foreach
          my $value ( UNIVERSAL::isa( $values, 'ARRAY' ) ? @$values : $values )
        {
            next if $self->CustomFieldValueIsEmpty(
                Field => $cf,
                Value => $value,
            );
            $self->_AddCustomFieldValue(
                Field             => $cfid,
                Value             => $value,
                RecordTransaction => 0,
            );
        }
    }

    $self->AddCustomFieldDefaultValues;
}

=head2 LoadCustomFieldByIdentifier

Finds and returns the custom field of the given name for the
transaction, overriding L<RT::Record/LoadCustomFieldByIdentifier> to
look for queue-specific CFs before global ones.

=cut

sub LoadCustomFieldByIdentifier {
    my $self  = shift;
    my $field = shift;

    return $self->SUPER::LoadCustomFieldByIdentifier($field)
        if ref $field or $field =~ /^\d+$/;

    return $self->SUPER::LoadCustomFieldByIdentifier($field)
        unless UNIVERSAL::can( $self->Object, 'QueueObj' );

    my $CFs = RT::CustomFields->new( $self->CurrentUser );
    $CFs->SetContextObject( $self->Object );
    $CFs->Limit( FIELD => 'Name', VALUE => $field, CASESENSITIVE => 0 );
    $CFs->LimitToLookupType($self->CustomFieldLookupType);
    $CFs->LimitToGlobalOrObjectId($self->Object->QueueObj->id);
    return $CFs->First || RT::CustomField->new( $self->CurrentUser );
}

=head2 CustomFieldLookupType

Returns the RT::Transaction lookup type, which can 
be passed to RT::CustomField->Create() via the 'LookupType' hash key.

=cut


sub CustomFieldLookupType {
    "RT::Queue-RT::Ticket-RT::Transaction";
}


=head2 SquelchMailTo

Similar to Ticket class SquelchMailTo method - returns a list of
transaction's squelched addresses.  As transactions are immutable, the
list of squelched recipients cannot be modified after creation.

=cut

sub SquelchMailTo {
    my $self = shift;
    return () unless $self->CurrentUserCanSee;
    return $self->Attributes->Named('SquelchMailTo');
}

=head2 Recipients

Returns the list of email addresses (as L<Email::Address> objects)
that this transaction would send mail to.  There may be duplicates.

=cut

sub Recipients {
    my $self = shift;
    my @recipients;
    foreach my $scrip ( @{ $self->Scrips->Prepared } ) {
        my $action = $scrip->ActionObj->Action;
        next unless $action->isa('RT::Action::SendEmail');

        foreach my $type (qw(To Cc Bcc)) {
            push @recipients, $action->$type();
        }
    }

    if ( $self->Rules ) {
        for my $rule (@{$self->Rules}) {
            next unless $rule->{hints} && $rule->{hints}{class} eq 'SendEmail';
            my $data = $rule->{hints}{recipients};
            foreach my $type (qw(To Cc Bcc)) {
                push @recipients, map {Email::Address->new($_)} @{$data->{$type}};
            }
        }
    }
    return @recipients;
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
     'cache_for_sec'  => 6000,
  }
}


=head2 ACLEquivalenceObjects

This method returns a list of objects for which a user's rights also apply
to this Transaction.

This currently only applies to Transaction Custom Fields on Tickets, so we return
the Ticket's Queue and the Ticket.

This method is called from L<RT::Principal/HasRight>.

=cut

sub ACLEquivalenceObjects {
    my $self = shift;

    return unless $self->ObjectType eq 'RT::Ticket';
    my $object = $self->Object;
    return $object,$object->QueueObj;

}





=head2 id

Returns the current value of id.
(In the database, id is stored as int(11).)


=cut


=head2 ObjectType

Returns the current value of ObjectType.
(In the database, ObjectType is stored as varchar(64).)



=head2 SetObjectType VALUE


Set ObjectType to VALUE.
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, ObjectType will be stored as a varchar(64).)


=cut


=head2 ObjectId

Returns the current value of ObjectId.
(In the database, ObjectId is stored as int(11).)



=head2 SetObjectId VALUE


Set ObjectId to VALUE.
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, ObjectId will be stored as a int(11).)


=cut


=head2 TimeTaken

Returns the current value of TimeTaken.
(In the database, TimeTaken is stored as int(11).)



=head2 SetTimeTaken VALUE


Set TimeTaken to VALUE.
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, TimeTaken will be stored as a int(11).)


=cut


=head2 Type

Returns the current value of Type.
(In the database, Type is stored as varchar(20).)



=head2 SetType VALUE


Set Type to VALUE.
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, Type will be stored as a varchar(20).)


=cut


=head2 Field

Returns the current value of Field.
(In the database, Field is stored as varchar(40).)



=head2 SetField VALUE


Set Field to VALUE.
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, Field will be stored as a varchar(40).)


=cut


=head2 OldValue

Returns the current value of OldValue.
(In the database, OldValue is stored as varchar(255).)



=head2 SetOldValue VALUE


Set OldValue to VALUE.
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, OldValue will be stored as a varchar(255).)


=cut


=head2 NewValue

Returns the current value of NewValue.
(In the database, NewValue is stored as varchar(255).)



=head2 SetNewValue VALUE


Set NewValue to VALUE.
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, NewValue will be stored as a varchar(255).)


=cut


=head2 ReferenceType

Returns the current value of ReferenceType.
(In the database, ReferenceType is stored as varchar(255).)



=head2 SetReferenceType VALUE


Set ReferenceType to VALUE.
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, ReferenceType will be stored as a varchar(255).)


=cut


=head2 OldReference

Returns the current value of OldReference.
(In the database, OldReference is stored as int(11).)



=head2 SetOldReference VALUE


Set OldReference to VALUE.
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, OldReference will be stored as a int(11).)


=cut


=head2 NewReference

Returns the current value of NewReference.
(In the database, NewReference is stored as int(11).)



=head2 SetNewReference VALUE


Set NewReference to VALUE.
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, NewReference will be stored as a int(11).)


=cut


=head2 Data

Returns the current value of Data.
(In the database, Data is stored as varchar(255).)



=head2 SetData VALUE


Set Data to VALUE.
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



sub _CoreAccessible {
    {

        id =>
                {read => 1, sql_type => 4, length => 11,  is_blob => 0,  is_numeric => 1,  type => 'int(11)', default => ''},
        ObjectType =>
                {read => 1, write => 1, sql_type => 12, length => 64,  is_blob => 0,  is_numeric => 0,  type => 'varchar(64)', default => ''},
        ObjectId =>
                {read => 1, write => 1, sql_type => 4, length => 11,  is_blob => 0,  is_numeric => 1,  type => 'int(11)', default => '0'},
        TimeTaken =>
                {read => 1, write => 1, sql_type => 4, length => 11,  is_blob => 0,  is_numeric => 1,  type => 'int(11)', default => '0'},
        Type =>
                {read => 1, write => 1, sql_type => 12, length => 20,  is_blob => 0,  is_numeric => 0,  type => 'varchar(20)', default => ''},
        Field =>
                {read => 1, write => 1, sql_type => 12, length => 40,  is_blob => 0,  is_numeric => 0,  type => 'varchar(40)', default => ''},
        OldValue =>
                {read => 1, write => 1, sql_type => 12, length => 255,  is_blob => 0,  is_numeric => 0,  type => 'varchar(255)', default => ''},
        NewValue =>
                {read => 1, write => 1, sql_type => 12, length => 255,  is_blob => 0,  is_numeric => 0,  type => 'varchar(255)', default => ''},
        ReferenceType =>
                {read => 1, write => 1, sql_type => 12, length => 255,  is_blob => 0,  is_numeric => 0,  type => 'varchar(255)', default => ''},
        OldReference =>
                {read => 1, write => 1, sql_type => 4, length => 11,  is_blob => 0,  is_numeric => 1,  type => 'int(11)', default => ''},
        NewReference =>
                {read => 1, write => 1, sql_type => 4, length => 11,  is_blob => 0,  is_numeric => 1,  type => 'int(11)', default => ''},
        Data =>
                {read => 1, write => 1, sql_type => 12, length => 255,  is_blob => 0,  is_numeric => 0,  type => 'varchar(255)', default => ''},
        Creator =>
                {read => 1, auto => 1, sql_type => 4, length => 11,  is_blob => 0,  is_numeric => 1,  type => 'int(11)', default => '0'},
        Created =>
                {read => 1, auto => 1, sql_type => 11, length => 0,  is_blob => 0,  is_numeric => 0,  type => 'datetime', default => ''},

 }
};

sub FindDependencies {
    my $self = shift;
    my ($walker, $deps) = @_;

    $self->SUPER::FindDependencies($walker, $deps);

    $deps->Add( out => $self->Object );
    $deps->Add( in => $self->Attachments );

    my $type = $self->Type;
    if ($type eq "CustomField") {
        my $cf = RT::CustomField->new( RT->SystemUser );
        $cf->Load( $self->Field );
        $deps->Add( out => $cf );
    } elsif ($type =~ /^(Take|Untake|Force|Steal|Give)$/) {
        for my $field (qw/OldValue NewValue/) {
            my $user = RT::User->new( RT->SystemUser );
            $user->Load( $self->$field );
            $deps->Add( out => $user );
        }
    } elsif ($type eq "DelWatcher") {
        my $principal = RT::Principal->new( RT->SystemUser );
        $principal->Load( $self->OldValue );
        $deps->Add( out => $principal->Object );
    } elsif ($type eq "AddWatcher") {
        my $principal = RT::Principal->new( RT->SystemUser );
        $principal->Load( $self->NewValue );
        $deps->Add( out => $principal->Object );
    } elsif ($type eq "DeleteLink") {
        if ($self->OldValue) {
            my $base = RT::URI->new( $self->CurrentUser );
            $base->FromURI( $self->OldValue );
            $deps->Add( out => $base->Object ) if $base->Resolver and $base->Object;
        }
    } elsif ($type eq "AddLink") {
        if ($self->NewValue) {
            my $base = RT::URI->new( $self->CurrentUser );
            $base->FromURI( $self->NewValue );
            $deps->Add( out => $base->Object ) if $base->Resolver and $base->Object;
        }
    } elsif ($type eq "Set" and $self->Field eq "Queue") {
        for my $field (qw/OldValue NewValue/) {
            my $queue = RT::Queue->new( RT->SystemUser );
            $queue->Load( $self->$field );
            $deps->Add( out => $queue );
        }
    } elsif ($type =~ /^(Add|Open|Resolve)Reminder$/) {
        my $ticket = RT::Ticket->new( RT->SystemUser );
        $ticket->Load( $self->NewValue );
        $deps->Add( out => $ticket );
    }
}

sub __DependsOn {
    my $self = shift;
    my %args = (
        Shredder => undef,
        Dependencies => undef,
        @_,
    );
    my $deps = $args{'Dependencies'};

    $deps->_PushDependencies(
        BaseObject => $self,
        Flags => RT::Shredder::Constants::DEPENDS_ON,
        TargetObjects => $self->Attachments,
        Shredder => $args{'Shredder'}
    );

    return $self->SUPER::__DependsOn( %args );
}

sub Serialize {
    my $self = shift;
    my %args = (@_);
    my %store = $self->SUPER::Serialize(@_);

    my $type = $store{Type};
    if ($type eq "CustomField") {
        my $cf = RT::CustomField->new( RT->SystemUser );
        $cf->Load( $store{Field} );
        $store{Field} = \($cf->UID);

        $store{OldReference} = \($self->OldReferenceObject->UID) if $self->OldReference;
        $store{NewReference} = \($self->NewReferenceObject->UID) if $self->NewReference;
    } elsif ($type =~ /^(Take|Untake|Force|Steal|Give)$/) {
        for my $field (qw/OldValue NewValue/) {
            my $user = RT::User->new( RT->SystemUser );
            $user->Load( $store{$field} );
            $store{$field} = \($user->UID);
        }
    } elsif ($type eq "DelWatcher") {
        my $principal = RT::Principal->new( RT->SystemUser );
        $principal->Load( $store{OldValue} );
        $store{OldValue} = \($principal->UID);
    } elsif ($type eq "AddWatcher") {
        my $principal = RT::Principal->new( RT->SystemUser );
        $principal->Load( $store{NewValue} );
        $store{NewValue} = \($principal->UID);
    } elsif ($type eq "DeleteLink") {
        if ($store{OldValue}) {
            my $base = RT::URI->new( $self->CurrentUser );
            $base->FromURI( $store{OldValue} );
            if ($base->Resolver && (my $object = $base->Object)) {
                if ($args{serializer}->Observe(object => $object)) {
                    $store{OldValue} = \($object->UID);
                }
                elsif ($args{serializer}{HyperlinkUnmigrated}) {
                    $store{OldValue} = $base->AsHREF;
                }
                else {
                    $store{OldValue} = "(not migrated)";
                }
            }
        }
    } elsif ($type eq "AddLink") {
        if ($store{NewValue}) {
            my $base = RT::URI->new( $self->CurrentUser );
            $base->FromURI( $store{NewValue} );
            if ($base->Resolver && (my $object = $base->Object)) {
                if ($args{serializer}->Observe(object => $object)) {
                    $store{NewValue} = \($object->UID);
                }
                elsif ($args{serializer}{HyperlinkUnmigrated}) {
                    $store{NewValue} = $base->AsHREF;
                }
                else {
                    $store{NewValue} = "(not migrated)";
                }
            }
        }
    } elsif ($type eq "Set" and $store{Field} eq "Queue") {
        for my $field (qw/OldValue NewValue/) {
            my $queue = RT::Queue->new( RT->SystemUser );
            $queue->Load( $store{$field} );
            if ($args{serializer}->Observe(object => $queue)) {
                $store{$field} = \($queue->UID);
            }
            else {
                $store{$field} = "$RT::Organization: " . $queue->Name . " (not migrated)";

            }
        }
    } elsif ($type =~ /^(Add|Open|Resolve)Reminder$/) {
        my $ticket = RT::Ticket->new( RT->SystemUser );
        $ticket->Load( $store{NewValue} );
        $store{NewValue} = \($ticket->UID);
    }

    return %store;
}

sub PreInflate {
    my $class = shift;
    my ($importer, $uid, $data) = @_;

    if ($data->{Object} and ref $data->{Object}) {
        my $on_uid = ${ $data->{Object} };
        return if $importer->ShouldSkipTransaction($on_uid);
    }

    if ($data->{Type} eq "DeleteLink" and ref $data->{OldValue}) {
        my $uid = ${ $data->{OldValue} };
        my $obj = $importer->LookupObj( $uid );
        $data->{OldValue} = $obj->URI;
    } elsif ($data->{Type} eq "AddLink" and ref $data->{NewValue}) {
        my $uid = ${ $data->{NewValue} };
        my $obj = $importer->LookupObj( $uid );
        $data->{NewValue} = $obj->URI;
    }

    return $class->SUPER::PreInflate( $importer, $uid, $data );
}

RT::Base->_ImportOverlays();

1;
