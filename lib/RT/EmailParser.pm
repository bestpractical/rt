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

package RT::EmailParser;


use base qw/RT::Base/;

use strict;
use warnings;


use Email::Address;
use MIME::Entity;
use MIME::Head;
use MIME::Parser;
use File::Temp qw/tempdir/;
use RT::Util qw(mime_recommended_filename EntityLooksLikeEmailMessage);

=head1 NAME

  RT::EmailParser - helper functions for parsing parts from incoming
  email messages

=head1 SYNOPSIS


=head1 DESCRIPTION




=head1 METHODS

=head2 new

Returns a new RT::EmailParser object

=cut

sub new  {
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my $self  = {};
  bless ($self, $class);
  return $self;
}


=head2 SmartParseMIMEEntityFromScalar Message => SCALAR_REF [, Decode => BOOL, Exact => BOOL ] }

Parse a message stored in a scalar from scalar_ref.

=cut

sub SmartParseMIMEEntityFromScalar {
    my $self = shift;
    my %args = ( Message => undef, Decode => 1, Exact => 0, @_ );

    eval {
        my ( $fh, $temp_file );
        for ( 1 .. 10 ) {

            # on NFS and NTFS, it is possible that tempfile() conflicts
            # with other processes, causing a race condition. we try to
            # accommodate this by pausing and retrying.
            last
              if ( $fh, $temp_file ) =
              eval { File::Temp::tempfile( UNLINK => 0 ) };
            sleep 1;
        }
        if ($fh) {

            #thank you, windows                      
            binmode $fh;
            $fh->autoflush(1);
            print $fh $args{'Message'};
            close($fh);
            if ( -f $temp_file ) {

                my $entity = $self->ParseMIMEEntityFromFile( $temp_file, $args{'Decode'}, $args{'Exact'} );
                unlink($temp_file)
                    or RT->Logger->error("Unable to delete temp file $temp_file, error: $!");
                return $entity;
            }
        }
    };

    #If for some reason we weren't able to parse the message using a temp file
    # try it with a scalar
    if ( $@ || !$self->Entity ) {
        return $self->ParseMIMEEntityFromScalar( $args{'Message'}, $args{'Decode'}, $args{'Exact'} );
    }

}


=head2 ParseMIMEEntityFromSTDIN

Parse a message from standard input

=cut

sub ParseMIMEEntityFromSTDIN {
    my $self = shift;
    return $self->ParseMIMEEntityFromFileHandle(\*STDIN, @_);
}

=head2 ParseMIMEEntityFromScalar  $message

Takes either a scalar or a reference to a scalar which contains a stringified MIME message.
Parses it.

Returns true if it wins.
Returns false if it loses.

=cut

sub ParseMIMEEntityFromScalar {
    my $self = shift;
    return $self->_ParseMIMEEntity( shift, 'parse_data', @_ );
}

=head2 ParseMIMEEntityFromFilehandle *FH

Parses a mime entity from a filehandle passed in as an argument

=cut

sub ParseMIMEEntityFromFileHandle {
    my $self = shift;
    return $self->_ParseMIMEEntity( shift, 'parse', @_ );
}

=head2 ParseMIMEEntityFromFile 

Parses a mime entity from a filename passed in as an argument

=cut

sub ParseMIMEEntityFromFile {
    my $self = shift;
    return $self->_ParseMIMEEntity( shift, 'parse_open', @_ );
}


sub _ParseMIMEEntity {
    my $self = shift;
    my $message = shift;
    my $method = shift;
    my $postprocess = (@_ ? shift : 1);
    my $exact = shift;

    # Create a new parser object:
    my $parser = MIME::Parser->new();
    $self->_SetupMIMEParser($parser);
    $parser->decode_bodies(0) if $exact;

    # TODO: XXX 3.0 we really need to wrap this in an eval { }
    unless ( $self->{'entity'} = $parser->$method($message) ) {
        $RT::Logger->crit("Couldn't parse MIME stream and extract the submessages");
        # Try again, this time without extracting nested messages
        $parser->extract_nested_messages(0);
        unless ( $self->{'entity'} = $parser->$method($message) ) {
            $RT::Logger->crit("couldn't parse MIME stream");
            return ( undef);
        }
    }

    $self->_PostProcessNewEntity if $postprocess;

    return $self->{'entity'};
}

