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
use warnings;
use strict;

=head1 SYNOPSIS

    use RT::Model::Attachment;

=head1 description

This module should never be instantiated directly by client code. it's an internal 
module which should only be instantiated through exported APIs in Ticket, queue and other 
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
    column transaction_id => references RT::Model::Transaction;
    column
        message_id => max_length is 200,
        type is 'varchar(200)', default is '';
    column parent => references RT::Model::Attachment;
    column
        content_type => max_length is 200,
        type is 'varchar(200)', default is '';
    column filename => max_length is 255, type is 'varchar(255)', default is '';
    column subject  => max_length is 255, type is 'varchar(255)', default is '';
    column content  => type is 'blob',    default is '';
    column content_encoding => type is 'blob', default is '';
    column headers          => type is 'blob', default is '';
    column creator          => references RT::Model::Principal;
    column created          => type is 'timestamp';

};

=head2 create

Create a new attachment. Takes a paramhash:
    
    'Attachment' Should be a single MIME body with optional subparts
    'parent' is an optional id of the parent attachment
    'transaction_id' is the mandatory id of the transaction this attachment is associated with.;

=cut

sub create {
    my $self = shift;
    my %args = (
        id             => 0,
        transaction_id => 0,
        parent         => 0,
        attachment     => undef,
        @_
    );

    # For ease of reference
    my $Attachment = $args{'attachment'};

    # if we didn't specify a ticket, we need to bail
    unless ( $args{'transaction_id'} ) {
        Jifty->log->fatal( "RT::Model::Attachment->create couldn't, as you didn't specify a transaction" );
        return (0);
    }

    # If we possibly can, collapse it to a singlepart
    $Attachment->make_singlepart;

    # Get the subject
    my $subject = $Attachment->head->get( 'subject', 0 );
    defined($subject) or $subject = '';
    chomp($subject);

    #Get the Message-ID
    my $message_id = $Attachment->head->get( 'Message-ID', 0 );
    defined($message_id) or $message_id = '';
    chomp($message_id);
    $message_id =~ s/^<(.*?)>$/$1/o;

    #Get the filename
    my $filename = $Attachment->head->recommended_filename;

    # If a message has no bodyhandle, that means that it has subparts (or appears to)
    # and we should act accordingly.
    unless ( defined $Attachment->bodyhandle ) {
        my ($id) = $self->SUPER::create(
            transaction_id => $args{'transaction_id'},
            parent         => $args{'parent'},
            content_type   => $Attachment->mime_type,
            headers        => $Attachment->head->as_string,
            message_id     => $message_id,
            subject        => $subject,
        );

        unless ($id) {
            Jifty->log->fatal( "Attachment insert failed - " . Jifty->handle->dbh->errstr );
        }

        foreach my $part ( $Attachment->parts ) {
            my $SubAttachment = RT::Model::Attachment->new();
            my ($id) = $SubAttachment->create(
                transaction_id => $args{'transaction_id'},
                parent         => $id,
                attachment     => $part,
            );
            unless ($id) {
                Jifty->log->fatal( "Attachment insert failed: " . Jifty->handle->dbh->errstr );
            }
        }
        return ($id);
    }

    #If it's not multipart
    else {

        my ( $content_encoding, $Body ) = $self->_encode_lob( $Attachment->bodyhandle->as_string, $Attachment->mime_type );

        my $id = $self->SUPER::create(
            transaction_id   => $args{'transaction_id'},
            content_type     => $Attachment->mime_type,
            content_encoding => $content_encoding,
            parent           => $args{'parent'},
            headers          => $Attachment->head->as_string,
            subject          => $subject,
            content          => $Body,
            filename         => $filename,
            message_id       => $message_id,
        );

        unless ($id) {
            Jifty->log->fatal( "Attachment insert failed: " . Jifty->handle->dbh->errstr );
        }
        return $id;
    }
}

=head2 import

Create an attachment exactly as specified in the named parameters.

=cut

#XXX: we don't want to mess with perl's importer
sub __import {
    my $self = shift;
    my %args = ( content_encoding => 'none', @_ );

    ( $args{'content_encoding'}, $args{'content'} ) = $self->_encode_lob( $args{'content'}, $args{'MimeType'} );

    return ( $self->SUPER::create(%args) );
}

=head2 transaction_obj

Returns the transaction object asscoiated with this attachment.

=cut

sub transaction_obj {
    my $self = shift;

    unless ( $self->{_transaction_obj} ) {
        $self->{_transaction_obj} = RT::Model::Transaction->new;
        $self->{_transaction_obj}->load( $self->transaction_id );
    }

    unless ( $self->{_transaction_obj}->id ) {
        Jifty->log->fatal( "Attachment " . $self->id . " can't find transaction " . $self->transaction_id . " which it is ostensibly part of. That's bad" );
    }
    return $self->{_transaction_obj};
}

