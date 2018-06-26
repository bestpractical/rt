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

=head1 SYNOPSIS

    use RT::Attachment;

=head1 DESCRIPTION

This module should never be instantiated directly by client code. it's an internal 
module which should only be instantiated through exported APIs in Ticket, Queue and other 
similar objects.

=head1 METHODS



=cut


package RT::Attachment;
use base 'RT::Record';

sub Table {'Attachments'}




use strict;
use warnings;


use RT::Transaction;
use MIME::Base64;
use MIME::QuotedPrint;
use MIME::Body;
use RT::Util 'mime_recommended_filename';
use URI;

sub _OverlayAccessible {
  {
    TransactionId   => { 'read'=>1, 'public'=>1, 'write' => 0 },
    MessageId       => { 'read'=>1, 'write' => 0 },
    Parent          => { 'read'=>1, 'write' => 0 },
    ContentType     => { 'read'=>1, 'write' => 0 },
    Subject         => { 'read'=>1, 'write' => 0 },
    Content         => { 'read'=>1, 'write' => 0 },
    ContentEncoding => { 'read'=>1, 'write' => 0 },
    Headers         => { 'read'=>1, 'write' => 0 },
    Filename        => { 'read'=>1, 'write' => 0 },
    Creator         => { 'read'=>1, 'auto'=>1, },
    Created         => { 'read'=>1, 'auto'=>1, },
  };
}

=head2 Create

Create a new attachment. Takes a paramhash:
    
    'Attachment' Should be a single MIME body with optional subparts
    'Parent' is an optional id of the parent attachment
    'TransactionId' is the mandatory id of the transaction this attachment is associated with.;

=cut

sub Create {
    my $self = shift;
    my %args = ( id            => 0,
                 TransactionId => 0,
                 Parent        => 0,
                 Attachment    => undef,
                 @_ );

    # For ease of reference
    my $Attachment = $args{'Attachment'};

    # if we didn't specify a ticket, we need to bail
    unless ( $args{'TransactionId'} ) {
        $RT::Logger->crit( "RT::Attachment->Create couldn't, as you didn't specify a transaction" );
        return (0);
    }

    # If we possibly can, collapse it to a singlepart
    $Attachment->make_singlepart;

    my $head = $Attachment->head;

    # Get the subject
    my $Subject = Encode::decode( 'UTF-8', $head->get( 'subject' ) );
    $Subject = '' unless defined $Subject;
    chomp $Subject;

    #Get the Message-ID
    my $MessageId = Encode::decode( "UTF-8", $head->get( 'Message-ID' ) );
    defined($MessageId) or $MessageId = '';
    chomp ($MessageId);
    $MessageId =~ s/^<(.*?)>$/$1/o;

    #Get the filename
    my $Filename = mime_recommended_filename($Attachment);

    # remove path part. 
    $Filename =~ s!.*/!! if $Filename;

    my $content;
    unless ( $head->get('Content-Length') ) {
        my $length = 0;
        $length = length $Attachment->bodyhandle->as_string
            if defined $Attachment->bodyhandle;
        $head->replace( 'Content-Length' => Encode::encode( "UTF-8", $length ) );
    }
    $head = $head->as_string;

    # MIME::Head doesn't support perl strings well and can return
    # octets which later will be double encoded in low-level code
    $head = Encode::decode( 'UTF-8', $head );

    # If a message has no bodyhandle, that means that it has subparts (or appears to)
    # and we should act accordingly.  
    unless ( defined $Attachment->bodyhandle ) {
        my ($id) = $self->SUPER::Create(
            TransactionId => $args{'TransactionId'},
            Parent        => $args{'Parent'},
            ContentType   => $Attachment->mime_type,
            Headers       => $head,
            MessageId     => $MessageId,
            Subject       => $Subject,
        );

        unless ($id) {
            $RT::Logger->crit("Attachment insert failed - ". $RT::Handle->dbh->errstr);
            my $txn = RT::Transaction->new($self->CurrentUser);
            $txn->Load($args{'TransactionId'});
            if ( $txn->id ) {
                $txn->Object->_NewTransaction( Type => 'AttachmentError', ActivateScrips => 0, Data => $Filename );
            }
            return ($id);
        }

        foreach my $part ( $Attachment->parts ) {
            my $SubAttachment = RT::Attachment->new( $self->CurrentUser );
            my ($id) = $SubAttachment->Create(
                TransactionId => $args{'TransactionId'},
                Parent        => $id,
                Attachment    => $part,
            );
            unless ($id) {
                $RT::Logger->crit("Attachment insert failed: ". $RT::Handle->dbh->errstr);
                return ($id);
            }
        }
        return ($id);
    }

    #If it's not multipart
    else {

        my ( $encoding, $type, $note_args );
        ( $encoding, $content, $type, $Filename, $note_args ) =
                $self->_EncodeLOB( $Attachment->bodyhandle->as_string, $Attachment->mime_type, $Filename, );

        my $id = $self->SUPER::Create(
            TransactionId   => $args{'TransactionId'},
            ContentType     => $type,
            ContentEncoding => $encoding,
            Parent          => $args{'Parent'},
            Headers         => $head,
            Subject         => $Subject,
            Content         => $content,
            Filename        => $Filename,
            MessageId       => $MessageId,
        );

        if ($id) {
            if ($note_args) {
                $self->TransactionObj->Object->_NewTransaction( %$note_args );
            }
        }
        else {
            $RT::Logger->crit("Attachment insert failed: ". $RT::Handle->dbh->errstr);
            my $txn = RT::Transaction->new($self->CurrentUser);
            $txn->Load($args{'TransactionId'});
            if ( $txn->id ) {
                $txn->Object->_NewTransaction( Type => 'AttachmentError', ActivateScrips => 0, Data => $Filename );
            }
        }
        return $id;
    }
}