sub _DecodeBodies {
    my $self = shift;
    return unless $self->{'entity'};
    
    my @parts = $self->{'entity'}->parts_DFS;
    $self->_DecodeBody($_) foreach @parts;
}

sub _DecodeBody {
    my $self = shift;
    my $entity = shift;

    my $old = $entity->bodyhandle or return;
    return unless $old->is_encoded;

    require MIME::Decoder;
    my $encoding = $entity->head->mime_encoding;
    my $decoder = MIME::Decoder->new($encoding);
    unless ( $decoder ) {
        $RT::Logger->error("Couldn't find decoder for '$encoding', switching to binary");
        $old->is_encoded(0);
        return;
    }

    require MIME::Body;
    # XXX: use InCore for now, but later must switch to files
    my $new = MIME::Body::InCore->new();
    $new->binmode(1);
    $new->is_encoded(0);

    my $source = $old->open('r') or die "couldn't open body: $!";
    my $destination = $new->open('w') or die "couldn't open body: $!";
    { 
        local $@;
        eval { $decoder->decode($source, $destination) };
        $RT::Logger->error($@) if $@;
    }
    $source->close or die "can't close: $!";
    $destination->close or die "can't close: $!";

    $entity->bodyhandle( $new );
}

=head2 _PostProcessNewEntity

cleans up and postprocesses a newly parsed MIME Entity

=cut

sub _PostProcessNewEntity {
    my $self = shift;

    #Now we've got a parsed mime object. 

    _DetectAttachedEmailFiles($self->{'entity'});

    # Unfold headers that are have embedded newlines
    #  Better do this before conversion or it will break
    #  with multiline encoded Subject (RFC2047) (fsck.com #5594)
    $self->Head->unfold;

    # try to convert text parts into utf-8 charset
    RT::I18N::SetMIMEEntityToEncoding($self->{'entity'}, 'utf-8');
}

=head2 _DetectAttachedEmailFiles

Email messages submitted as attachments will be processed as a nested email
rather than an attached file. Users may prefer to treat attached emails
as normal file attachments and not have them processed.

If TreatAttachedEmailAsFiles is selected, treat attached email files
as regular file attachments. We do this by checking MIME entities that
have email (message/) content types and also have a defined filename,
indicating they are attachments.

See the extract_nested_messages documentation in in the L<MIME::Parser>
module for details on how it deals with nested email messages.

=cut

sub _DetectAttachedEmailFiles {
    my $entity = shift;

    return unless RT->Config->Get('TreatAttachedEmailAsFiles');

    my $filename = mime_recommended_filename($entity);

    # This detection is based on the way MIME::Parser handles email with
    # extract_nested_messages enabled.

    if ( EntityLooksLikeEmailMessage($entity)
         && not defined $entity->bodyhandle
         && $filename ) {

        # Fixup message
        # TODO: Investigate proposing an option upstream in MIME::Parser to avoid the initial parse
        if ( $entity->parts(0) ){
            my $bodyhandle = $entity->parts(0)->bodyhandle;

            # Get the headers from the part and write them back to the body.
            # This will create a file attachment that looks like the file you get if
            # you "Save As" and email message in your email client.
            # If we don't save them here, the headers from the attached email will be lost.

            my $headers = $entity->parts(0)->head->as_string;
            my $body = $bodyhandle->as_string;

            my $IO = $bodyhandle->open("w")
                || RT::Logger->error("Unable to open email body: $!");
            $IO->print($headers . "\n");
            $IO->print($body);
            $IO->close
                || RT::Logger->error("Unable to close email body: $!");

            $entity->parts([]);
            $entity->bodyhandle($bodyhandle);
            RT::Logger->debug("Manually setting bodyhandle for attached email file");
        }
    }
    elsif ( $entity->parts ) {
        foreach my $part ( $entity->parts ){
            _DetectAttachedEmailFiles( $part );
        }
    }

    return;
}