=head2 parent_obj

Returns a parent's L<RT::Model::Attachment> object if this attachment
has a parent, otherwise returns undef.

=cut

sub parent_obj {
    my $self = shift;
    return undef unless $self->parent;

    my $parent = RT::Model::Attachment->new;
    $parent->load_by_id( $self->parent );
    return $parent;
}

=head2 children

Returns an L<RT::Model::AttachmentCollection> object which is preloaded with
all attachments objects with this attachment\'s id as their
C<parent>.

=cut

sub children {
    my $self = shift;

    my $kids = RT::Model::AttachmentCollection->new;
    $kids->children_of( $self->id );
    return ($kids);
}

=head2 content

Returns the attachment's content. if it's base64 encoded, decode it 
before returning it.

=cut

sub content {
    my $self = shift;
    return $self->_decode_lob( $self->content_type, $self->content_encoding, $self->_value( 'content', decode_utf8 => 0 ), );
}

=head2 original_content

Returns the attachment's content as octets before RT's mangling.
Currently, this just means restoring text content back to its
original encoding.

=cut

sub original_content {
    my $self = shift;

    return $self->content
        unless RT::I18N::is_textual_content_type( $self->content_type );
    my $enc = $self->original_encoding;

    my $content;
    if ( !$self->content_encoding || $self->content_encoding eq 'none' ) {
        $content = $self->_value( 'content', decode_utf8 => 0 );
    } elsif ( $self->content_encoding eq 'base64' ) {
        $content = MIME::Base64::decode_base64( $self->_value( 'content', decode_utf8 => 0 ) );
    } elsif ( $self->content_encoding eq 'quoted-printable' ) {
        $content = MIME::QuotedPrint::decode( $self->_value( 'content', decode_utf8 => 0 ) );
    } else {
        return ( _( "Unknown content_encoding %1", $self->content_encoding ) );
    }

    # Turn *off* the SvUTF8 bits here so decode_utf8 and from_to below can work.
    local $@;
    Encode::_utf8_off($content);

    if ( !$enc || $enc eq '' || $enc eq 'utf8' || $enc eq 'utf-8' ) {

        # If we somehow fail to do the decode, at least push out the raw bits
        eval { return ( Encode::decode_utf8($content) ) }
            || return ($content);
    }

    eval { Encode::from_to( $content, 'utf8' => $enc ) } if $enc;
    if ($@) {
        Jifty->log->error( "Could not convert attachment from assumed utf8 to '$enc' :" . $@ );
    }
    return $content;
}

=head2 original_encoding

Returns the attachment's original encoding.

=cut

sub original_encoding {
    my $self = shift;
    return $self->get_header('X-RT-Original-Encoding');
}

=head2 content_length

Returns length of L</content> in bytes.

=cut

sub content_length {
    my $self = shift;

    return undef unless $self->transaction_obj->current_user_can_see;

    my $len = $self->get_header('Content-Length');
    unless ( defined $len ) {
        use bytes;
        no warnings 'uninitialized';
        $len = length( $self->content );
        $self->set_header( 'Content-Length' => $len );
    }
    return $len;
}

=head2 quote

=cut

sub quote {
    my $self = shift;
    my %args = (
        Reply => undef,    # Prefilled reply (i.e. from the KB/FAQ system)
        @_
    );

    my ( $quoted_content, $body, $headers );
    my $max = 0;

    # TODO: Handle Multipart/Mixed (eventually fix the link in the
    # ShowHistory web template?)
    if ( RT::I18N::is_textual_content_type( $self->content_type ) ) {
        $body = $self->content;

        # Do we need any preformatting (wrapping, that is) of the message?

        # Remove quoted signature.
        $body =~ s/\n-- \n(.*)$//s;

        # What's the longest line like?
        foreach ( split( /\n/, $body ) ) {
            $max = length if ( length > $max );
        }

        if ( $max > 76 ) {
            require Text::Wrapper;
            my $wrapper = new Text::Wrapper(
                columns    => 70,
                body_start => ( $max > 70 * 3 ? '   ' : '' ),
                par_start  => ''
            );
            $body = $wrapper->wrap($body);
        }

        $body =~ s/^/> /gm;

        $body = '[' . $self->transaction_obj->creator_obj->name() . ' - ' . $self->transaction_obj->created_as_string() . "]:\n\n" . $body . "\n\n";

    } else {
        $body = "[Non-text message not quoted]\n\n";
    }

    $max = 60 if $max < 60;
    $max = 70 if $max > 78;
    $max += 2;

    return ( \$body, $max );
}

=head2 content_as_mime

Returns MIME entity built from this attachment.

