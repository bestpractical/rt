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
# Portions Copyright 2000 Tobias Brox <tobix@cpan.org>

=head1 name

  RT::Model::Template - RT's template object

=head1 SYNOPSIS

  use RT::Model::Template;

=head1 description


=head1 METHODS


=cut

package RT::Model::Template;

use strict;
no warnings qw(redefine);

use Text::Template;
use MIME::Entity;
use MIME::Parser;
use File::Temp qw /tempdir/;

sub table {'Templates'}

use base qw'RT::Record';
use Jifty::DBI::Schema;
use Jifty::DBI::Record schema {
    column queue => max_length is 11,  type is 'int',          default is '0';
    column name  => max_length is 200, type is 'varchar(200)', default is '';
    column
        description => max_length is 255,
        type is 'varchar(255)', default is '';
    column type => max_length is 16, type is 'varchar(16)', default is '';
    column content => type is 'blob', default is '';
    column last_updated    => type is 'timestamp';
    column last_updated_by => max_length is 11, type is 'int', default is '0';
    column creator         => max_length is 11, type is 'int', default is '0';
    column created         => type is 'timestamp';

};

sub _set {
    my $self = shift;

    unless ( $self->current_user_has_queue_right('ModifyTemplate') ) {
        return ( 0, _('Permission Denied') );
    }
    return $self->SUPER::_set(@_);
}

# }}}

# {{{ sub _value

=head2 _value

Takes the name of a table column.
Returns its value as a string, if the user passes an ACL check





=cut

sub _value {
    my $self = shift;

    unless ( $self->current_user_has_queue_right('ShowTemplate') ) {
        return undef;
    }
    return $self->__value(@_);

}

# }}}

# {{{ sub load

=head2 load <identifer>

Load a template, either by number or by name

=cut

sub load {
    my $self       = shift;
    my $identifier = shift;
    return undef unless $identifier;

    if ( $identifier =~ /\D/ ) {
        return $self->load_by_cols( 'name', $identifier );
    }
    return $self->load_by_id($identifier);
}

# }}}

# {{{ sub load_global_template

=head2 load_global_template name

Load the global template with the name name

=cut

sub load_global_template {
    my $self = shift;
    my $id   = shift;

    return ( $self->load_queue_template( queue => 0, name => $id ) );
}

# }}}

# {{{ sub loadqueue_template

=head2  load_queue_template (queue => QUEUEID, name => name)

Loads the queue template named name for queue QUEUE.

=cut

sub load_queue_template {
    my $self = shift;
    my %args = (
        queue => undef,
        name  => undef,
        @_
    );

    return ( $self->load_by_cols( name => $args{'name'}, queue => $args{'queue'} ) );

}

# }}}

# {{{ sub create

=head2 create

Takes a paramhash of content, queue, name and description.
name should be a unique string identifying this Template.
description and content should be the template's title and content.
queue should be 0 for a global template and the queue # for a queue-specific 
template.

Returns the Template's id # if the create was successful. Returns undef for
unknown database failure.


=cut

sub create {
    my $self = shift;
    my %args = (
        content     => undef,
        queue       => 0,
        description => '[no description]',
        type        => 'Action',             #By default, template are 'Action' templates
        name        => undef,
        @_
    );

    unless ( $args{'queue'} ) {
        unless (
            $self->current_user->has_right(
                right  => 'ModifyTemplate',
                object => RT->system
            )
            )
        {
            return ( undef, _('Permission Denied') );
        }
        $args{'queue'} = 0;
    } else {
        my $queue_obj = RT::Model::Queue->new( current_user => $self->current_user );
        $queue_obj->load( $args{'queue'} )
            || return ( undef, _('Invalid queue') );

        unless ( $queue_obj->current_user_has_right('ModifyTemplate') ) {
            return ( undef, _('Permission Denied') );
        }
        $args{'queue'} = $queue_obj->id;
    }

    my $result = $self->SUPER::create(
        content     => $args{'content'},
        queue       => $args{'queue'},
        description => $args{'description'},
        name        => $args{'name'},
    );

    return ($result);

}