=head2 IsRTaddress ADDRESS

Takes a single parameter, an email address. 
Returns true if that address matches the C<RTAddressRegexp> config option.
Returns false, otherwise.


=cut

sub IsRTAddress {
    my $self = shift;
    my $address = shift;

    return undef unless defined($address) and $address =~ /\S/;

    if ( my $address_re = RT->Config->Get('RTAddressRegexp') ) {
        return $address =~ /$address_re/i ? 1 : undef;
    }

    # we don't warn here, but do in config check
    if ( my $correspond_address = RT->Config->Get('CorrespondAddress') ) {
        return 1 if lc $correspond_address eq lc $address;
    }
    if ( my $comment_address = RT->Config->Get('CommentAddress') ) {
        return 1 if lc $comment_address eq lc $address;
    }

    my $queue = RT::Queue->new( RT->SystemUser );
    $queue->LoadByCols( CorrespondAddress => $address );
    return 1 if $queue->id;

    $queue->LoadByCols( CommentAddress => $address );
    return 1 if $queue->id;

    return undef;
}


=head2 CullRTAddresses ARRAY

Takes a single argument, an array of email addresses.
Returns the same array with any IsRTAddress()es weeded out.


=cut

sub CullRTAddresses {
    my $self = shift;
    my @addresses = (@_);

    return grep { !$self->IsRTAddress($_) } @addresses;
}


# LookupExternalUserInfo is a site-definable method for synchronizing
# incoming users with an external data source. 
#
# This routine takes a tuple of EmailAddress and FriendlyName
#   EmailAddress is the user's email address, ususally taken from
#       an email message's From: header.
#   FriendlyName is a freeform string, ususally taken from the "comment" 
#       portion of an email message's From: header.
#
# If you define an AutoRejectRequest template, RT will use this   
# template for the rejection message.


=head2 LookupExternalUserInfo

 LookupExternalUserInfo is a site-definable method for synchronizing
 incoming users with an external data source. 

 This routine takes a tuple of EmailAddress and FriendlyName
    EmailAddress is the user's email address, ususally taken from
        an email message's From: header.
    FriendlyName is a freeform string, ususally taken from the "comment" 
        portion of an email message's From: header.

 It returns (FoundInExternalDatabase, ParamHash);

   FoundInExternalDatabase must  be set to 1 before return if the user 
   was found in the external database.

   ParamHash is a Perl parameter hash which can contain at least the 
   following fields. These fields are used to populate RT's users 
   database when the user is created.

    EmailAddress is the email address that RT should use for this user.  
    Name is the 'Name' attribute RT should use for this user. 
         'Name' is used for things like access control and user lookups.
    RealName is what RT should display as the user's name when displaying 
         'friendly' names

=cut

sub LookupExternalUserInfo {
  my $self = shift;
  my $EmailAddress = shift;
  my $RealName = shift;

  my $FoundInExternalDatabase = 1;
  my %params;

  #Name is the RT username you want to use for this user.
  $params{'Name'} = $EmailAddress;
  $params{'EmailAddress'} = $EmailAddress;
  $params{'RealName'} = $RealName;

  return ($FoundInExternalDatabase, %params);
}

=head2 Head

Return the parsed head from this message

=cut

sub Head {
    my $self = shift;
    return $self->Entity->head;
}

=head2 Entity 

Return the parsed Entity from this message

=cut

sub Entity {
    my $self = shift;
    return $self->{'entity'};
}



=head2 _SetupMIMEParser $parser

A private instance method which sets up a mime parser to do its job

