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
## Portions Copyright 2000 Tobias Brox <tobix@fsck.com>

## This is a library of static subs to be used by the Mason web
## interface to RT

=head1 name

RT::Interface::Web


=cut

use strict;
use warnings;

package RT::Interface::Web;
use RT::System;
use RT::SavedSearches;
use URI qw();

# {{{ escape_utf8

=head2 escape_utf8 SCALARREF

does a css-busting but minimalist escaping of whatever html you're passing in.

=cut

sub escape_utf8 {
    my $ref = shift;
    return unless defined $$ref;

    $$ref =~ s/&/&#38;/g;
    $$ref =~ s/</&lt;/g;
    $$ref =~ s/>/&gt;/g;
    $$ref =~ s/\(/&#40;/g;
    $$ref =~ s/\)/&#41;/g;
    $$ref =~ s/"/&#34;/g;
    $$ref =~ s/'/&#39;/g;
}

# }}}

# {{{ escape_uri

=head2 escape_uri SCALARREF

Escapes URI component according to RFC2396

=cut

use Encode qw();

sub escape_uri {
    my $ref = shift;
    return unless defined $$ref;

    use bytes;
    $$ref =~ s/([^a-zA-Z0-9_.!~*'()-])/uc sprintf("%%%02X", ord($1))/eg;
}

# }}}

# {{{ web_canonicalize_info

=head2 web_canonicalize_info();

Different web servers set different environmental varibles. This
function must return something suitable for REMOTE_USER. By default,
just downcase $ENV{'REMOTE_USER'}

=cut

sub web_canonicalize_info {
    return $ENV{'REMOTE_USER'} ? lc $ENV{'REMOTE_USER'} : $ENV{'REMOTE_USER'};
}

# }}}

# {{{ web_external_auto_info

=head2 web_external_auto_info($user);

Returns a hash of user attributes, used when WebExternalAuto is set.

=cut

sub web_external_auto_info {
    my $user = shift;

    my %user_info;

    $user_info{'privileged'} = 1;

    if ( $^O !~ /^(?:riscos|MacOS|MSWin32|dos|os2)$/ ) {

        # Populate fields with information from Unix /etc/passwd

        my ( $comments, $real_name ) = ( getpwnam($user) )[ 5, 6 ];
        $user_info{'comments'}  = $comments  if defined $comments;
        $user_info{'real_name'} = $real_name if defined $real_name;
    } elsif ( $^O eq 'MSWin32' and eval 'use Net::AdminMisc; 1' ) {

        # Populate fields with information from NT domain controller
    }

    # and return the wad of stuff
    return {%user_info};
}

# }}}

=head2 redirect URL

This routine ells the current user's browser to redirect to URL.  
Additionally, it unties the user's currently active session, helping to avoid 
A bug in Apache::Session 1.81 and earlier which clobbers sessions if we try to use 
a cached DBI statement handle twice at the same time.

=cut

sub redirect {
    my $redir_to   = shift;
    my $uri        = URI->new($redir_to);
    my $server_uri = URI->new( RT->config->get('WebURL') );

    # If the user is coming in via a non-canonical
    # hostname, don't redirect them to the canonical host,
    # it will just upset them (and invalidate their credentials)
    if (   $uri->host eq $server_uri->host
        && $uri->port eq $server_uri->port )
    {
        $uri->host( $ENV{'HTTP_HOST'} );
        $uri->port( $ENV{'SERVER_PORT'} );
    }

    Jifty->web->_redirect( $uri->canonical );
}

=head2 StaticFileheaders 

Send the browser a few headers to try to get it to (somewhat agressively)
cache RT's static Javascript and CSS files.

This routine could really use _accurate_ heuristics. (XXX TODO)

=cut

sub static_file_headers {
    my $date = RT::Date->new( current_user => RT->system_user );

    # make cache public
    $HTML::Mason::Commands::r->headers_out->{'Cache-Control'}
        = 'max-age=259200, public';

    # Expire things in a month.
    $date->set( value => time + 30 * 24 * 60 * 60 );
    $HTML::Mason::Commands::r->headers_out->{'Expires'} = $date->rfc2616;

# if we set 'Last-Modified' then browser request a comp using 'If-Modified-Since'
# request, but we don't handle it and generate full reply again
# Last modified at server start time
# $date->set( value => $^T );
# $HTML::Mason::Commands::r->headers_out->{'Last-Modified'} = $date->rfc2616;
}

package HTML::Mason::Commands;

use vars qw/$r $m %session/;

# {{{ loc

=head2 loc ARRAY

loc is a nice clean global routine which calls Jifty->web->current_user->_()
with whatever it's called with. If there is no Jifty->web->current_user, 
it creates a temporary user, so we have something to get a localisation handle
through

=cut

sub loc {

    return _(@_);
}

# }}}

# {{{ sub abort
# Error - calls Error and aborts
sub abort {

    if (   $session{'ErrorDocument'}
        && $session{'ErrorDocumentType'} )
    {
        $r->content_type( $session{'ErrorDocumentType'} );
        $m->comp( $session{'ErrorDocument'}, Why => shift );
        $m->abort;
    } else {
        $m->comp( "/Elements/Error", Why => shift );
        $m->abort;
    }
}

# }}}

# {{{ sub create_ticket

=head2 create_ticket ARGS

Create a new ticket, using Mason's %ARGS.  returns @results.

=cut

sub create_ticket {
    my %ARGS = (@_);

    my (@Actions);

    my $Ticket = RT::Model::Ticket->new();

    my $Queue = RT::Model::Queue->new();
    unless ( $Queue->load( $ARGS{'queue'} ) ) {
        abort('Queue not found');
    }

    unless ( $Queue->current_user_has_right('CreateTicket') ) {
        abort('You have no permission to create tickets in that queue.');
    }

    my $due = RT::Date->new();
    $due->set( format => 'unknown', value => $ARGS{'Due'} );
    my $starts = RT::Date->new();
    $starts->set( format => 'unknown', value => $ARGS{'starts'} );

    my $mime_obj = make_mime_entity(
        subject => $ARGS{'subject'},
        From    => $ARGS{'From'},
        cc      => $ARGS{'cc'},
        Body    => $ARGS{'content'},
        type    => $ARGS{'content_type'},
    );

    if ( $ARGS{'Attachments'} ) {
        my $rv = $mime_obj->make_multipart;
        Jifty->log->error("Couldn't make multipart message")
            if !$rv || $rv !~ /^(?:DONE|ALREADY)$/;

        foreach ( values %{ $ARGS{'Attachments'} } ) {
            unless ($_) {
                Jifty->log->error("Couldn't add empty attachemnt");
                next;
            }
            $mime_obj->add_part($_);
        }
    }

    foreach my $argument (qw(encrypt sign)) {
        $mime_obj->head->add( "X-RT-$argument" => $ARGS{$argument} )
            if defined $ARGS{$argument};
    }

    my %create_args = (
        type => $ARGS{'type'} || 'ticket',
        queue => $ARGS{'queue'},
        owner => $ARGS{'owner'},

        # note: name change
        requestor        => $ARGS{'requestors'},
        cc               => $ARGS{'cc'},
        admin_cc          => $ARGS{'admin_cc'},
        initial_priority => $ARGS{'initial_priority'},
        final_priority   => $ARGS{'final_priority'},
        time_left        => $ARGS{'time_left'},
        time_estimated   => $ARGS{'time_estimated'},
        time_worked      => $ARGS{'time_worked'},
        subject          => $ARGS{'subject'},
        Status           => $ARGS{'Status'},
        Due              => $due->iso,
        starts           => $starts->iso,
        mime_obj          => $mime_obj
    );

    my @temp_squelch;
    foreach my $type (qw(requestor cc admin_cc)) {
        push @temp_squelch, map $_->address,
            Mail::Address->parse( $create_args{$type} )
            if grep $_ eq $type || $_ eq ( $type . 's' ),
            @{ $ARGS{'SkipNotification'} || [] };

    }

    if (@temp_squelch) {
        require RT::ScripAction::SendEmail;
        RT::ScripAction::SendEmail->squelch_mail_to(
            RT::ScripAction::SendEmail->squelch_mail_to,
            @temp_squelch );
    }

    if ( $ARGS{'AttachTickets'} ) {
        require RT::ScripAction::SendEmail;
        RT::ScripAction::SendEmail->attach_tickets(
            RT::ScripAction::SendEmail->attach_tickets,
            ref $ARGS{'AttachTickets'}
            ? @{ $ARGS{'AttachTickets'} }
            : ( $ARGS{'AttachTickets'} )
        );
    }

    foreach my $arg ( keys %ARGS ) {
        next if $arg =~ /-(?:Magic|category)$/;

        if ( $arg =~ /^object-RT::Model::Transaction--CustomField-/ ) {
            $create_args{$arg} = $ARGS{$arg};
        }

        # object-RT::Model::Ticket--CustomField-3-Values
        elsif ( $arg =~ /^object-RT::Model::Ticket--CustomField-(\d+)(.*?)$/ )
        {
            my $cfid = $1;

            my $cf = RT::Model::CustomField->new();
            $cf->load($cfid);
            unless ( $cf->id ) {
                Jifty->log->error( "Couldn't load custom field #" . $cfid );
                next;
            }

            if ( $arg =~ /-Upload$/ ) {
                $create_args{"custom_field-$cfid"} = _uploaded_file($arg);
                next;
            }

            my $type = $cf->type;

            my @values = ();
            if ( ref $ARGS{$arg} eq 'ARRAY' ) {
                @values = @{ $ARGS{$arg} };
            } elsif ( $type =~ /text/i ) {
                @values = ( $ARGS{$arg} );
            } else {
                @values = split /\r*\n/, $ARGS{$arg} || '';
            }
            @values = grep length, map {
                s/\r+\n/\n/g;
                s/^\s+//;
                s/\s+$//;
                $_;
                }
                grep defined, @values;

            $create_args{"custom_field-$cfid"} = \@values;
        }
    }

    # turn new link lists into arrays, and pass in the proper arguments
    my %map = (
        'new-DependsOn' => 'DependsOn',
        'DependsOn-new' => 'DependedOnBy',
        'new-MemberOf'  => 'Parents',
        'MemberOf-new'  => 'Children',
        'new-RefersTo'  => 'RefersTo',
        'RefersTo-new'  => 'ReferredToBy',
    );
    foreach my $key ( keys %map ) {
        next unless $ARGS{$key};
        $create_args{ $map{$key} } = [ grep $_, split ' ', $ARGS{$key} ];

    }

    my ( $id, $Trans, $ErrMsg ) = $Ticket->create(%create_args);
    unless ($id) {
        abort($ErrMsg);
    }

    push( @Actions, split( "\n", $ErrMsg ) );
    unless ( $Ticket->current_user_has_right('ShowTicket') ) {
        abort(    "No permission to view newly Created ticket #"
                . $Ticket->id
                . "." );
    }
    return ( $Ticket, @Actions );

}

# }}}

# {{{ sub load_ticket - loads a ticket

=head2  load_ticket id

Takes a ticket id as its only variable. if it's handed an array, it takes
the first value.

Returns an RT::Model::Ticket object as the current user.

=cut

sub load_ticket {
    my $id = shift;

    if ( ref($id) eq "ARRAY" ) {
        $id = $id->[0];
    }

    unless ($id) {
        abort("No ticket specified");
    }

    my $Ticket = RT::Model::Ticket->new();
    $Ticket->load($id);
    unless ( $Ticket->id ) {
        abort("Could not load ticket $id");
    }
    return $Ticket;
}

# }}}

# {{{ sub process_update_message

=head2 process_update_message

Takes paramhash with fields args_ref, ticket_obj and SkipSignatureOnly.

Don't write message if it only contains current user's signature and
SkipSignatureOnly argument is true. Function anyway adds attachments
and updates time worked field even if skips message. The default value
is true.

=cut

sub process_update_message {

    #TODO document what else this takes.
    my %args = (
        args_ref           => undef,
        ticket_obj        => undef,
        SkipSignatureOnly => 1,
        @_
    );

    if ( $args{args_ref}->{'UpdateAttachments'}
        && !keys %{ $args{args_ref}->{'UpdateAttachments'} } )
    {
        delete $args{args_ref}->{'UpdateAttachments'};
    }

    #Make the update content have no 'weird' newlines in it
    return ()
        unless $args{args_ref}->{'UpdateTimeWorked'}
            || $args{args_ref}->{'UpdateAttachments'}
            || $args{args_ref}->{'update_content'};

    $args{args_ref}->{'update_content'} =~ s/\r+\n/\n/g
        if $args{args_ref}->{'update_content'};

    # skip updates if the content contains only user's signature
    # and we don't update other fields
    if ( $args{'SkipSignatureOnly'} ) {
        my $sig = $args{'ticket_obj'}->current_user->user_object->signature
            || '';
        $sig =~ s/^\s*|\s*$//g;
        if ( $args{args_ref}->{'update_content'} =~ /^\s*(--)?\s*\Q$sig\E\s*$/ )
        {
            return ()
                unless $args{args_ref}->{'UpdateTimeWorked'}
                    || $args{args_ref}->{'UpdateAttachments'};

            # we have to create transaction, but we don't create attachment
            # XXX: this couldn't work as expected
            $args{args_ref}->{'update_content'} = '';
        }
    }

    if ( $args{args_ref}->{'Updatesubject'} eq $args{'ticket_obj'}->subject ) {
        $args{args_ref}->{'Updatesubject'} = undef;
    }

    my $Message = make_mime_entity(
        subject => $args{args_ref}->{'Updatesubject'},
        Body    => $args{args_ref}->{'update_content'},
        type    => $args{args_ref}->{'Updatecontent_type'},
    );

    $Message->head->add(
        'Message-ID' => RT::Interface::Email::gen_message_id(
            Ticket => $args{'ticket_obj'},
        )
    );
    my $old_txn = RT::Model::Transaction->new();
    if ( $args{args_ref}->{'QuoteTransaction'} ) {
        $old_txn->load( $args{args_ref}->{'QuoteTransaction'} );
    } else {
        $old_txn = $args{ticket_obj}->transactions->first();
    }

    if ( my $msg = $old_txn->message->first ) {
        RT::Interface::Email::set_in_reply_to(
            Message   => $Message,
            InReplyTo => $msg
        );
    }

    if ( $args{args_ref}->{'UpdateAttachments'} ) {
        $Message->make_multipart;
        $Message->add_part($_)
            foreach values %{ $args{args_ref}->{'UpdateAttachments'} };
    }

    if ( $args{args_ref}->{'AttachTickets'} ) {
        require RT::ScripAction::SendEmail;
        RT::ScripAction::SendEmail->attach_tickets(
            RT::ScripAction::SendEmail->attach_tickets,
            ref $args{args_ref}->{'AttachTickets'}
            ? @{ $args{args_ref}->{'AttachTickets'} }
            : ( $args{args_ref}->{'AttachTickets'} )
        );
    }

    my $bcc = $args{args_ref}->{'UpdateBcc'};
    my $cc  = $args{args_ref}->{'update_cc'};

    my %message_args = (
        cc_message_to  => $cc,
        bcc_message_to => $bcc,
        sign         => $args{args_ref}->{'sign'},
        encrypt      => $args{args_ref}->{'encrypt'},
        mime_obj      => $Message,
        time_taken    => $args{args_ref}->{'UpdateTimeWorked'}
    );

    unless ( $args{'ARGRef'}->{'UpdateIgnoreAddressCheckboxes'} ) {
        foreach my $key ( keys %{ $args{args_ref} } ) {
            next unless $key =~ /^Update(cc|Bcc)-(.*)$/;

            my $var   = ucfirst($1) . 'MessageTo';
            my $value = $2;
            if ( $message_args{$var} ) {
                $message_args{$var} .= ", $value";
            } else {
                $message_args{$var} = $value;
            }
        }
    }

    my @results;
    if ( $args{args_ref}->{'UpdateType'} =~ /^(private|public)$/ ) {
        my ( $Transaction, $description, $object )
            = $args{ticket_obj}->comment(%message_args);
        push( @results, $description );
        $object->update_custom_fields( args_ref => $args{args_ref} ) if $object;
    } elsif ( $args{args_ref}->{'UpdateType'} eq 'response' ) {
        my ( $Transaction, $description, $object )
            = $args{ticket_obj}->correspond(%message_args);
        push( @results, $description );
        $object->update_custom_fields( args_ref => $args{args_ref} ) if $object;
    } else {
        push( @results,
            _("Update type was neither correspondence nor comment.") . " "
                . _("Update not recorded.") );
    }
    return @results;
}

# }}}

# {{{ sub make_mime_entity

=head2 make_mime_entity PARAMHASH

Takes a paramhash subject, Body and AttachmentFieldname.

Also takes Form, cc and type as optional paramhash keys.

  Returns a MIME::Entity.

=cut

sub make_mime_entity {

    #TODO document what else this takes.
    my %args = (
        subject             => undef,
        From                => undef,
        cc                  => undef,
        Body                => undef,
        AttachmentFieldname => undef,
        type                => undef,
        @_,
    );
    my $Message = MIME::Entity->build(
        Type    => 'multipart/mixed',
        subject => $args{'subject'} || "",
        From    => $args{'From'},
        cc      => $args{'cc'},
    );

    if ( defined $args{'Body'} && length $args{'Body'} ) {

        # Make the update content have no 'weird' newlines in it
        $args{'Body'} =~ s/\r\n/\n/gs;

        # MIME::Head is not happy in utf-8 domain.  This only happens
        # when processing an incoming email (so far observed).
        no utf8;
        use bytes;
        $Message->attach(
            Type => $args{'type'} || 'text/plain',
            Charset => 'UTF-8',
            Data    => $args{'Body'},
        );
    }

    if ( $args{'AttachmentFieldname'} ) {

        my $cgi_object = Jifty->handler->cgi;

        if ( my $filehandle
            = $cgi_object->upload( $args{'AttachmentFieldname'} ) )
        {

            my ( @content, $buffer );
            while ( my $bytesread = read( $filehandle, $buffer, 4096 ) ) {
                push @content, $buffer;
            }

            my $uploadinfo = $cgi_object->uploadInfo($filehandle);

            # Prefer the cached name first over CGI.pm stringification.
            my $filename = $RT::Mason::CGI::Filename;
            $filename = "$filehandle" unless defined($filename);

            $filename =~ s#^.*[\\/]##;

            $Message->attach(
                Type     => $uploadinfo->{'Content-Type'},
                Filename => Encode::decode_utf8($filename),
                Data     => \@content,
            );
        }
    }

    $Message->make_singlepart;
    RT::I18N::set_mime_entity_to_utf8($Message)
        ;    # convert text parts into utf-8

    return ($Message);

}

# }}}

# {{{ sub parse_date_to_iso

=head2 parse_date_to_iso

Takes a date in an arbitrary format.
Returns an ISO date and time in GMT

=cut

sub parse_date_to_iso {
    my $date = shift;

    my $date_obj = RT::Date->new();
    $date_obj->set(
        format => 'unknown',
        Value  => $date
    );
    return ( $date_obj->iso );
}

# }}}

# {{{ sub process_acl_changes

sub process_acl_changes {
    my $ARGSref = shift;

    #XXX: why don't we get ARGSref like in other Process* subs?

    my @results;

    foreach my $arg ( keys %$ARGSref ) {
        next
            unless (
            $arg =~ /^(grant_right|revoke_right)-(\d+)-(.+?)-(\d+)$/ );

        my ( $method, $principal_id, $object_type, $object_id )
            = ( $1, $2, $3, $4 );

        my @Rights;
        if ( UNIVERSAL::isa( $ARGSref->{$arg}, 'ARRAY' ) ) {
            @Rights = @{ $ARGSref->{$arg} };
        } else {
            @Rights = $ARGSref->{$arg};
        }
        @Rights = grep $_, @Rights;
        next unless @Rights;

        my $principal = RT::Model::Principal->new();
        $principal->load($principal_id);

        my $obj;
        if ( $object_type eq 'RT::System' ) {
            $obj = RT->system;
        } elsif ( $RT::Model::ACE::OBJECT_TYPES{$object_type} ) {
            $obj = $object_type->new();
            $obj->load($object_id);
            unless ( $obj->id ) {
                Jifty->log->error("couldn't load $object_type #$object_id");
                next;
            }
        } else {
            Jifty->log->error("object type '$object_type' is incorrect");
            push( @results,
                      _("System Error") . ': '
                    . _( "Rights could not be granted for %1", $object_type )
            );
            next;
        }

        foreach my $right (@Rights) {
            my ( $val, $msg )
                = $principal->$method( object => $obj, right => $right );
            push( @results, $msg );
        }
    }

    return (@results);
}

# }}}

# {{{ sub update_record_obj

=head2 update_record_obj ( args_ref => \%ARGS, object => RT::Record, attributes_ref => \@attribs)

@attribs is a list of ticket fields to check and update if they differ from the  B<object>'s current values. args_ref is a ref to HTML::Mason's %ARGS.

Returns an array of success/failure messages

=cut

sub update_record_object {
    my %args = (
        args_ref         => undef,
        attributes_ref   => undef,
        object          => undef,
        AttributePrefix => undef,
        @_
    );

    my $object  = $args{'object'};
    my @results = $object->update(
        attributes_ref   => $args{'attributes_ref'},
        args_ref         => $args{'args_ref'},
        AttributePrefix => $args{'AttributePrefix'},
    );

    return (@results);
}

# }}}

# {{{ sub process_custom_field_updates

sub process_custom_field_updates {
    my %args = (
        CustomFieldObj => undef,
        args_ref        => undef,
        @_
    );

    my $object  = $args{'CustomFieldObj'};
    my $args_ref = $args{'args_ref'};

    my @attribs = qw(name type description queue sort_order);
    my @results = update_record_object(
        attributes_ref => \@attribs,
        object        => $object,
        args_ref       => $args_ref
    );

    my $prefix = "CustomField-" . $object->id;
    if ( $args_ref->{"$prefix-AddValue-name"} ) {
        my ( $addval, $addmsg ) = $object->add_value(
            name        => $args_ref->{"$prefix-AddValue-name"},
            description => $args_ref->{"$prefix-AddValue-Description"},
            sort_order   => $args_ref->{"$prefix-AddValue-sort_order"},
        );
        push( @results, $addmsg );
    }

    my @delete_values
        = ( ref $args_ref->{"$prefix-DeleteValue"} eq 'ARRAY' )
        ? @{ $args_ref->{"$prefix-DeleteValue"} }
        : ( $args_ref->{"$prefix-DeleteValue"} );

    foreach my $id (@delete_values) {
        next unless defined $id;
        my ( $err, $msg ) = $object->delete_value($id);
        push( @results, $msg );
    }

    my $vals = $object->values();
    while ( my $cfv = $vals->next() ) {
        if ( my $so = $args_ref->{ "$prefix-sort_order" . $cfv->id } ) {
            if ( $cfv->sort_order != $so ) {
                my ( $err, $msg ) = $cfv->set_sort_order($so);
                push( @results, $msg );
            }
        }
    }

    return (@results);
}

# }}}

# {{{ sub process_ticket_basics

=head2 process_ticket_basics ( ticket_obj => $Ticket, args_ref => \%ARGS );

Returns an array of results messages.

=cut

sub process_ticket_basics {

    my %args = (
        ticket_obj => undef,
        args_ref    => undef,
        @_
    );

    my $ticket_obj = $args{'ticket_obj'};
    my $args_ref    = $args{'args_ref'};

    # {{{ Set basic fields
    my @attribs = qw(
        subject
        final_priority
        priority
        time_estimated
        time_worked
        time_left
        type
        status
        queue
    );

    if ( $args_ref->{'queue'} and ( $args_ref->{'queue'} !~ /^(\d+)$/ ) ) {
        my $tempqueue
            = RT::Model::Queue->new( current_user => RT->system_user );
        $tempqueue->load( $args_ref->{'queue'} );
        if ( $tempqueue->id ) {
            $args_ref->{'queue'} = $tempqueue->id;
        }
    }

    # Status isn't a field that can be set to a null value.
    # RT core complains if you try
    delete $args_ref->{'Status'} unless $args_ref->{'Status'};

    my @results = update_record_object(
        attributes_ref => \@attribs,
        object        => $ticket_obj,
        args_ref       => $args_ref,
    );

    # We special case owner changing, so we can use force_owner_change
    if ( $args_ref->{'owner'}
        && ( $ticket_obj->owner != $args_ref->{'owner'} ) )
    {
        my ($ChownType);
        if ( $args_ref->{'force_owner_change'} ) {
            $ChownType = "Force";
        } else {
            $ChownType = "Give";
        }

        my ( $val, $msg )
            = $ticket_obj->set_owner( $args_ref->{'owner'}, $ChownType );
        push( @results, $msg );
    }

    # }}}

    return (@results);
}

# }}}

sub process_ticket_custom_field_updates {
    my %args = @_;
    $args{'object'} = delete $args{'ticket_obj'};
    my $args_ref = { %{ $args{'args_ref'} } };

    # Build up a list of objects that we want to work with
    my %custom_fields_to_mod;
    foreach my $arg ( keys %$args_ref ) {
        if ( $arg =~ /^Ticket-(\d+-.*)/ ) {
            $args_ref->{"object-RT::Model::Ticket-$1"}
                = delete $args_ref->{$arg};
        } elsif ( $arg =~ /^CustomField-(\d+-.*)/ ) {
            $args_ref->{"object-RT::Model::Ticket--$1"}
                = delete $args_ref->{$arg};
        }
    }

    return process_object_custom_field_updates( %args, args_ref => $args_ref );
}

sub process_object_custom_field_updates {
    my %args    = @_;
    my $args_ref = $args{'args_ref'};
    my @results;

    # Build up a list of objects that we want to work with
    my %custom_fields_to_mod;
    foreach my $arg ( keys %$args_ref ) {

    # format: object-<object class>-<object id>-CustomField-<CF id>-<commands>
        next unless $arg =~ /^object-([\w:]+)-(\d*)-CustomField-(\d+)-(.*)$/;

# For each of those objects, find out what custom fields we want to work with.
        $custom_fields_to_mod{$1}{ $2 || 0 }{$3}{$4} = $args_ref->{$arg};
    }

    # For each of those objects
    foreach my $class ( keys %custom_fields_to_mod ) {
        foreach my $id ( keys %{ $custom_fields_to_mod{$class} } ) {
            my $object = $args{'object'};
            $object = $class->new()
                unless $object && ref $object eq $class;

            $object->load($id) unless ( $object->id || 0 ) == $id;
            unless ( $object->id ) {
                Jifty->log->warn("Couldn't load object $class #$id");
                next;
            }

            foreach my $cf ( keys %{ $custom_fields_to_mod{$class}{$id} } ) {
                my $CustomFieldObj = RT::Model::CustomField->new();
                $CustomFieldObj->load_by_id($cf);
                unless ( $CustomFieldObj->id ) {
                    Jifty->log->warn("Couldn't load custom field #$id");
                    next;
                }
                push @results,
                    _process_object_custom_field_updates(
                    Prefix      => "object-$class-$id-CustomField-$cf-",
                    object      => $object,
                    CustomField => $CustomFieldObj,
                    ARGS        => $custom_fields_to_mod{$class}{$id}{$cf},
                    );
            }
        }
    }
    return @results;
}

sub _process_object_custom_field_updates {
    my %args    = @_;
    my $cf      = $args{'CustomField'};
    my $cf_type = $cf->type;

    my @results;
    foreach my $arg ( keys %{ $args{'ARGS'} } ) {
        next if $arg =~ /category$/;

        # since http won't pass in a form element with a null value, we need
        # to fake it
        if ( $arg eq 'Values-Magic' ) {

          # We don't care about the magic, if there's really a values element;
            next
                if defined $args{'ARGS'}->{'value'}
                    && length $args{'ARGS'}->{'value'};
            next
                if defined $args{'ARGS'}->{'values'}
                    && length $args{'ARGS'}->{'values'};

           # "Empty" values does not mean anything for Image and Binary fields
            next if $cf_type =~ /^(?:Image|Binary)$/;

            $arg = 'values';
            $args{'ARGS'}->{'values'} = undef;
        }

        my @values = ();
        if ( ref $args{'ARGS'}->{$arg} eq 'ARRAY' ) {
            @values = @{ $args{'ARGS'}->{$arg} };
        } elsif ( $cf_type =~ /text/i ) {    # Both Text and Wikitext
            @values = ( $args{'ARGS'}->{$arg} );
        } else {
            @values = split /\r*\n/, $args{'ARGS'}->{$arg}
                if defined $args{'ARGS'}->{$arg};
        }
        @values = grep length, map {
            s/\r+\n/\n/g;
            s/^\s+//;
            s/\s+$//;
            $_;
            }
            grep defined, @values;

        if ( $arg eq 'AddValue' || $arg eq 'value' ) {
            foreach my $value (@values) {
                my ( $val, $msg ) = $args{'object'}->add_custom_field_value(
                    field => $cf->id,
                    value => $value
                );
                push( @results, $msg );
            }
        } elsif ( $arg eq 'Upload' ) {
            my $value_hash = _uploaded_file( $args{'Prefix'} . $arg ) or next;
            my ( $val, $msg )
                = $args{'object'}
                ->add_custom_field_value( %$value_hash, field => $cf, );
            push( @results, $msg );
        } elsif ( $arg eq 'delete_values' ) {
            foreach my $value (@values) {
                my ( $val, $msg )
                    = $args{'object'}->delete_custom_field_value(
                    field => $cf,
                    value => $value,
                    );
                push( @results, $msg );
            }
        } elsif ( $arg eq 'delete_value_ids' ) {
            foreach my $value (@values) {
                my ( $val, $msg )
                    = $args{'object'}->delete_custom_field_value(
                   field   => $cf,
                    value_id => $value,
                    );
                push( @results, $msg );
            }
        } elsif ( $arg eq 'values' && !$cf->repeated ) {
            my $cf_values = $args{'object'}->custom_field_values( $cf->id );

            my %values_hash;
            foreach my $value (@values) {
                if ( my $entry = $cf_values->has_entry($value) ) {
                    $values_hash{ $entry->id } = 1;
                    next;
                }

                my ( $val, $msg ) = $args{'object'}->add_custom_field_value(
                    field => $cf,
                    value => $value
                );
                push( @results, $msg );
                $values_hash{$val} = 1 if $val;
            }

            $cf_values->redo_search;
            while ( my $cf_value = $cf_values->next ) {
                next if $values_hash{ $cf_value->id };

                my ( $val, $msg )
                    = $args{'object'}->delete_custom_field_value(
                    field   => $cf,
                    value_id => $cf_value->id
                    );
                push( @results, $msg );
            }
        } elsif ( $arg eq 'values' ) {
            my $cf_values = $args{'object'}->custom_field_values( $cf->id );

            # keep everything up to the point of difference, delete the rest
            my $delete_flag;
            foreach my $old_cf ( @{ $cf_values->items_array_ref } ) {
                if (    !$delete_flag
                    and @values
                    and $old_cf->content eq $values[0] )
                {
                    shift @values;
                    next;
                }

                $delete_flag ||= 1;
                $old_cf->delete;
            }

            # now add/replace extra things, if any
            foreach my $value (@values) {
                my ( $val, $msg ) = $args{'object'}->add_custom_field_value(
                    field => $cf,
                    value => $value
                );
                push( @results, $msg );
            }
        } else {
            push(
                @results,
                _(  "User asked for an unknown update type for custom field %1 for %2 object #%3",
                    $cf->name, ref $args{'object'},
                    $args{'object'}->id
                )
            );
        }
    }
    return @results;
}

# {{{ sub process_ticket_watchers

=head2 process_ticket_watchers ( ticket_obj => $Ticket, args_ref => \%ARGS );

Returns an array of results messages.

=cut

sub process_ticket_watchers {
    my %args = (
        ticket_obj => undef,
        args_ref    => undef,
        @_
    );
    my (@results);

    my $Ticket  = $args{'ticket_obj'};
    my $args_ref = $args{'args_ref'};

    # Munge watchers

    foreach my $key ( keys %$args_ref ) {

        # Delete deletable watchers
        if ( $key =~ /^Ticket-DeleteWatcher-Type-(.*)-Principal-(\d+)$/ ) {
            my ( $code, $msg ) = $Ticket->delete_watcher(
                principal_id => $2,
                type         => $1
            );
            push @results, $msg;
        }

        # Delete watchers in the simple style demanded by the bulk manipulator
        elsif ( $key =~ /^Delete(requestor|cc|admin_cc)$/ ) {
            my ( $code, $msg ) = $Ticket->delete_watcher(
                email => $args_ref->{$key},
                type  => $1
            );
            push @results, $msg;
        }

        # Add new wathchers by email address
        elsif ( ( $args_ref->{$key} || '' ) =~ /^(?:admin_cc|cc|requestor)$/
            and $key =~ /^WatcherTypeEmail(\d*)$/ )
        {

            #They're in this order because otherwise $1 gets clobbered :/
            my ( $code, $msg ) = $Ticket->add_watcher(
                type  => $args_ref->{$key},
                email => $args_ref->{ "WatcherAddressEmail" . $1 }
            );
            push @results, $msg;
        }

        #Add requestors in the simple style demanded by the bulk manipulator
        elsif ( $key =~ /^Add(requestor|cc|admin_cc)$/ ) {
            my ( $code, $msg ) = $Ticket->add_watcher(
                type  => $1,
                email => $args_ref->{$key}
            );
            push @results, $msg;
        }

        # Add new  watchers by owner
        elsif ( $key =~ /^Ticket-AddWatcher-Principal-(\d*)$/ ) {
            my $principal_id = $1;
            my $form         = $args_ref->{$key};
            foreach my $value ( ref($form) ? @{$form} : ($form) ) {
                next unless $value =~ /^(?:admin_cc|cc|requestor)$/i;

                my ( $code, $msg ) = $Ticket->add_watcher(
                    type         => $value,
                    principal_id => $principal_id
                );
                push @results, $msg;
            }
        }

    }
    return (@results);
}

# }}}

# {{{ sub process_ticket_dates

=head2 process_ticket_dates ( ticket_obj => $Ticket, args_ref => \%ARGS );

Returns an array of results messages.

=cut

sub process_ticket_dates {
    my %args = (
        ticket_obj => undef,
        args_ref    => undef,
        @_
    );

    my $Ticket  = $args{'ticket_obj'};
    my $args_ref = $args{'args_ref'};

    my (@results);

    # {{{ Set date fields
    my @date_fields = qw(
        Told
        Resolved
        starts
        Started
        Due
    );

    #Run through each field in this list. update the value if apropriate
    foreach my $field (@date_fields) {
        next unless exists $args_ref->{ $field . '_Date' };
        next if $args_ref->{ $field . '_Date' } eq '';

        my ( $code, $msg );

        my $DateObj = RT::Date->new();
        $DateObj->set(
            format => 'unknown',
            Value  => $args_ref->{ $field . '_Date' }
        );

        my $obj = $field . "_obj";
        if (    ( defined $DateObj->unix )
            and ( $DateObj->unix != $Ticket->$obj()->unix() ) )
        {
            my $method = "set_$field";
            my ( $code, $msg ) = $Ticket->$method( $DateObj->iso );
            push @results, "$msg";
        }
    }

    # }}}
    return (@results);
}

# }}}

# {{{ sub process_ticket_links

=head2 process_ticket_links ( ticket_obj => $Ticket, args_ref => \%ARGS );

Returns an array of results messages.

=cut

sub process_ticket_links {
    my %args = (
        ticket_obj => undef,
        args_ref    => undef,
        @_
    );

    my $Ticket  = $args{'ticket_obj'};
    my $args_ref = $args{'args_ref'};

    my (@results)
        = process_record_links( record_obj => $Ticket, args_ref => $args_ref );

    #Merge if we need to
    if ( $args_ref->{ $Ticket->id . "-MergeInto" } ) {
        $args_ref->{ $Ticket->id . "-MergeInto" } =~ s/\s+//g;
        my ( $val, $msg )
            = $Ticket->merge_into( $args_ref->{ $Ticket->id . "-MergeInto" } );
        push @results, $msg;
    }

    return (@results);
}

# }}}

sub process_record_links {
    my %args = (
        record_obj => undef,
        args_ref   => undef,
        @_
    );

    my $Record  = $args{'record_obj'};
    my $args_ref = $args{'args_ref'};

    my (@results);

    # Delete links that are gone gone gone.
    foreach my $arg ( keys %$args_ref ) {
        if ( $arg =~ /delete_link-(.*?)-(DependsOn|MemberOf|RefersTo)-(.*)$/ )
        {
            my $base   = $1;
            my $type   = $2;
            my $target = $3;

            push @results,
                _( "Trying to delete: base: %1 target: %2 Type: %3",
                $base, $target, $type );
            my ( $val, $msg ) = $Record->delete_link(
                base   => $base,
                type   => $type,
                target => $target
            );

            push @results, $msg;

        }

    }

    my @linktypes = qw( DependsOn MemberOf RefersTo );

    foreach my $linktype (@linktypes) {
        if ( $args_ref->{ $Record->id . "-$linktype" } ) {
            for my $luri (
                split( / /, $args_ref->{ $Record->id . "-$linktype" } ) )
            {
                $luri =~ s/\s*$//;    # Strip trailing whitespace
                my ( $val, $msg ) = $Record->add_link(
                    target => $luri,
                    type   => $linktype
                );
                push @results, $msg;
            }
        }
        if ( $args_ref->{ "$linktype-" . $Record->id } ) {

            for my $luri (
                split( / /, $args_ref->{ "$linktype-" . $Record->id } ) )
            {
                my ( $val, $msg ) = $Record->add_link(
                    base => $luri,
                    type => $linktype
                );

                push @results, $msg;
            }
        }
    }

    return (@results);
}

=head2 _uploaded_file ( $arg );

Takes a CGI parameter name; if a file is uploaded under that name,
return a hash reference suitable for AddCustomFieldValue's use:
C<( value => $filename, large_content => $content, content_type => $type )>.

Returns C<undef> if no files were uploaded in the C<$arg> field.

=cut

sub _uploaded_file {
    my $arg         = shift;
    my $cgi_object  = Jifty->handler->cgi;
    my $fh          = $cgi_object->upload($arg) or return undef;
    my $upload_info = $cgi_object->uploadInfo($fh);

    my $filename = "$fh";
    $filename =~ s#^.*[\\/]##;
    binmode($fh);

    return {
        value        => $filename,
        large_content => do { local $/; scalar <$fh> },
        content_type  => $upload_info->{'Content-Type'},
    };
}

sub get_column_map_entry {
    my %args = ( Map => {}, name => '', Attribute => undef, @_ );

    # deal with the simplest thing first
    if ( $args{'Map'}{ $args{'name'} } ) {
        return $args{'Map'}{ $args{'name'} }{ $args{'Attribute'} };
    }

    # complex things
    elsif ( my ( $mainkey, $subkey ) = $args{'name'} =~ /^(.*?)\.{(.+)}$/ ) {
        return undef unless $args{'Map'}->{$mainkey};
        return $args{'Map'}{$mainkey}{ $args{'Attribute'} }
            unless ref $args{'Map'}{$mainkey}{ $args{'Attribute'} } eq 'CODE';

        return sub {
            $args{'Map'}{$mainkey}{ $args{'Attribute'} }->( @_, $subkey );
        };
    }
    return undef;
}

=head2 _load_container_object ( $type, $id );

Instantiate container object for saving searches.

=cut

sub _load_container_object {
    my ( $obj_type, $obj_id ) = @_;
    return RT::SavedSearch->new()->_load_privacy_object( $obj_type, $obj_id );
}

=head2 _parse_saved_search ( $arg );

Given a serialization string for saved search, and returns the
container object and the search id.

=cut

sub _parse_saved_search {
    my $spec = shift;
    return unless $spec;
    if ( $spec !~ /^(.*?)-(\d+)-SavedSearch-(\d+)$/ ) {
        return;
    }
    my $obj_type  = $1;
    my $obj_id    = $2;
    my $search_id = $3;

    return ( _load_container_object( $obj_type, $obj_id ), $search_id );
}

eval "require RT::Interface::Web_Vendor";
die $@ if ( $@ && $@ !~ qr{^Can't locate RT/Interface/Web_Vendor.pm} );
eval "require RT::Interface::Web_Local";
die $@ if ( $@ && $@ !~ qr{^Can't locate RT/Interface/Web_Local.pm} );

1;
