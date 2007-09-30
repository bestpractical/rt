use warnings; use strict;


=head1 SYNOPSIS

    use RT::Model::Attachment;

=head1 DESCRIPTION

This module should never be instantiated directly by client code. it's an internal 
module which should only be instantiated through exported APIs in Ticket, Queue and other 
similar objects.

=head1 METHODS



=cut


package RT::Model::Attachment;

use strict;
no warnings qw(redefine);

use RT::Model::Transaction;
use MIME::Base64;
use MIME::QuotedPrint;

sub table {'Attachments'} 

use base 'RT::Record';
use Jifty::DBI::Schema;
use Jifty::DBI::Record schema {
column        TransactionId => max_length is 11,  type is 'int(11)', default is '0';
column        MessageId => max_length is 200,  type is 'varchar(200)', default is '';
column        Parent => max_length is 11,  type is 'int(11)', default is '0';
column        ContentType => max_length is 200,  type is 'varchar(200)', default is '';
column        Filename => max_length is 255,  type is 'varchar(255)', default is '';
column        Subject => max_length is 255,  type is 'varchar(255)', default is '';

column        Content =>   type is 'blob', default is '';
column        ContentEncoding =>   type is 'blob', default is '';
column        Headers =>   type is 'blob', default is '';
column        Creator => max_length is 11,  type is 'int(11)', default is '0';
column        Created => type is 'datetime';
 
};
 


=head2 Create

Create a new attachment. Takes a paramhash:
    
    'Attachment' Should be a single MIME body with optional subparts
    'Parent' is an optional id of the parent attachment
    'TransactionId' is the mandatory id of the transaction this attachment is associated with.;

=cut

sub create {
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
        $RT::Logger->crit( "RT::Model::Attachment->create couldn't, as you didn't specify a transaction\n" );
        return (0);
    }

    # If we possibly can, collapse it to a singlepart
    $Attachment->make_singlepart;

    # Get the subject
    my $Subject = $Attachment->head->get( 'subject', 0 );
    defined($Subject) or $Subject = '';
    chomp($Subject);

    #Get the Message-ID
    my $MessageId = $Attachment->head->get( 'Message-ID', 0 );
    defined($MessageId) or $MessageId = '';
    chomp ($MessageId);
    $MessageId =~ s/^<(.*?)>$/$1/o;

    #Get the filename
    my $Filename = $Attachment->head->recommended_filename;

    # If a message has no bodyhandle, that means that it has subparts (or appears to)
    # and we should act accordingly.  
    unless ( defined $Attachment->bodyhandle ) {
        my ($id) = $self->SUPER::create(
            TransactionId => $args{'TransactionId'},
            Parent        => $args{'Parent'},
            ContentType   => $Attachment->mime_type,
            Headers       => $Attachment->head->as_string,
            MessageId     => $MessageId,
            Subject       => $Subject,
        );

        unless ($id) {
            $RT::Logger->crit("Attachment insert failed - ". Jifty->handle->dbh->errstr);
        }

        foreach my $part ( $Attachment->parts ) {
            my $SubAttachment = new RT::Model::Attachment( $self->current_user );
            my ($id) = $SubAttachment->create(
                TransactionId => $args{'TransactionId'},
                Parent        => $id,
                Attachment    => $part,
            );
            unless ($id) {
                $RT::Logger->crit("Attachment insert failed: ". Jifty->handle->dbh->errstr);
            }
        }
        return ($id);
    }

    #If it's not multipart
    else {

        my ($ContentEncoding, $Body) = $self->_EncodeLOB(
            $Attachment->bodyhandle->as_string,
            $Attachment->mime_type
        );

        my $id = $self->SUPER::create(
            TransactionId   => $args{'TransactionId'},
            ContentType     => $Attachment->mime_type,
            ContentEncoding => $ContentEncoding,
            Parent          => $args{'Parent'},
            Headers         => $Attachment->head->as_string,
            Subject         => $Subject,
            Content         => $Body,
            Filename        => $Filename,
            MessageId       => $MessageId,
        );

        unless ($id) {
            $RT::Logger->crit("Attachment insert failed: ". Jifty->handle->dbh->errstr);
        }
        return $id;
    }
}

=head2 Import

Create an attachment exactly as specified in the named parameters.

=cut

sub Import {
    my $self = shift;
    my %args = ( ContentEncoding => 'none', @_ );

    ( $args{'ContentEncoding'}, $args{'Content'} ) =
        $self->_EncodeLOB( $args{'Content'}, $args{'MimeType'} );

    return ( $self->SUPER::create(%args) );
}