=cut


    ## TODO: Does it make sense storing to disk at all?  After all, we
    ## need to put each msg as an in-core scalar before saving it to
    ## the database, don't we?

    ## At the same time, we should make sure that we nuke attachments 
    ## Over max size and return them

sub _SetupMIMEParser {
    my $self   = shift;
    my $parser = shift;
    
    # Set up output directory for files; we use $RT::VarPath instead
    # of File::Spec->tmpdir (e.g., /tmp) beacuse it isn't always
    # writable.
    my $tmpdir;
    if (-w File::Spec->tmpdir) {
        $tmpdir = File::Temp::tempdir( TMPDIR => 1, CLEANUP => 1 );
    } elsif ( -w $RT::VarPath ) {
        $tmpdir = File::Temp::tempdir( DIR => $RT::VarPath, CLEANUP => 1 );
    } else {
        $RT::Logger->crit("Neither the RT var directory ($RT::VarPath) nor the system tmpdir (@{[File::Spec->tmpdir]}) are writable; falling back to in-memory parsing!");
    }

    #If someone includes a message, extract it
    $parser->extract_nested_messages(1);
    $parser->extract_uuencode(1);    ### default is false

    if ($tmpdir) {
        # If we got a writable tmpdir, write to disk
        push ( @{ $self->{'AttachmentDirs'} ||= [] }, $tmpdir );
        $parser->output_dir($tmpdir);
        $parser->filer->ignore_filename(1);

        # Set up the prefix for files with auto-generated names:
        $parser->output_prefix("part");

        # From the MIME::Parser docs:
        # "Normally, tmpfiles are created when needed during parsing, and destroyed automatically when they go out of scope"
        # Turns out that the default is to recycle tempfiles
        # Temp files should never be recycled, especially when running under perl taint checking

        $parser->tmp_recycling(0) if $parser->can('tmp_recycling');
    } else {
        # Otherwise, fall back to storing it in memory
        $parser->output_to_core(1);
        $parser->tmp_to_core(1);
        $parser->use_inner_files(1);
    }

}

=head2 ParseEmailAddress string

Returns a list of Email::Address objects
Works around the bug that Email::Address 1.889 and earlier
doesn't handle local-only email addresses (when users pass
in just usernames on the RT system in fields that expect
Email Addresses)

We don't handle the case of 
bob, fred@bestpractical.com 
because we don't want to fail parsing
bob, "Falcone, Fred" <fred@bestpractical.com>
The next release of Email::Address will have a new method
we can use that removes the bandaid

=cut

use Email::Address::List;

sub ParseEmailAddress {
    my $self = shift;
    my $address_string = shift;

    # Some broken mailers send:  ""Vincent, Jesse"" <jesse@fsck.com>. Hate
    $address_string =~ s/\"\"(.*?)\"\"/\"$1\"/g;

    my @list = Email::Address::List->parse(
        $address_string,
        skip_comments => 1,
        skip_groups => 1,
    );
    my $logger = sub { RT->Logger->error(
        "Unable to parse an email address from $address_string: ". shift
    ) };

    my @addresses;
    foreach my $e ( @list ) {
        if ($e->{'type'} eq 'mailbox') {
            if ($e->{'not_ascii'}) {
                $logger->($e->{'value'} ." contains not ASCII values");
                next;
            }
            push @addresses, $e->{'value'}
        } elsif ( $e->{'value'} =~ /^\s*(\w+)\s*$/ ) {
            my $user = RT::User->new( RT->SystemUser );
            $user->Load( $1 );
            if ($user->id) {
                push @addresses, Email::Address->new($user->Name, $user->EmailAddress);
            } else {
                $logger->($e->{'value'} ." is not a valid email address and is not user name");
            }
        } else {
            $logger->($e->{'value'} ." is not a valid email address");
        }
    }

    $self->CleanupAddresses(@addresses);

    return @addresses;
}

=head2 CleanupAddresses ARRAY

Massages an array of L<Email::Address> objects to make their email addresses
more palatable.