=cut

sub content_as_mime {
    my $self = shift;

    my $entity = new MIME::Entity;
    $entity->head->add( split /:/, $_, 2 ) foreach $self->split_headers;

    use MIME::Body;
    $entity->bodyhandle( MIME::Body::Scalar->new( $self->original_content ) );

    return $entity;
}

=head2 addresses

Returns a hashref of all addresses related to this attachment.
The keys of the hash are C<From>, C<To>, C<Cc>, C<Bcc>, C<RT-Send-Cc>
and C<RT-Send-Bcc>. The values are references to lists of
L<Email::Address> objects.

=cut

sub addresses {
    my $self = shift;

    my %data                 = ();
    my $current_user_address = lc $self->current_user->user_object->email;
    my $correspond           = lc $self->transaction_obj->ticket_obj->queue_obj->correspond_address;
    my $comment              = lc $self->transaction_obj->ticket_obj->queue_obj->comment_address;
    foreach my $hdr (qw(From To Cc Bcc RT-Send-Cc RT-Send-Bcc)) {
        my @Addresses;
        my $line = $self->get_header($hdr);

        foreach my $AddrObj ( Email::Address->parse($line) ) {
            my $address = $AddrObj->address;
            $address = lc RT::Model::User->canonicalize_email($address);
            next if ( $current_user_address eq $address );
            next if ( $comment              eq $address );
            next if ( $correspond           eq $address );
            next if ( RT::EmailParser->is_rt_address($address) );
            push @Addresses, $AddrObj;
        }
        $data{$hdr} = \@Addresses;
    }
    return \%data;
}

=head2 nice_headers

Returns a multi-line string of the To, From, Cc, date and subject headers.

=cut

sub nice_headers {
    my $self = shift;
    my $hdrs = "";
    my @hdrs = $self->_split_headers;
    while ( my $str = shift @hdrs ) {
        next unless $str =~ /^(To|From|RT-Send-Cc|Cc|Bcc|Date|subject):/i;
        $hdrs .= $str . "\n";
        $hdrs .= shift(@hdrs) . "\n" while ( $hdrs[0] =~ /^[ \t]+/ );
    }
    return $hdrs;
}

=head2 headers

Returns this object's headers as a string.  This method specifically
removes the RT-Send-Bcc: header, so as to never reveal to whom RT sent a Bcc.
We need to record the RT-Send-Cc and RT-Send-Bcc values so that we can actually send
out mail. The mailing rules are separated from the ticket update code by
an abstraction barrier that makes it impossible to pass this data directly.

=cut

sub headers {
    return join( "\n", $_[0]->split_headers );
}

=head2 get_header $TAG

Returns the value of the header Tag as a string. This bypasses the weeding out
done in headers() above.

=cut

sub get_header {
    my $self = shift;
    my $tag  = shift;
    foreach my $line ( $self->_split_headers ) {
        next unless $line =~ /^\Q$tag\E:\s+(.*)$/si;

        #if we find the header, return its value
        return ($1);
    }

    # we found no header. return an empty string
    return undef;
}

=head2 del_header $TAG

Delete a field from the attachment's headers.
    
=cut

sub del_header {
    my $self = shift;
    my $tag  = shift;

    my $newheader = '';
    foreach my $line ( $self->_split_headers ) {
        next if $line =~ /^\Q$tag\E:\s+(.*)$/is;
        $newheader .= "$line\n";
    }
    return $self->__set( field => 'headers', value => $newheader );
}

=head2 add_header $TAG, $VALUE, ...

Add one or many fields to the attachment's headers.

=cut

sub add_header {
    my $self = shift;

    my $newheader = $self->__value('headers');
    while ( my ( $tag, $value ) = splice @_, 0, 2 ) {
        $value = '' unless defined $value;
        $value =~ s/\s+$//s;
        $value =~ s/\r+\n/\n /g;
        $newheader .= "$tag: $value\n";
    }
    return $self->__set( column => 'headers', value => $newheader );
}

=head2 set_header ( 'Tag', 'Value' )

Replace or add a Header to the attachment's headers.

=cut

sub set_header {
    my $self      = shift;
    my $tag       = shift;
    my $newheader = '';

    foreach my $line ( $self->_split_headers ) {
        if ( defined $tag and $line =~ /^\Q$tag\E:\s+(.*)$/i ) {
            $newheader .= "$tag: $_[0]\n";
            undef $tag;
        } else {
            $newheader .= "$line\n";
        }
    }

    $newheader .= "$tag: $_[0]\n" if defined $tag;
    $self->__set( column => 'headers', value => $newheader );
}

=head2 split_headers

Returns an array of this attachment object's headers, with one header 
per array entry. Multiple lines are folded.

B<Never> returns C<RT-Send-Bcc> field.

