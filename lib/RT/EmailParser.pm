# BEGIN BPS TAGGED BLOCK
# 
# COPYRIGHT:
#  
# This software is Copyright (c) 1996-2004 Best Practical Solutions, LLC 
#                                          <jesse.com>
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
# Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
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
# END BPS TAGGED BLOCK
package RT::EmailParser;


use base qw/RT::Base/;

use strict;
use Mail::Address;
use MIME::Entity;
use MIME::Head;
use MIME::Parser;
use File::Temp qw/tempdir/;

=head1 NAME

  RT::EmailParser - helper functions for parsing parts from incoming
  email messages

=head1 SYNOPSIS


=head1 DESCRIPTION


=begin testing

ok(require RT::EmailParser);

=end testing


=head1 METHODS

=head2 new


=cut

sub new  {
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my $self  = {};
  bless ($self, $class);
  return $self;
}


# {{{ sub SmartParseMIMEEntityFromScalar

=head2 SmartParseMIMEEntityFromScalar { Message => SCALAR_REF, Decode => BOOL }

Parse a message stored in a scalar from scalar_ref

=cut

sub SmartParseMIMEEntityFromScalar {
    my $self = shift;
    my %args = ( Message => undef, Decode => 1, @_ );

    my ( $fh, $temp_file );
    eval {

        for ( 1 .. 10 ) {

            # on NFS and NTFS, it is possible that tempfile() conflicts
            # with other processes, causing a race condition. we try to
            # accommodate this by pausing and retrying.
            last
              if ( $fh, $temp_file ) =
              eval { File::Temp::tempfile( undef, UNLINK => 0 ) };
            sleep 1;
        }
        if ($fh) {

            #thank you, windows                      
            binmode $fh;
            $fh->autoflush(1);
            print $fh $args{'Message'};
            close($fh);
            if ( -f $temp_file ) {

                # We have to trust the temp file's name -- untaint it
                $temp_file =~ /(.*)/;
                $self->ParseMIMEEntityFromFile( $1, $args{'Decode'} );
                unlink($1);
            }
        }
    };

    #If for some reason we weren't able to parse the message using a temp file
    # try it with a scalar
    if ( $@ || !$self->Entity ) {
        $self->ParseMIMEEntityFromScalar( $args{'Message'}, $args{'Decode'} );
    }

}

# }}}

# {{{ sub ParseMIMEEntityFromSTDIN

=head2 ParseMIMEEntityFromSTDIN

Parse a message from standard input

=cut

sub ParseMIMEEntityFromSTDIN {
    my $self = shift;
    my $postprocess = (@_ ? shift : 1);
    return $self->ParseMIMEEntityFromFileHandle(\*STDIN, $postprocess);
}

# }}}

# {{{ ParseMIMEEntityFromScalar

=head2 ParseMIMEEntityFromScalar  $message

Takes either a scalar or a reference to a scalr which contains a stringified MIME message.
Parses it.

Returns true if it wins.
Returns false if it loses.

=cut

sub ParseMIMEEntityFromScalar {
    my $self = shift;
    my $message = shift;
    my $postprocess = (@_ ? shift : 1);
    $self->_ParseMIMEEntity($message,'parse_data', $postprocess);
}

# }}}

# {{{ ParseMIMEEntityFromFilehandle *FH

=head2 ParseMIMEEntityFromFilehandle *FH

Parses a mime entity from a filehandle passed in as an argument

=cut

sub ParseMIMEEntityFromFileHandle {
    my $self = shift;
    my $filehandle = shift;
    my $postprocess = (@_ ? shift : 1);
    $self->_ParseMIMEEntity($filehandle,'parse', $postprocess);
}

# }}}

# {{{ ParseMIMEEntityFromFile

=head2 ParseMIMEEntityFromFile 

Parses a mime entity from a filename passed in as an argument

=cut

sub ParseMIMEEntityFromFile {
    my $self = shift;
    my $file = shift;
    my $postprocess = (@_ ? shift : 1);
    $self->_ParseMIMEEntity($file,'parse_open',$postprocess);
}

# }}}

# {{{ _ParseMIMEEntity
sub _ParseMIMEEntity {
    my $self = shift;
    my $message = shift;
    my $method = shift;
    my $postprocess = shift;
    # Create a new parser object:

    my $parser = MIME::Parser->new();
    $self->_SetupMIMEParser($parser);


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
    if ($postprocess) {
    $self->_PostProcessNewEntity() ;
    }

}

# }}}

# {{{ _PostProcessNewEntity 

=head2 _PostProcessNewEntity

cleans up and postprocesses a newly parsed MIME Entity

=cut

sub _PostProcessNewEntity {
    my $self = shift;

    #Now we've got a parsed mime object. 

    # try to convert text parts into utf-8 charset
    RT::I18N::SetMIMEEntityToEncoding($self->{'entity'}, 'utf-8');


    # Unfold headers that are have embedded newlines
    $self->Head->unfold;


}

# }}}

# {{{ LookupExternalUserInfo


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


=item LookupExternalUserInfo

 LookupExternalUserInfo is a site-definable method for synchronizing
 incoming users with an external data source. 

 This routine takes a tuple of EmailAddress and FriendlyName
    EmailAddress is the user's email address, ususally taken from
        an email message's From: header.
    FriendlyName is a freeform string, ususally taken from the "comment" 
        portion of an email message's From: header.

 It returns (FoundInExternalDatabase, ParamHash);

   FoundInExternalDatabase must  be set to 1 before return if the user was
   found in the external database.

   ParamHash is a Perl parameter hash which can contain at least the following
   fields. These fields are used to populate RT's users database when the user 
   is created

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

  # See RT's contributed code for examples.
  # http://www.fsck.com/pub/rt/contrib/
  return ($FoundInExternalDatabase, %params);
}

# }}}

# {{{ Accessor methods for parsed email messages

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

# }}}

# {{{ _SetupMIMEParser 

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
    
    # Set up output directory for files:

    my $tmpdir = File::Temp::tempdir( TMPDIR => 1, CLEANUP => 1 );
    push ( @{ $self->{'AttachmentDirs'} }, $tmpdir );
    $parser->output_dir($tmpdir);
    $parser->filer->ignore_filename(1);

    #If someone includes a message, extract it
    $parser->extract_nested_messages(1);

    $parser->extract_uuencode(1);    ### default is false

    # Set up the prefix for files with auto-generated names:
    $parser->output_prefix("part");

    # do _not_ store each msg as in-core scalar;

    $parser->output_to_core(0);

    # From the MIME::Parser docs:
    # "Normally, tmpfiles are created when needed during parsing, and destroyed automatically when they go out of scope"
    # Turns out that the default is to recycle tempfiles
    # Temp files should never be recycled, especially when running under perl taint checking
    
    $parser->tmp_recycling(0);

}

# }}}

sub DESTROY {
    my $self = shift;
    File::Path::rmtree([@{$self->{'AttachmentDirs'}}],0,1);
}



eval "require RT::EmailParser_Vendor";
die $@ if ($@ && $@ !~ qr{^Can't locate RT/EmailParser_Vendor.pm});
eval "require RT::EmailParser_Local";
die $@ if ($@ && $@ !~ qr{^Can't locate RT/EmailParser_Local.pm});

1;