Currently this strips off surrounding single quotes around C<< ->address >> and
B<< modifies the L<Email::Address> objects in-place >>.

Returns the list of objects for convienence in C<map>/C<grep> chains.

=cut

sub CleanupAddresses {
    my $self = shift;

    for my $addr (@_) {
        next unless defined $addr;
        # Outlook sometimes sends addresses surrounded by single quotes;
        # clean them all up
        if ((my $email = $addr->address) =~ s/^'(.+)'$/$1/) {
            $addr->address($email);
        }
    }
    return @_;
}

=head2 RescueOutlook 

Outlook 2007/2010 have a bug when you write an email with the html format.
it will send a 'multipart/alternative' with both 'text/plain' and 'text/html'
in it.  it's cool to have a 'text/plain' part, but the problem is the part is
not so right: all the "\n" in your main message will become "\n\n" :/

this method will fix this bug, i.e. replaces "\n\n" to "\n".
return 1 if it does find the problem in the entity and get it fixed.

=cut


sub RescueOutlook {
    my $self = shift;
    my $mime = $self->Entity();

    return unless $mime && $self->LooksLikeMSEmail($mime);

    my $text_part;
    if ( $mime->head->get('Content-Type') =~ m{multipart/mixed} ) {
        my $first = $mime->parts(0);
        if ( $first->head->get('Content-Type') =~ m{multipart/alternative} )
        {
            my $inner_first = $first->parts(0);
            if ( $inner_first->head->get('Content-Type') =~ m{text/plain} )
            {
                $text_part = $inner_first;
            }
        }
    }
    elsif ( $mime->head->get('Content-Type') =~ m{multipart/alternative} ) {
        my $first = $mime->parts(0);
        if ( $first->head->get('Content-Type') =~ m{text/plain} ) {
            $text_part = $first;
        }
    }

    # Add base64 since we've seen examples of double newlines with
    # this type too. Need an example of a multi-part base64 to
    # handle that permutation if it exists.
    elsif ( ($mime->head->get('Content-Transfer-Encoding')||'') =~ m{base64} ) {
        $text_part = $mime;    # Assuming single part, already decoded.
    }

    if ($text_part) {

        # use the unencoded string
        my $content = $text_part->bodyhandle->as_string;
        if ( $content =~ s/\n\n/\n/g ) {

            # Outlook puts a space on extra newlines, remove it
            $content =~ s/\ +$//mg;

            # only write only if we did change the content
            if ( my $io = $text_part->open("w") ) {
                $io->print($content);
                $io->close;
                $RT::Logger->debug(
                    "Removed extra newlines from MS Outlook message.");
                return 1;
            }
            else {
                $RT::Logger->error("Can't write to body to fix newlines");
            }
        }
    }

    return;
}

=head1 LooksLikeMSEmail

Try to determine if the current email may have
come from MS Outlook or gone through Exchange, and therefore
may have extra newlines added.

=cut

sub LooksLikeMSEmail {
    my $self = shift;
    my $mime = shift;

    my $mailer = $mime->head->get('X-Mailer');

    # 12.0 is outlook 2007, 14.0 is 2010
    return 1 if ( $mailer && $mailer =~ /Microsoft(?:.*?)Outlook 1[2-4]\./ );

    if ( RT->Config->Get('CheckMoreMSMailHeaders') ) {

        # Check for additional headers that might
        # indicate this came from Outlook or through Exchange.
        # A sample we received had the headers X-MS-Has-Attach: and
        # X-MS-Tnef-Correlator: and both had no value.

        my @tags = $mime->head->tags();
        return 1 if grep { /^X-MS-/ } @tags;
    }

    return 0;    # Doesn't look like MS email.
}

sub DESTROY {
    my $self = shift;
    File::Path::rmtree([@{$self->{'AttachmentDirs'}}],0,1)
        if $self->{'AttachmentDirs'};
}



RT::Base->_ImportOverlays();

1;
