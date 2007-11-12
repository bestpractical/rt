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
=head1 SYNOPSIS

  use RT::Attachment;


=head1 DESCRIPTION

This module should never be instantiated directly by client code. it's an internal 
module which should only be instantiated through exported APIs in Ticket, Queue and other 
similar objects.


=head1 METHODS


=begin testing

ok (require RT::Attachment);

=end testing

=cut


package RT::Attachment;

use strict;
no warnings qw(redefine);

use MIME::Base64;
use MIME::QuotedPrint;


# {{{ sub _OverlayAccessible 
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
# }}}

# {{{ sub TransactionObj 

=head2 TransactionObj

Returns the transaction object asscoiated with this attachment.

=cut

sub TransactionObj {
    require RT::Transaction;
    my $self=shift;
    unless (exists $self->{_TransactionObj}) {
	$self->{_TransactionObj}=RT::Transaction->new($self->CurrentUser);
	$self->{_TransactionObj}->Load($self->TransactionId);
    }
    unless ($self->{_TransactionObj}->Id) {
        $RT::Logger->crit("Attachment ".$self->id." can't find transaction ".$self->TransactionId." which it is ostensibly part of. That's bad");
    }
    return $self->{_TransactionObj};
}

# }}}

# {{{ sub Create 

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

    #For ease of reference
    my $Attachment = $args{'Attachment'};

    #if we didn't specify a ticket, we need to bail
    if ( $args{'TransactionId'} == 0 ) {
        $RT::Logger->crit( "RT::Attachment->Create couldn't, as you didn't specify a transaction\n" );
        return (0);

    }

    #If we possibly can, collapse it to a singlepart
    $Attachment->make_singlepart;

    #Get the subject
    my $Subject = $Attachment->head->get( 'subject', 0 );
    defined($Subject) or $Subject = '';
    chomp($Subject);

    #Get the Message-ID
    my $MessageId = $Attachment->head->get( 'Message-ID', 0 );
    defined($MessageId) or $MessageId = '';
    chomp ($MessageId);
    $MessageId =~ s/^<(.*)>$/$1/go;


    #Get the filename
    my $Filename = $Attachment->head->recommended_filename;

    # If a message has no bodyhandle, that means that it has subparts (or appears to)
    # and we should act accordingly.  
    unless ( defined $Attachment->bodyhandle ) {

        my $id = $self->SUPER::Create(
            TransactionId => $args{'TransactionId'},
            Parent        => 0,
            ContentType   => $Attachment->mime_type,
            Headers       => $Attachment->head->as_string,
            MessageId     => $MessageId,
            Subject       => $Subject
        );
        
        unless ($id) {
            $RT::Logger->crit("Attachment insert failed - ".$RT::Handle->dbh->errstr);
        }

        foreach my $part ( $Attachment->parts ) {
            my $SubAttachment = new RT::Attachment( $self->CurrentUser );
            my ($id) = $SubAttachment->Create(
                TransactionId => $args{'TransactionId'},
                Parent        => $id,
                Attachment    => $part,
            );
            unless ($id) {
                $RT::Logger->crit("Attachment insert failed - ".$RT::Handle->dbh->errstr);
            }
        }
        return ($id);
    }

    #If it's not multipart
    else {

        my ($ContentEncoding, $Body) = $self->_EncodeLOB( $Attachment->bodyhandle->as_string,
                                                          $Attachment->mime_type 
                                                        );
        my $id = $self->SUPER::Create(
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
            $RT::Logger->crit("Attachment insert failed - ".$RT::Handle->dbh->errstr);
        }

        return ($id);
    }
}

# }}}


=head2 Import

Create an attachment exactly as specified in the named parameters.

=cut


sub Import {
    my $self = shift;
    my %args = ( ContentEncoding => 'none',

		 @_ );


 ($args{'ContentEncoding'}, $args{'Content'}) = $self->_EncodeLOB($args{'Content'}, $args{'MimeType'});

    return($self->SUPER::Create(%args));
}

# {{{ sub Content

=head2 Content

Returns the attachment's content. if it's base64 encoded, decode it 
before returning it.

=cut

sub Content {
  my $self = shift;
   $self->_DecodeLOB($self->ContentType, $self->ContentEncoding, $self->_Value('Content', decode_utf8 => 0));
}


# }}}


# {{{ sub OriginalContent

=head2 OriginalContent

Returns the attachment's content as octets before RT's mangling.
Currently, this just means restoring text content back to its
original encoding.

=cut

sub OriginalContent {
  my $self = shift;

  return $self->Content unless RT::I18N::IsTextualContentType($self->ContentType);

  my $enc = $self->OriginalEncoding;

  my $content;
  if ( $self->ContentEncoding eq 'none' || ! $self->ContentEncoding ) {
      $content = $self->_Value('Content', decode_utf8 => 0);
  } elsif ( $self->ContentEncoding eq 'base64' ) {
      $content = MIME::Base64::decode_base64($self->_Value('Content', decode_utf8 => 0));
  } elsif ( $self->ContentEncoding eq 'quoted-printable' ) {
      $content = MIME::QuotedPrint::decode($self->_Value('Content', decode_utf8 => 0));
  } else {
      return( $self->loc("Unknown ContentEncoding [_1]", $self->ContentEncoding));
  }

  # Turn *off* the SvUTF8 bits here so decode_utf8 and from_to below can work.
  local $@;
  Encode::_utf8_off($content);

  if (!$enc || $enc eq '' ||  $enc eq 'utf8' || $enc eq 'utf-8') {
    # If we somehow fail to do the decode, at least push out the raw bits
    eval {return( Encode::decode_utf8($content))} || return ($content);
  }
  
  eval { Encode::from_to($content, 'utf8' => $enc) } if $enc;
  if ($@) {
	$RT::Logger->error("Could not convert attachment from assumed utf8 to '$enc' :".$@);
  }
  return $content;
}