=head2 TransactionObj

Returns the transaction object asscoiated with this attachment.

=cut

sub TransactionObj {
    my $self = shift;

    unless ( $self->{_TransactionObj} ) {
        $self->{_TransactionObj} = RT::Model::Transaction->new( $self->current_user );
        $self->{_TransactionObj}->load( $self->TransactionId );
    }

    unless ($self->{_TransactionObj}->id) {
        $RT::Logger->crit(  "Attachment ". $self->id
                           ." can't find transaction ". $self->TransactionId
                           ." which it is ostensibly part of. That's bad");
    }
    return $self->{_TransactionObj};
}

=head2 ParentObj

Returns a parent's L<RT::Model::Attachment> object if this attachment
has a parent, otherwise returns undef.

=cut

sub ParentObj {
    my $self = shift;
    return undef unless $self->Parent;

    my $parent = RT::Model::Attachment->new( $self->current_user );
    $parent->load_by_id( $self->Parent );
    return $parent;
}

=head2 Children

Returns an L<RT::Model::AttachmentCollection> object which is preloaded with
all attachments objects with this attachment\'s Id as their
C<Parent>.

=cut

sub Children {
    my $self = shift;
    
    my $kids = RT::Model::AttachmentCollection->new( $self->current_user );
    $kids->ChildrenOf( $self->id );
    return($kids);
}

=head2 Content

Returns the attachment's content. if it's base64 encoded, decode it 
before returning it.

=cut

sub Content {
    my $self = shift;
    return $self->_DecodeLOB(
        $self->ContentType,
        $self->ContentEncoding,
        $self->_value('Content', decode_utf8 => 0),
    );
}

=head2 OriginalContent

Returns the attachment's content as octets before RT's mangling.
Currently, this just means restoring text content back to its
original encoding.

=cut