=cut

sub split_headers {
    my $self = shift;
    return ( grep !/^RT-Send-Bcc/i, $self->_split_headers(@_) );
}

=head2 _split_headers

Returns an array of this attachment object's headers, with one header 
per array entry. multiple lines are folded.


=cut

sub _split_headers {
    my $self = shift;
    my $headers = ( shift || $self->_value('headers') );
    my @headers;
    for ( split( /\n(?=\w|\z)/, $headers ) ) {
        push @headers, $_;

    }
    return (@headers);
}

sub encrypt {
    my $self = shift;

    my $txn = $self->transaction_obj;
    return ( 0, _('Permission Denied') ) unless $txn->current_user_can_see;
    return ( 0, _('Permission Denied') )
        unless $txn->ticket_obj->current_user_has_right('ModifyTicket');
    return ( 0, _('GnuPG integration is disabled') )
        unless RT->config->get('GnuPG')->{'enable'};
    return ( 0, _('Attachments encryption is disabled') )
        unless RT->config->get('GnuPG')->{'allow_encrypt_data_in_db'};

    require RT::Crypt::GnuPG;

    my $type = $self->content_type;
    if ( $type =~ /^x-application-rt\/gpg-encrypted/i ) {
        return ( 1, _('Already encrypted') );
    } elsif ( $type =~ /^multipart\//i ) {
        return ( 1, _('No need to encrypt') );
    } else {
        $type = qq{x-application-rt\/gpg-encrypted; original-type="$type"};
    }

    my $queue = $txn->ticket_obj->queue_obj;
    my $encrypt_for;
    foreach my $address ( grep $_, $queue->correspond_address, $queue->comment_address, RT->config->get('CorrespondAddress'), RT->config->get('CommentAddress'), ) {
        my %res = RT::Crypt::GnuPG::get_keys_info( $address, 'private' );
        next if $res{'exit_code'} || !$res{'info'};
        %res = RT::Crypt::GnuPG::get_keys_for_encryption($address);
        next if $res{'exit_code'} || !$res{'info'};
        $encrypt_for = $address;
    }
    unless ($encrypt_for) {
        return ( 0, _('No key suitable for encryption') );
    }

    $self->__set( column => 'content_type', value => $type );
    $self->set_header( 'Content-Type' => $type );

    my $content = $self->content;
    my %res     = RT::Crypt::GnuPG::sign_encrypt_content(
        content    => \$content,
        sign       => 0,
        encrypt    => 1,
        Recipients => [$encrypt_for],
    );
    if ( $res{'exit_code'} ) {
        return ( 0, _('GnuPG error. Contact with administrator') );
    }

    my ( $status, $msg ) = $self->__set( column => 'content', value => $content );
    unless ($status) {
        return ( $status, _( "Couldn't replace content with encrypted data: %1", $msg ) );
    }
    return ( 1, _('Successfuly encrypted data') );
}

sub decrypt {
    my $self = shift;

    my $txn = $self->transaction_obj;
    return ( 0, _('Permission Denied') ) unless $txn->current_user_can_see;
    return ( 0, _('Permission Denied') )
        unless $txn->ticket_obj->current_user_has_right('ModifyTicket');
    return ( 0, _('GnuPG integration is disabled') )
        unless RT->config->get('GnuPG')->{'enable'};

    require RT::Crypt::GnuPG;

    my $type = $self->content_type;
    if ( $type =~ /^x-application-rt\/gpg-encrypted/i ) {
        ($type) = ( $type =~ /original-type="(.*)"/i );
        $type ||= 'application/octeat-stream';
    } else {
        return ( 1, _('Is not encrypted') );
    }
    $self->__set( column => 'content_type', value => $type );
    $self->set_header( 'Content-Type' => $type );

    my $content = $self->content;
    my %res = RT::Crypt::GnuPG::decrypt_content( content => \$content, );
    if ( $res{'exit_code'} ) {
        return ( 0, _('GnuPG error. Contact with administrator') );
    }

    my ( $status, $msg ) = $self->__set( column => 'content', value => $content );
    unless ($status) {
        return ( $status, _( "Couldn't replace content with decrypted data: %1", $msg ) );
    }
    return ( 1, _('Successfuly decrypted data') );
}

=head2 _value

Takes the name of a table column.
Returns its value as a string, if the user passes an ACL check

=cut

sub _value {
    my $self  = shift;
    my $field = shift;

    #if the field is public, return it.
    if (1) {
        return ( $self->__value( $field, @_ ) );
    }

    return undef unless $self->transaction_obj->current_user_can_see;
    return $self->__value( $field, @_ );
}

# Transactions don't change. by adding this cache congif directiove,
# we don't lose pathalogically on long tickets.

1;