# }}}


# {{{ sub OriginalEncoding

=head2 OriginalEncoding

Returns the attachment's original encoding.

=cut

sub OriginalEncoding {
  my $self = shift;
  return $self->GetHeader('X-RT-Original-Encoding');
}

# }}}

# {{{ sub Children

=head2 Children

  Returns an RT::Attachments object which is preloaded with all Attachments objects with this Attachment\'s Id as their 'Parent'

=cut

sub Children {
    my $self = shift;
    
    my $kids = new RT::Attachments($self->CurrentUser);
    $kids->ChildrenOf($self->Id);
    return($kids);
}

# }}}

# {{{ UTILITIES

# {{{ sub Quote 



sub Quote {
    my $self=shift;
    my %args=(Reply=>undef, # Prefilled reply (i.e. from the KB/FAQ system)
	      @_);

    my ($quoted_content, $body, $headers);
    my $max=0;

    # TODO: Handle Multipart/Mixed (eventually fix the link in the
    # ShowHistory web template?)
    if (RT::I18N::IsTextualContentType($self->ContentType)) {
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
# }}}

# {{{ sub NiceHeaders - pulls out only the most relevant headers

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
# }}}

# {{{ sub Headers

=head2 Headers

Returns this object's headers as a string.  This method specifically
removes the RT-Send-Bcc: header, so as to never reveal to whom RT sent a Bcc.
We need to record the RT-Send-Cc and RT-Send-Bcc values so that we can actually send
out mail. (The mailing rules are separated from the ticket update code by
an abstraction barrier that makes it impossible to pass this data directly

=cut

sub Headers {
    my $self = shift;
    my $hdrs="";
    my @headers =  grep { !/^RT-Send-Bcc/i } $self->_SplitHeaders;
    return join("\n",@headers);

}


# }}}

# {{{ sub GetHeader

=head2 GetHeader ( 'Tag')

Returns the value of the header Tag as a string. This bypasses the weeding out
done in Headers() above.

=cut

sub GetHeader {
    my $self = shift;
    my $tag = shift;
    foreach my $line ($self->_SplitHeaders) {
        if ($line =~ /^\Q$tag\E:\s+(.*)$/si) { #if we find the header, return its value
            return ($1);
        }
    }
    
    # we found no header. return an empty string
    return undef;
}
# }}}

# {{{ sub SetHeader

=head2 SetHeader ( 'Tag', 'Value' )

Replace or add a Header to the attachment's headers.

=cut

sub SetHeader {
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
    $self->__Set( Field => 'Headers', Value => $newheader);
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
        return ( $self->__Value( $field, @_ ) );
    }

    #If it's a comment, we need to be extra special careful
    elsif ( $self->TransactionObj->Type =~ /^Comment/ ) {
        if ( $self->TransactionObj->CurrentUserHasRight('ShowTicketComments') )
        {
            return ( $self->__Value( $field, @_ ) );
        }
    }
    elsif ( $self->TransactionObj->CurrentUserHasRight('ShowTicket') ) {
        return ( $self->__Value( $field, @_ ) );
    }

    #if they ain't got rights to see, don't let em
    else {
        return (undef);
    }

}

# }}}

=head2 _SplitHeaders

Returns an array of this attachment object's headers, with one header 
per array entry. multiple lines are folded.

=begin testing

my $test1 = "From: jesse";
my @headers = RT::Attachment->_SplitHeaders($test1);
is ($#headers, 0, $test1 );

my $test2 = qq{From: jesse
To: bobby
Subject: foo
};

@headers = RT::Attachment->_SplitHeaders($test2);
is ($#headers, 2, "testing a bunch of singline multiple headers" );


my $test3 = qq{From: jesse
To: bobby,
 Suzie,
    Sally,
    Joey: bizzy,
Subject: foo
};

@headers = RT::Attachment->_SplitHeaders($test3);
is ($#headers, 2, "testing a bunch of singline multiple headers" );


=end testing

=cut

sub _SplitHeaders {
    my $self = shift;
    my $headers = (shift || $self->SUPER::Headers());
    my @headers;
    for (split(/\n(?=\w|\z)/,$headers)) {
        push @headers, $_;

    }
    return(@headers);
}


sub ContentLength {
    my $self = shift;

    unless ( (($self->TransactionObj->CurrentUserHasRight('ShowTicketComments')) and
	     ($self->TransactionObj->Type eq 'Comment') )  or
	    ($self->TransactionObj->CurrentUserHasRight('ShowTicket'))) {
	return undef;
    }

    if (my $len = $self->GetHeader('Content-Length')) {
	return $len;
    }

    {
	use bytes;
	my $len = length($self->Content);
	$self->SetHeader('Content-Length' => $len);
	return $len;
    }
}

# }}}

# Transactions don't change. by adding this cache congif directiove, we don't lose pathalogically on long tickets.
sub _CacheConfig {
    {
        'cache_p'         => 1,
          'fast_update_p' => 1,
          'cache_for_sec' => 180,
    }
}

1;