# }}}

# {{{ sub delete

=head2 delete

Delete this template.

=cut

sub delete {
    my $self = shift;

    unless ( $self->current_user_has_queue_right('ModifyTemplate') ) {
        return ( 0, _('Permission Denied') );
    }

    return ( $self->SUPER::delete(@_) );
}

=head2 is_empty
 
Returns true value if content of the template is empty, otherwise
returns false.

=cut

sub is_empty {
    my $self    = shift;
    my $content = $self->content;
    return 0 if defined $content && length $content;
    return 1;
}

=head2 mime_obj
 
Returns L<MIME::Entity> object parsed using L</Parse> method. Returns
undef if last call to L</Parse> failed or never be called.
 
Note that content of the template is UTF-8, but L<MIME::Parser> is not
good at handling it and all data of the entity should be treated as
octets and converted to perl strings using Encode::decode_utf8 or
something else.

=cut

sub mime_obj {
    my $self = shift;
    return ( $self->{'mime_obj'} );
}

# {{{ sub parse

=head2 parse

 This routine performs Text::Template parsing on the template and then
 imports the results into a MIME::Entity so we can really use it

 Takes a hash containing Argument, ticket_obj, and transaction_obj.

 It returns a tuple of (val, message)
 If val is 0, the message contains an error message

=cut

=head2 parse
         
This routine performs L<Text::Template> parsing on the template and then
imports the results into a L<MIME::Entity> so we can really use it. Use
L</mime_obj> method to get the L<MIME::Entity> object.
 
Takes a hash containing Argument, ticket_obj, and transaction_obj and other
arguments that will be available in the template's code.
     
It returns a tuple of (val, message). If val is false, the message contains
an error message.
 
=cut

sub parse {
    my $self = shift;
    my ( $rv, $msg );

    if ( $self->content =~ m{^Content-type:\s+text/html\b}im ) {
        local $RT::Model::Transaction::Preferredcontent_type = 'text/html';
        ( $rv, $msg ) = $self->_parse(@_);
    }
    else {
        ( $rv, $msg ) = $self->_parse(@_);
    }

# We only HTMLify things if the template includes at least one Transaction->Content call.
    return ( $rv, $msg ) unless $rv and $self->content =~ /->\s*Content\b/;

    my $orig_entity = $self->mime_obj;
    my $mime_type   = $self->mime_obj->mime_type;

    if ( defined $mime_type and $mime_type eq 'text/html' ) {
        $self->_downgrade_from_html(@_);
    }

    return ( $rv, $msg );
}

sub _parse {
    my $self = shift;

    # clear prev MIME object
    $self->{'mime_obj'} = undef;

    #We're passing in whatever we were passed. it's destined for _Parsecontent
    my ( $content, $msg ) = $self->_parse_content(@_);
    return ( 0, $msg ) unless defined $content && length $content;

    if ( $content =~ /^\S/s && $content !~ /^\S+:/ ) {
        Jifty->log->error( "Template #"
              . $self->id
              . " has leading line that doesn't"
              . " look like header field, if you don't want to override"
              . " any headers and don't want to see this error message"
              . " then leave first line of the template empty" );
        $content = "\n" . $content;
    }

    # Re-use the MIMEParser setup code from RT::EmailParser, which
    # tries to use tmpdirs, falling back to in-memory parsing. But we
    # don't stick the RT::EmailParser into a lexical because it cleans
    # out the tmpdir it makes on DESTROY
    my $parser = MIME::Parser->new();
    $self->{rtparser} = RT::EmailParser->new;
    $self->{rtparser}->_setup_mime_parser($parser);


    ### Should we forgive normally-fatal errors?
    $parser->ignore_errors(1);

    # MIME::Parser doesn't play well with perl strings
    utf8::encode($content);
    $self->{'mime_obj'} = eval { $parser->parse_data( \$content ) };
    if ( my $error = $@ || $parser->last_error ) {
        Jifty->log->error("$error");
        return ( 0, $error );
    }

    # Unfold all headers
    $self->{'mime_obj'}->head->unfold;

    return ( 1, _("Template parsed") );

}