=head2 TransactionObj

Returns the transaction object asscoiated with this attachment.

=cut

sub TransactionObj {
    my $self = shift;

    unless ( $self->{_TransactionObj} ) {
        $self->{_TransactionObj} = RT::Transaction->new( $self->CurrentUser );
        $self->{_TransactionObj}->Load( $self->TransactionId );
    }

    unless ($self->{_TransactionObj}->Id) {
        $RT::Logger->crit(  "Attachment ". $self->id
                           ." can't find transaction ". $self->TransactionId
                           ." which it is ostensibly part of. That's bad");
    }
    return $self->{_TransactionObj};
}

=head2 ParentObj

Returns a parent's L<RT::Attachment> object if this attachment
has a parent, otherwise returns undef.

=cut

sub ParentObj {
    my $self = shift;
    return undef unless $self->Parent;

    my $parent = RT::Attachment->new( $self->CurrentUser );
    $parent->LoadById( $self->Parent );
    return $parent;
}

=head2 Closest

Takes a MIME type as a string or regex.  Returns an L<RT::Attachment> object
for the nearest containing part with a matching L</ContentType>.  Strings must
match exactly and all matches are done case insensitively.  Strings ending in a
C</> must only match the first part of the MIME type.  For example:

    # Find the nearest multipart/* container
    my $container = $attachment->Closest("multipart/");

Returns undef if no such object is found.

=cut

sub Closest {
    my $self = shift;
    my $type = shift;
    my $part = $self->ParentObj or return undef;

    $type = qr/^\Q$type\E$/
        unless ref $type eq "REGEX";

    while (lc($part->ContentType) !~ $type) {
        $part = $part->ParentObj or last;
    }

    return ($part and $part->id) ? $part : undef;
}

=head2 Children

Returns an L<RT::Attachments> object which is preloaded with
all attachments objects with this attachment's Id as their
C<Parent>.

=cut

sub Children {
    my $self = shift;
    
    my $kids = RT::Attachments->new( $self->CurrentUser );
    $kids->ChildrenOf( $self->Id );
    return($kids);
}

=head2 Siblings