sub OriginalContent {
    my $self = shift;

    return $self->Content unless ($self->ContentType =~ qr{^(text/plain|message/rfc822)$}i);
    my $enc = $self->OriginalEncoding;

    my $content;
    if ( !$self->ContentEncoding || $self->ContentEncoding eq 'none' ) {
        $content = $self->_value('Content', decode_utf8 => 0);
    } elsif ( $self->ContentEncoding eq 'base64' ) {
        $content = MIME::Base64::decode_base64($self->_value('Content', decode_utf8 => 0));
    } elsif ( $self->ContentEncoding eq 'quoted-printable' ) {
        return MIME::QuotedPrint::decode($self->_value('Content', decode_utf8 => 0));
    } else {
        return( $self->loc("Unknown ContentEncoding [_1]", $self->ContentEncoding));
    }

    # please, comment this code //ruz
    # Encode::_utf8_on($content);
    if (!$enc || $enc eq '' ||  $enc eq 'utf8' || $enc eq 'utf-8') {
        # If we somehow fail to do the decode, at least push out the raw bits
        eval { return( Encode::decode_utf8($content)) } || return ($content);
    }

    eval { Encode::from_to($content, 'utf8' => $enc) } if $enc;
    if ($@) {
        $RT::Logger->error("Could not convert attachment from assumed utf8 to '$enc' :".$@);
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

    return undef unless $self->TransactionObj->current_user_can_see;

    my $len = $self->GetHeader('Content-Length');
    unless ( defined $len ) {
        use bytes;
        no warnings 'uninitialized';
        $len = length($self->Content);
        $self->set_Header('Content-Length' => $len);
    }
    return $len;
}

=head2 Quote

=cut

sub Quote {
    my $self=shift;
    my %args=(Reply=>undef, # Prefilled reply (i.e. from the KB/FAQ system)
	      @_);

    my ($quoted_content, $body, $headers);
    my $max=0;

    # TODO: Handle Multipart/Mixed (eventually fix the link in the
    # ShowHistory web template?)
    if ($self->ContentType =~ m{^(text/plain|message)}i) {
	$body=$self->Content;

	# Do we need any preformatting (wrapping, that is) of the message?

	# Remove quoted signature.
	$body =~ s/\n-- \n(.*)$//s;

	# What's the longest line like?
	foreach (split (/\n/,$body)) {
	    $max=length if ( length > $max);
	}

	if ($max>76) {
	    require Text::Wrapper;
	    my $wrapper=new Text::Wrapper
		(
		 columns => 70, 
		 body_start => ($max > 70*3 ? '   ' : ''),
		 par_start => ''
		 );
	    $body=$wrapper->wrap($body);
	}

	$body =~ s/^/> /gm;

	$body = '[' . $self->TransactionObj->CreatorObj->Name() . ' - ' . $self->TransactionObj->CreatedAsString()
	            . "]:\n\n"
   	        . $body . "\n\n";

    } else {
	$body = "[Non-text message not quoted]\n\n";
    }
    
    $max=60 if $max<60;
    $max=70 if $max>78;
    $max+=2;

    return (\$body, $max);
}

=head2 ContentAsMIME

Returns MIME entity built from this attachment.

=cut

sub ContentAsMIME {
    my $self = shift;

    my $entity = new MIME::Entity;
    $entity->head->add( split /:/, $_, 2 )
        foreach $self->SplitHeaders;

    use MIME::Body;
    $entity->bodyhandle(
        MIME::Body::Scalar->new( $self->OriginalContent )
    );

    return $entity;
}


=head2 Addresses

Returns a hashref of all addresses related to this attachment.  
The keys of the hash are C<From>,C<To>,C<Cc>, C<Bcc>, C<RT-Send-Cc> and C<RT-Send-Bcc>. The values are references to lists of Mail::Address objects.


=cut


sub Addresses {
    my $self = shift;

    my %data = ();
    my $current_user_address = lc $self->current_user->EmailAddress;
    my $correspond = lc $self->TransactionObj->TicketObj->QueueObj->CorrespondAddress;
    my $comment = lc $self->TransactionObj->TicketObj->QueueObj->CommentAddress;
    foreach my $hdr (qw(From To Cc Bcc RT-Send-Cc RT-Send-Bcc)) {
        my @Addresses;
        my $line      = $self->GetHeader($hdr);
        
        foreach my $AddrObj ( Mail::Address->parse( $line )) {
            my $address = $AddrObj->address;
            my $user    = RT::Model::User->new(RT->SystemUser);
            $address = lc $user->CanonicalizeEmailAddress($address);
            next if ( $current_user_address eq $address );
            next if ( $comment              eq $address );
            next if ( $correspond           eq $address );
            next if ( RT::EmailParser->IsRTAddress($address) );
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

=head2 GetHeader $TAG

Returns the value of the header Tag as a string. This bypasses the weeding out
done in Headers() above.

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
=head DelHeader $TAG

Delete a field from the attachment's headers.
    
=cut
    
sub DelHeader {
    my $self = shift;
    my $tag = shift;
    
    my $newheader = '';
    foreach my $line ($self->_SplitHeaders) {
        next if $line =~ /^\Q$tag\E:\s+(.*)$/is;
    $newheader .= "$line\n";
    }
    return $self->__set( field => 'Headers', value => $newheader);
}

=head AddHeader $TAG, $VALUE, ...

Add one or many fields to the attachment's headers.

=cut

sub AddHeader {
    my $self = shift;

    my $newheader = $self->__value( 'Headers' );
    while ( my ($tag, $value) = splice @_, 0, 2 ) {
        $value = '' unless defined $value;
        $value =~ s/\s+$//s;
        $value =~ s/\r+\n/\n /g;
    $newheader .= "$tag: $value\n";
    }
    return $self->__set( column => 'Headers', value => $newheader);
}       

=head2 SetHeader ( 'Tag', 'Value' )

Replace or add a Header to the attachment's headers.

=cut

sub set_Header {
    my $self = shift;
    my $tag = shift;
    my $newheader = '';

    foreach my $line ($self->_SplitHeaders) {
        if (defined $tag and $line =~ /^\Q$tag\E:\s+(.*)$/i) {
	    $newheader .= "$tag: $_[0]\n";
	    undef $tag;
        }
	else {
	    $newheader .= "$line\n";
	}
    }

    $newheader .= "$tag: $_[0]\n" if defined $tag;
    $self->__set( column => 'Headers', value => $newheader);
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
    my $headers = (shift || $self->_value('Headers'));
    my @headers;
    for (split(/\n(?=\w|\z)/,$headers)) {
        push @headers, $_;

    }
    return(@headers);
}


=head2 _value

Takes the name of a table column.
Returns its value as a string, if the user passes an ACL check

=cut

sub _value {
    my $self  = shift;
    my $field = shift;

    #if the field is public, return it.
    if ( 1) {
        return ( $self->__value( $field, @_ ) );
    }

    return undef unless $self->TransactionObj->current_user_can_see;
    return $self->__value( $field, @_ );
}

# Transactions don't change. by adding this cache congif directiove,
# we don't lose pathalogically on long tickets.
sub _CacheConfig {
    {
        'cache_p'       => 1,
        'fast_update_p' => 1,
        'cache_for_sec' => 180,
    }
}

1;