# }}}

# {{{ sub _parsecontent

# Perform template substitutions on the template

sub _parse_content {
    my $self = shift;
    my %args = (
        argument        => undef,
        ticket_obj      => undef,
        transaction_obj => undef,
        @_
    );

    my $content = $self->content;
    unless ( defined $content ) {
        return ( undef, _("Permission Denied") );
    }

    # We need to untaint the content of the template, since we'll be working
    # with it
    $content =~ s/^(.*)$/$1/;
    my $template = Text::Template->new(
        TYPE   => 'STRING',
        SOURCE => $content
    );

    $args{'ticket'} = delete $args{'ticket_obj'} if $args{'ticket_obj'};
    $args{'transaction'} = delete $args{'transaction_obj'}
        if $args{'transaction_obj'};
    $args{'requestor'} = eval { $args{'ticket'}->role_group("requestor")->user_members_obj->first->name; }
        if $args{'ticket'};
    $args{'rtname'} = RT->config->get('rtname');
    if ( $args{'ticket'} ) {
        my $t = $args{'ticket'};    # avoid memory leak
        $args{'loc'} = sub { _(@_) };
    } else {
        $args{'loc'} = sub { _(@_) };
    }

    foreach my $key ( keys %args ) {
        next unless ref $args{$key};
        next if ref $args{$key} =~ /^(ARRAY|HASH|SCALAR|CODE)$/;
        my $val = $args{$key};
        $args{$key} = \$val;
    }

    my $is_broken = 0;
    my $retval    = $template->fill_in(
        HASH   => \%args,
        BROKEN => sub {
            my (%args) = @_;
            Jifty->log->error("Template parsing error: $args{error}")
                unless $args{error} =~ /^Died at /;    # ignore intentional die()
            $is_broken++;
            return undef;
        },
    );
    return ( undef, _('Template parsing error') ) if $is_broken;

    return ($retval);
}

sub _downgrade_from_html {
    my $self        = shift;
    my $orig_entity = $self->mime_obj;
    die 'hehe';

    local $RT::Model::Transaction::Preferredcontent_type = 'text/plain';

    my ( $rv, $msg ) = $self->_parse(@_);
    if ( !$rv ) {
        $self->{mime_obj} = $orig_entity;
        return;
    }

    $orig_entity->head->mime_attr( "Content-type"         => 'text/html' );
    $orig_entity->head->mime_attr( "Content-type.charset" => 'utf-8' );
    $orig_entity->make_multipart( 'alternative', Force => 1 );

    my $new_entity = $self->{mime_obj};
    $new_entity->head->mime_attr( "Content-type"         => 'text/plain' );
    $new_entity->head->mime_attr( "Content-type.charset" => 'utf-8' );

    require HTML::formatText;
    require HTML::TreeBuilder;
    $new_entity->bodyhandle(
        MIME::Body::InCore->new(
            \(
                scalar(
                    HTML::formatText->new(
                        leftmargin  => 0,
                        rightmargin => 78,
                      )->format(
                        HTML::TreeBuilder->new_from_content(
                            $new_entity->bodyhandle->as_string
                        )
                      )
                )
            )
        )
    );

    $orig_entity->add_part( $new_entity, 0 );    # plain comes before html
    $self->{mime_obj} = $orig_entity;

    return ( $rv, $msg );
}

# }}}

# {{{ sub current_user_has_queue_right

=head2 current_user_has_queue_right

Helper function to call the template's queue's current_user_has_queue_right with the passed in args.

=cut

sub current_user_has_queue_right {
    my $self = shift;
    return ( $self->queue_obj->current_user_has_right(@_) );
}

# }}}

sub queue_obj {
    my $self = shift;
    my $q    = RT::Model::Queue->new;
    $q->load( $self->__value('queue') );
    return $q;
}
1;