Returns an L<RT::Attachments> object containing all the attachments sharing
the same immediate parent as the current object, excluding the current
attachment itself.

If the current attachment is a top-level part (i.e. Parent == 0) then a
guaranteed empty L<RT::Attachments> object is returned.

=cut

sub Siblings {
    my $self = shift;
    my $siblings = RT::Attachments->new( $self->CurrentUser );
    if ($self->Parent) {
        $siblings->ChildrenOf( $self->Parent );
        $siblings->Limit( FIELD => 'id', OPERATOR => '!=', VALUE => $self->Id );
    } else {
        # Ensure emptiness
        $siblings->Limit( SUBCLAUSE => 'empty', FIELD => 'id', VALUE => 0 );
    }
    return $siblings;
}

=head2 Content

Returns the attachment's content. if it's base64 encoded, decode it 
before returning it.

=cut

sub Content {
    my $self = shift;
    return $self->_DecodeLOB(
        $self->GetHeader('Content-Type'),  # Includes charset, unlike ->ContentType
        $self->ContentEncoding,
        $self->_Value('Content', decode_utf8 => 0),
    );
}

=head2 OriginalContent

Returns the attachment's content as octets before RT's mangling.
Generally this just means restoring text content back to its
original encoding.

If the attachment has a C<message/*> Content-Type, its children attachments
are reconstructed and returned as a string.

=cut

sub OriginalContent {
    my $self = shift;

    # message/* content types represent raw messages.  Since we break them
    # apart when they come in, we'll reconstruct their child attachments when
    # you ask for the OriginalContent of the message/ part.
    if ($self->IsMessageContentType) {
        # There shouldn't be more than one "subpart" to a message/* attachment
        my $child = $self->Children->First;
        return $self->Content unless $child and $child->id;
        return $child->ContentAsMIME(Children => 1)->as_string;
    }

    return $self->Content unless RT::I18N::IsTextualContentType($self->ContentType);

    my $content = $self->_DecodeLOB(
        "application/octet-stream", # Force _DecodeLOB to not decode to characters
        $self->ContentEncoding,
        $self->_Value('Content', decode_utf8 => 0),
    );

    my $entity = MIME::Entity->new();
    $entity->head->add("Content-Type", $self->GetHeader("Content-Type"));
    $entity->bodyhandle( MIME::Body::Scalar->new( $content ) );
    my $from = RT::I18N::_FindOrGuessCharset($entity);
    $from = 'utf-8' if not $from or not Encode::find_encoding($from);

    my $to = RT::I18N::_CanonicalizeCharset(
        $self->OriginalEncoding || 'utf-8'
    );

    local $@;
    eval { Encode::from_to($content, $from => $to) };
    if ($@) {
        $RT::Logger->error("Could not convert attachment from $from to $to: ".$@);
    }
    return $content;
}

=head2 OriginalEncoding

Returns the attachment's original encoding.

=cut

sub OriginalEncoding {
    my $self = shift;
    return $self->GetHeader('X-RT-Original-Encoding');
}

=head2 ContentLength

Returns length of L</Content> in bytes.

=cut

sub ContentLength {
    my $self = shift;

    return undef unless $self->TransactionObj->CurrentUserCanSee;

    my $len = $self->GetHeader('Content-Length');
    unless ( defined $len ) {
        use bytes;
        no warnings 'uninitialized';
        $len = length($self->Content) || 0;
        $self->SetHeader('Content-Length' => $len);
    }
    return $len;
}

=head2 FriendlyContentLength

Returns L</ContentLength> in bytes, kilobytes, or megabytes as most
appropriate.  The size is suffixed with C<MiB>, C<KiB>, or C<B> and the returned
string is localized.

Returns the empty string if the L</ContentLength> is 0 or undefined.

=cut

sub FriendlyContentLength {
    my $self = shift;
    my $size = $self->ContentLength;
    return '' unless $size;

    my $res = '';
    if ( $size > 1024*1024 ) {
        $res = $self->loc( "[_1]MiB", int( $size / 1024 / 102.4 ) / 10 );
    }
    elsif ( $size > 1024 ) {
        $res = $self->loc( "[_1]KiB", int( $size / 102.4 ) / 10 );
    }
    else {
        $res = $self->loc( "[_1]B", $size );
    }
    return $res;
}

=head2 ContentAsMIME [Children => 1]

Returns MIME entity built from this attachment.

If the optional parameter C<Children> is set to a true value, the children are
recursively added to the entity.

=cut

sub _EncodeHeaderToMIME {
    my ( $self, $header_name, $header_val ) = @_;
    if ($header_name =~ /^Content-/i) {
        my $params = MIME::Field::ParamVal->parse_params($header_val);
        $header_val = delete $params->{'_'};
        foreach my $key ( sort keys %$params ) {
            my $value = $params->{$key};
            if ( $value =~ /[^\x00-\x7f]/ ) { # check for non-ASCII
                $value = q{UTF-8''} . URI->new(
                    Encode::encode('UTF-8', $value)
                );
                $value =~ s/(["\\])/\\$1/g;
                $header_val .= qq{; ${key}*="$value"};
            }
            else {
                $header_val .= qq{; $key="$value"};
            }
        }
    }
    elsif ( $header_name =~ /^(?:Resent-)?(?:To|From|B?Cc|Sender|Reply-To)$/i ) {
        my @addresses = RT::EmailParser->ParseEmailAddress( $header_val );
        foreach my $address ( @addresses ) {
            foreach my $field (qw(phrase comment)) {
                my $v = $address->$field() or next;
                $v = RT::Interface::Email::EncodeToMIME( String => $v );
                $address->$field($v);
            }
        }
        $header_val = join ', ', map $_->format, @addresses;
    }
    else {
        $header_val = RT::Interface::Email::EncodeToMIME(
            String => $header_val
        );
    }
    return $header_val;
}

sub ContentAsMIME {
    my $self = shift;
    my %opts = (
        Children => 0,
        @_
    );

    my $entity = MIME::Entity->new();
    foreach my $header ($self->SplitHeaders) {
        my ($h_key, $h_val) = split /:/, $header, 2;
        $entity->head->add(
            $h_key, $self->_EncodeHeaderToMIME($h_key, $h_val)
        );
    }

    if ($entity->is_multipart) {
        if ($opts{'Children'} and not $self->IsMessageContentType) {
            my $children = $self->Children;
            while (my $child = $children->Next) {
                $entity->add_part( $child->ContentAsMIME(%opts) );
            }
        }
    } else {
        # since we want to return original content, let's use original encoding
        $entity->head->mime_attr(
            "Content-Type.charset" => $self->OriginalEncoding )
          if $self->OriginalEncoding;

        $entity->bodyhandle(
            MIME::Body::Scalar->new( $self->OriginalContent )
        );
    }

    return $entity;
}

=head2 IsMessageContentType

Returns a boolean indicating if the Content-Type of this attachment is a
C<message/> subtype.

=cut

sub IsMessageContentType {
    my $self = shift;
    return $self->ContentType =~ m{^\s*message/}i ? 1 : 0;
}

=head2 Addresses

Returns a hashref of all addresses related to this attachment.
The keys of the hash are C<From>, C<To>, C<Cc>, C<Bcc>, C<RT-Send-Cc>
and C<RT-Send-Bcc>. The values are references to lists of
L<Email::Address> objects.

=cut

our @ADDRESS_HEADERS = qw(From To Cc Bcc RT-Send-Cc RT-Send-Bcc);

sub Addresses {
    my $self = shift;

    my %data = ();
    my $current_user_address = lc($self->CurrentUser->EmailAddress || '');
    foreach my $hdr (@ADDRESS_HEADERS) {
        my @Addresses;
        my $line = $self->GetHeader($hdr);
        
        foreach my $AddrObj ( Email::Address->parse( $line )) {
            my $address = $AddrObj->address;
            $address = lc RT::User->CanonicalizeEmailAddress($address);
            next if $current_user_address eq $address;
            next if RT::EmailParser->IsRTAddress($address);
            push @Addresses, $AddrObj ;
        }
        $data{$hdr} = \@Addresses;
    }
    return \%data;
}

=head2 NiceHeaders

Returns a multi-line string of the To, From, Cc, Date and Subject headers.

=cut

sub NiceHeaders {
    my $self = shift;
    my $hdrs = "";
    my @hdrs = $self->_SplitHeaders;
    while (my $str = shift @hdrs) {
        next unless $str =~ /^(To|From|RT-Send-Cc|Cc|Bcc|Date|Subject):/i;
        $hdrs .= $str . "\n";
        $hdrs .= shift( @hdrs ) . "\n" while ($hdrs[0] =~ /^[ \t]+/);
    }
    return $hdrs;
}

=head2 Headers

Returns this object's headers as a string.  This method specifically
removes the RT-Send-Bcc: header, so as to never reveal to whom RT sent a Bcc.
We need to record the RT-Send-Cc and RT-Send-Bcc values so that we can actually send
out mail. The mailing rules are separated from the ticket update code by
an abstraction barrier that makes it impossible to pass this data directly.

=cut

sub Headers {
    return join("\n", $_[0]->SplitHeaders);
}

=head2 EncodedHeaders

Takes encoding as argument and returns the attachment's headers as octets in encoded
using the encoding.

This is not protection using quoted printable or base64 encoding.

=cut

sub EncodedHeaders {
    my $self = shift;
    my $encoding = shift || 'utf8';
    return Encode::encode( $encoding, $self->Headers );
}

=head2 GetHeader $TAG

Returns the value of the B<first> header Tag as a string. This bypasses the
weeding out done in Headers() above.

=cut

sub GetHeader {
    my $self = shift;
    my $tag = shift;
    foreach my $line ($self->_SplitHeaders) {
        next unless $line =~ /^\Q$tag\E:\s+(.*)$/si;

        #if we find the header, return its value
        return ($1);
    }
    
    # we found no header. return an empty string
    return undef;
}

=head2 GetAllHeaders $TAG

Returns a list of all values for the the given header tag, in the order they
appear.

=cut

sub GetAllHeaders {
    my $self = shift;
    my $tag = shift;
    my @values = ();
    foreach my $line ($self->_SplitHeaders) {
        next unless $line =~ /^\Q$tag\E:\s+(.*)$/si;
        push @values, $1;
    }
    return @values;
}

=head2 DelHeader $TAG

Delete a field from the attachment's headers.

=cut

sub DelHeader {
    my $self = shift;
    my $tag = shift;

    my $newheader = '';
    foreach my $line ($self->_SplitHeaders) {
        next if $line =~ /^\Q$tag\E:\s+/i;
        $newheader .= "$line\n";
    }
    return $self->__Set( Field => 'Headers', Value => $newheader);
}

=head2 AddHeader $TAG, $VALUE, ...

Add one or many fields to the attachment's headers.

=cut

sub AddHeader {
    my $self = shift;

    my $newheader = $self->__Value( 'Headers' );
    while ( my ($tag, $value) = splice @_, 0, 2 ) {
        $value = $self->_CanonicalizeHeaderValue($value);
        $newheader .= "$tag: $value\n";
    }
    return $self->__Set( Field => 'Headers', Value => $newheader);
}

=head2 SetHeader ( 'Tag', 'Value' )

Replace or add a Header to the attachment's headers.

=cut

sub SetHeader {
    my $self  = shift;
    my $tag   = shift;
    my $value = $self->_CanonicalizeHeaderValue(shift);

    my $replaced  = 0;
    my $newheader = '';
    foreach my $line ( $self->_SplitHeaders ) {
        if ( $line =~ /^\Q$tag\E:\s+/i ) {
            # replace first instance, skip all the rest
            unless ($replaced) {
                $newheader .= "$tag: $value\n";
                $replaced = 1;
            }
        } else {
            $newheader .= "$line\n";
        }
    }

    $newheader .= "$tag: $value\n" unless $replaced;
    $self->__Set( Field => 'Headers', Value => $newheader);
}

sub _CanonicalizeHeaderValue {
    my $self  = shift;
    my $value = shift;

    $value = '' unless defined $value;
    $value =~ s/\s+$//s;
    $value =~ s/\r*\n/\n /g;

    return $value;
}

=head2 SplitHeaders

Returns an array of this attachment object's headers, with one header 
per array entry. Multiple lines are folded.

B<Never> returns C<RT-Send-Bcc> field.

=cut

sub SplitHeaders {
    my $self = shift;
    return (grep !/^RT-Send-Bcc/i, $self->_SplitHeaders(@_) );
}

=head2 _SplitHeaders

Returns an array of this attachment object's headers, with one header 
per array entry. multiple lines are folded.


=cut

sub _SplitHeaders {
    my $self = shift;
    my $headers = (shift || $self->_Value('Headers'));
    my @headers;
    # XXX TODO: splitting on \n\w is _wrong_ as it treats \n[ as a valid
    # continuation, which it isn't.  The correct split pattern, per RFC 2822,
    # is /\n(?=[^ \t]|\z)/.  That is, only "\n " or "\n\t" is a valid
    # continuation.  Older values of X-RT-GnuPG-Status contain invalid
    # continuations and rely on this bogus split pattern, however, so it is
    # left as-is for now.
    for (split(/\n(?=\w|\z)/,$headers)) {
        push @headers, $_;

    }
    return(@headers);
}


sub Encrypt {
    my $self = shift;

    my $txn = $self->TransactionObj;
    return (0, $self->loc('Permission Denied')) unless $txn->CurrentUserCanSee;
    return (0, $self->loc('Permission Denied'))
        unless $txn->TicketObj->CurrentUserHasRight('ModifyTicket');
    return (0, $self->loc('Cryptography is disabled'))
        unless RT->Config->Get('Crypt')->{'Enable'};
    return (0, $self->loc('Attachments encryption is disabled'))
        unless RT->Config->Get('Crypt')->{'AllowEncryptDataInDB'};

    my $type = $self->ContentType;
    if ( $type =~ /^x-application-rt\/[^-]+-encrypted/i ) {
        return (1, $self->loc('Already encrypted'));
    } elsif ( $type =~ /^multipart\//i ) {
        return (1, $self->loc('No need to encrypt'));
    }

    my $queue = $txn->TicketObj->QueueObj;
    my $encrypt_for;
    foreach my $address ( grep $_,
        $queue->CorrespondAddress,
        $queue->CommentAddress,
        RT->Config->Get('CorrespondAddress'),
        RT->Config->Get('CommentAddress'),
    ) {
        my %res = RT::Crypt->GetKeysInfo( Key => $address, Type => 'private' );
        next if $res{'exit_code'} || !$res{'info'};
        %res = RT::Crypt->GetKeysForEncryption( $address );
        next if $res{'exit_code'} || !$res{'info'};
        $encrypt_for = $address;
    }
    unless ( $encrypt_for ) {
        return (0, $self->loc('No key suitable for encryption'));
    }

    my $content = $self->Content;
    my %res = RT::Crypt->SignEncryptContent(
        Content => \$content,
        Sign => 0,
        Encrypt => 1,
        Recipients => [ $encrypt_for ],
    );
    if ( $res{'exit_code'} ) {
        return (0, $self->loc('Encryption error; contact the administrator'));
    }

    my ($status, $msg) = $self->__Set( Field => 'Content', Value => $content );
    unless ( $status ) {
        return ($status, $self->loc("Couldn't replace content with encrypted data: [_1]", $msg));
    }

    $type = qq{x-application-rt\/$res{'Protocol'}-encrypted; original-type="$type"};
    $self->__Set( Field => 'ContentType', Value => $type );
    $self->SetHeader( 'Content-Type' => $type );

    return (1, $self->loc('Successfuly encrypted data'));
}

sub Decrypt {
    my $self = shift;

    my $txn = $self->TransactionObj;
    return (0, $self->loc('Permission Denied')) unless $txn->CurrentUserCanSee;
    return (0, $self->loc('Permission Denied'))
        unless $txn->TicketObj->CurrentUserHasRight('ModifyTicket');
    return (0, $self->loc('Cryptography is disabled'))
        unless RT->Config->Get('Crypt')->{'Enable'};

    my $type = $self->ContentType;
    my $protocol;
    if ( $type =~ /^x-application-rt\/([^-]+)-encrypted/i ) {
        $protocol = $1;
        $protocol =~ s/gpg/gnupg/; # backwards compatibility
        ($type) = ($type =~ /original-type="(.*)"/i);
        $type ||= 'application/octet-stream';
    } else {
        return (1, $self->loc('Is not encrypted'));
    }

    my $queue = $txn->TicketObj->QueueObj;
    my @addresses =
        $queue->CorrespondAddress,
        $queue->CommentAddress,
        RT->Config->Get('CorrespondAddress'),
        RT->Config->Get('CommentAddress')
    ;

    my $content = $self->Content;
    my %res = RT::Crypt->DecryptContent(
        Protocol => $protocol,
        Content => \$content,
        Recipients => \@addresses,
    );
    if ( $res{'exit_code'} ) {
        return (0, $self->loc('Decryption error; contact the administrator'));
    }

    my ($status, $msg) = $self->__Set( Field => 'Content', Value => $content );
    unless ( $status ) {
        return ($status, $self->loc("Couldn't replace content with decrypted data: [_1]", $msg));
    }
    $self->__Set( Field => 'ContentType', Value => $type );
    $self->SetHeader( 'Content-Type' => $type );

    return (1, $self->loc('Successfuly decrypted data'));
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
        return ( $self->__Value( $field, @_ ) );
    }

    return undef unless $self->TransactionObj->CurrentUserCanSee;
    return $self->__Value( $field, @_ );
}

# Attachments don't change; by adding this cache config directive,
# we don't lose pathalogically on long tickets.
sub _CacheConfig {
    {
        'cache_for_sec' => 180,
    }
}




=head2 id

Returns the current value of id.
(In the database, id is stored as int(11).)


=cut


=head2 TransactionId

Returns the current value of TransactionId.
(In the database, TransactionId is stored as int(11).)



=head2 SetTransactionId VALUE


Set TransactionId to VALUE.
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, TransactionId will be stored as a int(11).)


=cut


=head2 Parent

Returns the current value of Parent.
(In the database, Parent is stored as int(11).)



=head2 SetParent VALUE


Set Parent to VALUE.
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, Parent will be stored as a int(11).)


=cut


=head2 MessageId

Returns the current value of MessageId.
(In the database, MessageId is stored as varchar(160).)



=head2 SetMessageId VALUE


Set MessageId to VALUE.
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, MessageId will be stored as a varchar(160).)


=cut


=head2 Subject

Returns the current value of Subject.
(In the database, Subject is stored as varchar(255).)



=head2 SetSubject VALUE


Set Subject to VALUE.
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, Subject will be stored as a varchar(255).)


=cut


=head2 Filename

Returns the current value of Filename.
(In the database, Filename is stored as varchar(255).)



=head2 SetFilename VALUE


Set Filename to VALUE.
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, Filename will be stored as a varchar(255).)


=cut


=head2 ContentType

Returns the current value of ContentType.
(In the database, ContentType is stored as varchar(80).)



=head2 SetContentType VALUE


Set ContentType to VALUE.
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, ContentType will be stored as a varchar(80).)


=cut


=head2 ContentEncoding

Returns the current value of ContentEncoding.
(In the database, ContentEncoding is stored as varchar(80).)



=head2 SetContentEncoding VALUE


Set ContentEncoding to VALUE.
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, ContentEncoding will be stored as a varchar(80).)


=cut


=head2 Content

Returns the current value of Content.
(In the database, Content is stored as longblob.)



=head2 SetContent VALUE


Set Content to VALUE.
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, Content will be stored as a longblob.)


=cut


=head2 Headers

Returns the current value of Headers.
(In the database, Headers is stored as longtext.)



=head2 SetHeaders VALUE


Set Headers to VALUE.
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, Headers will be stored as a longtext.)


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
        TransactionId =>
                {read => 1, write => 1, sql_type => 4, length => 11,  is_blob => 0,  is_numeric => 1,  type => 'int(11)', default => ''},
        Parent =>
                {read => 1, write => 1, sql_type => 4, length => 11,  is_blob => 0,  is_numeric => 1,  type => 'int(11)', default => '0'},
        MessageId =>
                {read => 1, write => 1, sql_type => 12, length => 160,  is_blob => 0,  is_numeric => 0,  type => 'varchar(160)', default => ''},
        Subject =>
                {read => 1, write => 1, sql_type => 12, length => 255,  is_blob => 0,  is_numeric => 0,  type => 'varchar(255)', default => ''},
        Filename =>
                {read => 1, write => 1, sql_type => 12, length => 255,  is_blob => 0,  is_numeric => 0,  type => 'varchar(255)', default => ''},
        ContentType =>
                {read => 1, write => 1, sql_type => 12, length => 80,  is_blob => 0,  is_numeric => 0,  type => 'varchar(80)', default => ''},
        ContentEncoding =>
                {read => 1, write => 1, sql_type => 12, length => 80,  is_blob => 0,  is_numeric => 0,  type => 'varchar(80)', default => ''},
        Content =>
                {read => 1, write => 1, sql_type => -4, length => 0,  is_blob => 1,  is_numeric => 0,  type => 'longblob', default => ''},
        Headers =>
                {read => 1, write => 1, sql_type => -4, length => 0,  is_blob => 1,  is_numeric => 0,  type => 'longtext', default => ''},
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
    $deps->Add( out => $self->TransactionObj );
}

sub __DependsOn {
    my $self = shift;
    my %args = (
        Shredder => undef,
        Dependencies => undef,
        @_,
    );
    my $deps = $args{'Dependencies'};
    my $list = [];

    # Nested attachments
    my $objs = RT::Attachments->new( $self->CurrentUser );
    $objs->Limit(
        FIELD => 'Parent',
        OPERATOR        => '=',
        VALUE           => $self->Id
    );
    $objs->Limit(
        FIELD => 'id',
        OPERATOR        => '!=',
        VALUE           => $self->Id
    );
    push( @$list, $objs );

    $deps->_PushDependencies(
        BaseObject => $self,
        Flags => RT::Shredder::Constants::DEPENDS_ON,
        TargetObjects => $list,
        Shredder => $args{'Shredder'}
    );
    return $self->SUPER::__DependsOn( %args );
}

sub ShouldStoreExternally {
    my $self = shift;
    my $type = $self->ContentType;
    my $length = $self->ContentLength;

    if ($type =~ m{^multipart/}) {
        return (0, "attachment is multipart");
    }
    elsif ($length == 0) {
        return (0, "zero length");
    }
    elsif ($type =~ m{^(text|message)/}) {
        # If textual, we only store externally if it's _large_
        return 1 if $length > RT->Config->Get('ExternalStorageCutoffSize');
        return (0, "text length ($length) does not exceed ExternalStorageCutoffSize (" . RT->Config->Get('ExternalStorageCutoffSize') . ")");
    }
    elsif ($type =~ m{^image/}) {
        # Ditto images, which may be displayed inline
        return 1 if $length > RT->Config->Get('ExternalStorageCutoffSize');
        return (0, "image size ($length) does not exceed ExternalStorageCutoffSize (" . RT->Config->Get('ExternalStorageCutoffSize') . ")");
    }
    else {
        return 1;
    }
}

sub ExternalStoreDigest {
    my $self = shift;

    return undef if $self->ContentEncoding ne 'external';
    return $self->_Value('Content');
}

RT::Base->_ImportOverlays();

1;
