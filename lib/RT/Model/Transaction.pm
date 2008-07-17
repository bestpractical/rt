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
use strict;
use warnings;

=head1 name

RT::Model::Transaction


=head1 SYNOPSIS

=head1 description

=head1 METHODS

=cut

package RT::Model::Transaction;
use RT::Record;

use base qw/RT::Record/;

use Jifty::DBI::Schema;
use Jifty::DBI::Record schema {

    column
        object_type => max_length is 64,
        type is 'varchar(64)', default is '';
    column object_id  => max_length is 11, type is 'int',         default is '0';
    column time_taken => max_length is 11, type is 'int',         default is '0';
    column type       => max_length is 20, type is 'varchar(20)', default is '';
    column field      => max_length is 40, type is 'varchar(40)', default is '';
    column
        old_value => max_length is 255,
        type is 'varchar(255)', default is '';
    column
        new_value => max_length is 255,
        type is 'varchar(255)', default is '';
    column
        reference_type => max_length is 255,
        type is 'varchar(255)', default is '';
    column old_reference => max_length is 11,  type is 'int',          default is '0';
    column new_reference => max_length is 11,  type is 'int',          default is '0';
    column data          => max_length is 255, type is 'varchar(255)', default is '';
    column creator       => max_length is 11,  type is 'int',          default is '0';
    column created       => type is 'timestamp';

};

=head2 object_type

Returns the current value of object_type. 
(In the database, object_type is stored as varchar(64).)



=head2 setobject_type value


Set object_type to value. 
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, object_type will be stored as a varchar(64).)


=cut

=head2 object_id

Returns the current value of object_id. 
(In the database, object_id is stored as int.)



=head2 setobject_id value


Set object_id to value. 
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, object_id will be stored as a int.)


=cut

=head2 time_taken

Returns the current value of time_taken. 
(In the database, time_taken is stored as int.)



=head2 set_time_taken value


Set time_taken to value. 
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, time_taken will be stored as a int.)


=cut

=head2 type

Returns the current value of type. 
(In the database, type is stored as varchar(20).)



=head2 set_type value


Set type to value. 
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, type will be stored as a varchar(20).)


=cut

=head2 field

Returns the current value of field. 
(In the database, field is stored as varchar(40).)



=head2 set_field value


Set field to value. 
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, field will be stored as a varchar(40).)


=cut

=head2 old_value

Returns the current value of old_value. 
(In the database, old_value is stored as varchar(255).)



=head2 setold_value value


Set old_value to value. 
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, old_value will be stored as a varchar(255).)


=cut

=head2 new_value

Returns the current value of new_value. 
(In the database, new_value is stored as varchar(255).)



=head2 setnew_value value


Set new_value to value. 
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, new_value will be stored as a varchar(255).)


=cut

=head2 reference_type

Returns the current value of reference_type. 
(In the database, reference_type is stored as varchar(255).)



=head2 set_reference_type value


Set reference_type to value. 
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, reference_type will be stored as a varchar(255).)


=cut

=head2 old_reference

Returns the current value of old_reference. 
(In the database, old_reference is stored as int.)



=head2 set_old_reference value


Set old_reference to value. 
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, old_reference will be stored as a int.)


=cut

=head2 new_reference

Returns the current value of new_reference. 
(In the database, new_reference is stored as int.)



=head2 set_new_reference value


Set new_reference to value. 
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, new_reference will be stored as a int.)


=cut

=head2 data

Returns the current value of data. 
(In the database, data is stored as varchar(255).)



=head2 set_data value


Set data to value. 
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, data will be stored as a varchar(255).)


=cut

=head2 creator

Returns the current value of creator. 
(In the database, creator is stored as int.)


=cut

=head2 created

Returns the current value of created. 
(In the database, created is stored as datetime.)


=cut

sub table {'Transactions'}

use vars qw( %_brief_descriptions $Preferredcontent_type );

use RT::Model::AttachmentCollection;
use RT::Model::ScripCollection;

use HTML::FormatText;
use HTML::TreeBuilder;

# {{{ sub create

=head2 create

Create a new transaction.

This routine should _never_ be called by anything other than RT::Model::Ticket. 
It should not be called 
from client code. Ever. Not ever.  If you do this, we will hunt you down and break your kneecaps.
Then the unpleasant stuff will start.

TODO: Document what gets passed to this

=cut

sub create {
    my $self = shift;
    my %args = (
        id              => undef,
        time_taken      => 0,
        type            => 'undefined',
        data            => '',
        field           => undef,
        old_value       => undef,
        new_value       => undef,
        mime_obj        => undef,
        activate_scrips => 1,
        commit_scrips   => 1,
        object_type     => 'RT::Model::Ticket',
        object_id       => 0,
        reference_type  => undef,
        old_reference   => undef,
        new_reference   => undef,
        @_
    );

    $args{object_id} ||= $args{ticket};

    #if we didn't specify a ticket, we need to bail
    unless ( $args{'object_id'} && $args{'object_type'} ) {
        return ( 0, _( "Transaction->create couldn't, as you didn't specify an object type and id" ) );
    }

    #lets create our transaction
    my %params = (
        type           => $args{'type'},
        data           => $args{'data'},
        field          => $args{'field'},
        old_value      => $args{'old_value'},
        new_value      => $args{'new_value'},
        created        => $args{'created'},
        object_type    => $args{'object_type'},
        object_id      => $args{'object_id'},
        reference_type => $args{'reference_type'},
        old_reference  => $args{'old_reference'},
        new_reference  => $args{'new_reference'},
    );

    # Parameters passed in during an import that we probably don't want to touch, otherwise
    foreach my $attr qw(id creator created last_updated time_taken last_updated_by) {
        $params{$attr} = $args{$attr} if ( $args{$attr} );
    }

    my $id = $self->SUPER::create(%params);
    $self->load($id);
    if ( defined $args{'mime_obj'} ) {
        my ( $id, $msg ) = $self->_attach( $args{'mime_obj'} );
        unless ($id) {
            Jifty->log->error("Couldn't add attachment: $msg");
            return ( 0, _("Couldn't add attachment") );
        }
    }

    #Provide a way to turn off scrips if we need to
    Jifty->log->debug( 'About to think about scrips for transaction #' . $self->id );
    if (    $args{'activate_scrips'}
        and $args{'object_type'} eq 'RT::Model::Ticket' )
    {
        $self->{'scrips'} = RT::Model::ScripCollection->new( current_user => RT->system_user );

        Jifty->log->debug( 'About to prepare scrips for transaction #' . $self->id );
        $self->{'scrips'}->prepare(
            stage       => 'TransactionCreate',
            type        => $args{'type'},
            ticket      => $args{'object_id'},
            transaction => $self->id,
        );
        if ( $args{'commit_scrips'} ) {
            Jifty->log->debug( 'About to commit scrips for transaction #' . $self->id );
            $self->{'scrips'}->commit();
        } else {
            Jifty->log->debug( 'Skipping commit of scrips for transaction #' . $self->id );

        }
    }

    return ( $id, _("Transaction Created") );
}

# }}}

=head2 scrips

Returns the Scrips object for this transaction.
This routine is only useful on a freshly created transaction object.
Scrips do not get persisted to the database with transactions.


=cut

sub scrips {
    my $self = shift;
    return ( $self->{'scrips'} );
}

# {{{ sub delete

=head2 delete

Delete this transaction. Currently DOES NOT CHECK ACLS

=cut

sub delete {
    my $self = shift;

    Jifty->handle->begin_transaction();

    my $attachments = $self->attachments;

    while ( my $attachment = $attachments->next ) {
        my ( $id, $msg ) = $attachment->delete();
        unless ($id) {
            Jifty->handle->rollback();
            return ( $id, _( "System Error: %1", $msg ) );
        }
    }
    my ( $id, $msg ) = $self->SUPER::delete();
    unless ($id) {
        Jifty->handle->rollback();
        return ( $id, _( "System Error: %1", $msg ) );
    }
    Jifty->handle->commit();
    return ( $id, $msg );
}

# }}}

# {{{ Routines dealing with Attachments

# {{{ sub message

=head2 message

Returns the L<RT::Model::AttachmentCollection> object which contains the "top-level" object
attachment for this transaction.

=cut

sub message {
    my $self = shift;

    # XXX: Where is ACL check?

    unless ( defined $self->{'message'} ) {

        $self->{'message'} = RT::Model::AttachmentCollection->new();
        $self->{'message'}->limit(
            column => 'transaction_id',
            value  => $self->id
        );
        $self->{'message'}->children_of(0);
    } else {
        $self->{'message'}->goto_first_item;
    }
    return $self->{'message'};
}

# }}}

# {{{ sub content

=head2 content PARAMHASH

If this transaction has attached mime objects, returns the body of the first
textual part (as defined in RT::I18N::is_textual_content_type).  Otherwise,
returns undef.

Takes a paramhash.  If the $args{'Quote'} parameter is set, wraps this message 
at $args{'Wrap'}.  $args{'Wrap'} defaults to 70.

If $args{'type'} is set to C<text/html>, plain texts are upgraded to HTML.
Otherwise, HTML texts are downgraded to plain text.  If $args{'type'} is
missing, it defaults to the value of C<$RT::Model::Transaction::Preferredcontent_type>,
if that's missing too, defaults to 'text/plain'.

=cut

sub content {
    my $self = shift;
    my %args = (
        type => $Preferredcontent_type || 'text/plain',
        Quote => 0,
        Wrap  => 70,
        @_
    );

    my $content;
    if ( my $content_obj = $self->content_obj ) {
        $content = $content_obj->content || '';

        if ( lc $content_obj->content_type eq 'text/html' ) {
            $content =~ s/<p>--\s+<br \/>.*?$//s if $args{'Quote'};

            if ( $args{type} ne 'text/html' ) {
                $content = HTML::FormatText->new(
                    leftmargin  => 0,
                    rightmargin => 78,
                )->format( HTML::TreeBuilder->new_from_content($content) );
            }
        } else {
            $content =~ s/\n-- \n.*?$//s if $args{'Quote'};
            if ( $args{type} eq 'text/html' ) {

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
        $content = _('This transaction appears to have no content');
    }

    if ( $args{'Quote'} ) {

        # What's the longest line like?
        my $max = 0;
        foreach ( split( /\n/, $content ) ) {
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
        $content = _( "On %1, %2 wrote:", $self->created_as_string, $self->creator_obj->name ) . "\n$content\n\n";
    }

    return ($content);
}

# }}}

=head2 addresses

Returns a hashref of addresses related to this transaction. See L<RT::Model::Attachment/Addresses> for details.

=cut

sub addresses {
    my $self = shift;

    if ( my $attach = $self->attachments->first ) {
        return $attach->addresses;
    } else {
        return {};
    }

}

# {{{ content_obj

=head2 content_obj 

Returns the RT::Model::Attachment object which contains the content for this Transaction

=cut

sub content_obj {
    my $self = shift;

    # If we don't have any content, return undef now.
    # Get the set of toplevel attachments to this transaction.
    return undef unless my $Attachment = $self->attachments->first;

    # If it's a textual part, just return the body.
    if ( RT::I18N::is_textual_content_type( $Attachment->content_type ) ) {
        return ($Attachment);
    }

    # If it's a multipart object, first try returning the first part with preferred
    # MIME type ('text/plain' by default).

    elsif ( $Attachment->content_type =~ '^multipart/' ) {
        my $plain_parts = $Attachment->children;
        $plain_parts->content_type( value => ( $Preferredcontent_type || 'text/plain' ) );
        $plain_parts->limit_not_empty;

        # If we actully found a part, return its content
        if ( my $first = $plain_parts->first ) {
            return $first;
        }

        # If that fails, return the first textual part which has some content.
        my $all_parts = $self->attachments;
        while ( my $part = $all_parts->next ) {
            next
                unless RT::I18N::is_textual_content_type( $part->content_type )
                    && $part->content;
            return $part;
        }
    }

    # We found no content. suck
    return (undef);
}

# }}}

# {{{ sub subject

=head2 subject

If this transaction has attached mime objects, returns the first one's subject
Otherwise, returns null
  
=cut

sub subject {
    my $self = shift;
    return undef unless my $first = $self->attachments->first;
    return $first->subject;
}

# }}}

# {{{ sub attachments

=head2 attachments

Returns all the RT::Model::Attachment objects which are attached
to this transaction. Takes an optional parameter, which is
a content_type that Attachments should be restricted to.

=cut

sub attachments {
    my $self = shift;

    if ( $self->{'attachments'} ) {
        $self->{'attachments'}->goto_first_item;
        return $self->{'attachments'};
    }

    $self->{'attachments'} = RT::Model::AttachmentCollection->new;

    unless ( $self->current_user_can_see ) {
        $self->{'attachments'}->limit( column => 'id', value => '0' );
        return $self->{'attachments'};
    }

    $self->{'attachments'}->limit( column => 'transaction_id', value => $self->id );

    # Get the self->{'attachments'} in the order they're put into
    # the database.  Arguably, we should be returning a tree
    # of self->{'attachments'}, not a set...but no current app seems to need
    # it.

    $self->{'attachments'}->order_by( column => 'id', order => 'ASC' );

    return $self->{'attachments'};
}

# }}}

# {{{ sub _attach

=head2 _attach

A private method used to attach a mime object to this transaction.

=cut

sub _attach {
    my $self        = shift;
    my $mime_object = shift;

    unless ( defined $mime_object ) {
        Jifty->log->error("We can't attach a mime object if you don't give us one.");
        return ( 0, _( "%1: no attachment specified", $self ) );
    }

    my $Attachment = RT::Model::Attachment->new;
    my ( $id, $msg ) = $Attachment->create(
        transaction_id => $self->id,
        attachment     => $mime_object
    );
    return ( $Attachment, $msg || _("Attachment Created") );
}

# }}}

# }}}

# {{{ Routines dealing with Transaction Attributes

# {{{ sub description

=head2 description

Returns a text string which describes this transaction

=cut

sub description {
    my $self = shift;

    unless ( $self->current_user_can_see ) {
        return ( _("Permission Denied") );
    }

    unless ( defined $self->type ) {
        return ( _("No transaction type specified") );
    }

    return _( "%1 by %2", $self->brief_description, $self->creator_obj->name );
}

# }}}

# {{{ sub brief_description

=head2 brief_description

Returns a text string which briefly describes this transaction

=cut

sub brief_description {
    my $self = shift;

    unless ( $self->current_user_can_see ) {
        return ( _("Permission Denied") );
    }

    my $type = $self->type;    #cache this, rather than calling it 30 times

    unless ( defined $type ) {
        return _("No transaction type specified");
    }

    my $obj_type = $self->friendlyobject_type;

    if ( $type eq 'Create' ) {
        return ( _( "%1 Created", $obj_type ) );
    } elsif ( $type =~ /Status/ ) {
        if ( $self->field eq 'Status' ) {
            if ( $self->new_value eq 'deleted' ) {
                return ( _( "%1 deleted", $obj_type ) );
            } else {
                return ( _( "Status changed from %1 to %2", "'" . _( $self->old_value ) . "'", "'" . _( $self->new_value ) . "'" ) );

            }
        }

        # Generic:
        my $no_value = _("(no value)");
        return (
            _(  "%1 changed from %2 to %3",
                $self->field,
                (   $self->old_value
                    ? "'" . $self->old_value . "'"
                    : $no_value
                ),
                "'" . $self->new_value . "'"
            )
        );
    }

    if ( my $code = $_brief_descriptions{$type} ) {
        return $code->($self);
    }

    return _(
        "Default: %1/%2 changed from %3 to %4",
        $type,
        $self->field,
        (   $self->old_value
            ? "'" . $self->old_value . "'"
            : _("(no value)")
        ),
        "'" . $self->new_value . "'"
    );
}

%_brief_descriptions = (
    commentEmailRecord => sub {
        my $self = shift;
        return _("Outgoing email about a comment recorded");
    },
    EmailRecord => sub {
        my $self = shift;
        return _("Outgoing email recorded");
    },
    Correspond => sub {
        my $self = shift;
        return _("Correspondence added");
    },
    comment => sub {
        my $self = shift;
        return _("comments added");
    },
    custom_field => sub {
        my $self  = shift;
        my $field = _('custom_field');

        if ( $self->field ) {
            my $cf = RT::Model::CustomField->new;
            $cf->load( $self->field );
            $field = $cf->name();
        }

        if ( !defined $self->old_value || $self->old_value eq '' ) {
            return ( _( "%1 %2 added", $field, $self->new_value ) );
        } elsif ( !defined $self->new_value || $self->new_value eq '' ) {
            return ( _( "%1 %2 deleted", $field, $self->old_value ) );

        } else {
            return _( "%1 %2 changed to %3", $field, $self->old_value, $self->new_value );
        }
    },
    Untake => sub {
        my $self = shift;
        return _("Untaken");
    },
    Take => sub {
        my $self = shift;
        return _("Taken");
    },
    Force => sub {
        my $self = shift;
        my $Old  = RT::Model::User->new;
        $Old->load( $self->old_value );
        my $New = RT::Model::User->new;
        $New->load( $self->new_value );

        return _( "Owner forcibly changed from %1 to %2", $Old->name, $New->name );
    },
    Steal => sub {
        my $self = shift;
        my $Old  = RT::Model::User->new;
        $Old->load( $self->old_value );
        return _( "Stolen from %1", $Old->name );
    },
    Give => sub {
        my $self = shift;
        my $New  = RT::Model::User->new;
        $New->load( $self->new_value );
        return _( "Given to %1", $New->name );
    },
    AddWatcher => sub {
        my $self      = shift;
        my $principal = RT::Model::Principal->new;
        $principal->load( $self->new_value );
        return _( "%1 %2 added", $self->field, $principal->object->name );
    },
    del_watcher => sub {
        my $self      = shift;
        my $principal = RT::Model::Principal->new;
        $principal->load( $self->old_value );
        return _( "%1 %2 deleted", $self->field, $principal->object->name );
    },
    subject => sub {
        my $self = shift;
        return _( "subject changed to %1", $self->data );
    },
    AddLink => sub {
        my $self = shift;
        my $value;
        if ( $self->new_value ) {
            my $URI = RT::URI->new;
            $URI->from_uri( $self->new_value );
            if ( $URI->resolver ) {
                $value = $URI->resolver->as_string;
            } else {
                $value = $self->new_value;
            }
            if ( $self->field eq 'DependsOn' ) {
                return _( "Dependency on %1 added", $value );
            } elsif ( $self->field eq 'DependedOnBy' ) {
                return _( "Dependency by %1 added", $value );

            } elsif ( $self->field eq 'RefersTo' ) {
                return _( "Reference to %1 added", $value );
            } elsif ( $self->field eq 'ReferredToBy' ) {
                return _( "Reference by %1 added", $value );
            } elsif ( $self->field eq 'MemberOf' ) {
                return _( "Membership in %1 added", $value );
            } elsif ( $self->field eq 'has_member' ) {
                return _( "Member %1 added", $value );
            } elsif ( $self->field eq 'MergedInto' ) {
                return _( "Merged into %1", $value );
            }
        } else {
            return ( $self->data );
        }
    },
    delete_link => sub {
        my $self = shift;
        my $value;
        if ( $self->old_value ) {
            my $URI = RT::URI->new;
            $URI->from_uri( $self->old_value );
            if ( $URI->resolver ) {
                $value = $URI->resolver->as_string;
            } else {
                $value = $self->old_value;
            }

            if ( $self->field eq 'DependsOn' ) {
                return _( "Dependency on %1 deleted", $value );
            } elsif ( $self->field eq 'DependedOnBy' ) {
                return _( "Dependency by %1 deleted", $value );

            } elsif ( $self->field eq 'RefersTo' ) {
                return _( "Reference to %1 deleted", $value );
            } elsif ( $self->field eq 'ReferredToBy' ) {
                return _( "Reference by %1 deleted", $value );
            } elsif ( $self->field eq 'MemberOf' ) {
                return _( "Membership in %1 deleted", $value );
            } elsif ( $self->field eq 'has_member' ) {
                return _( "Member %1 deleted", $value );
            }
        } else {
            return ( $self->data );
        }
    },
    Set => sub {
        my $self = shift;
        if ( $self->field eq 'password' ) {
            return _('password changed');
        } elsif ( $self->field eq 'queue' ) {
            my $q1 = RT::Model::Queue->new();
            $q1->load( $self->old_value );
            my $q2 = RT::Model::Queue->new();
            $q2->load( $self->new_value );
            return _( "%1 changed from %2 to %3", $self->field, $q1->name, $q2->name );
        }

        # Write the date/time change at local time:
        elsif ( $self->field =~ /Due|starts|Started|Told/i ) {
            my $t1 = RT::Date->new();
            $t1->set( format => 'ISO', value => $self->new_value );
            my $t2 = RT::Date->new();
            $t2->set( format => 'ISO', value => $self->old_value );
            return _( "%1 changed from %2 to %3", $self->field, $t2->as_string, $t1->as_string );
        } else {
            return _(
                "%1 changed from %2 to %3",
                $self->field,
                (   $self->old_value
                    ? "'" . $self->old_value . "'"
                    : _("(no value)")
                ),
                "'" . $self->new_value . "'"
            );
        }
    },
    PurgeTransaction => sub {
        my $self = shift;
        return _( "Transaction %1 purged", $self->data );
    },
    AddReminder => sub {
        my $self   = shift;
        my $ticket = RT::Model::Ticket->new;
        $ticket->load( $self->new_value );
        return _( "Reminder '%1' added", $ticket->subject );
    },
    OpenReminder => sub {
        my $self   = shift;
        my $ticket = RT::Model::Ticket->new;
        $ticket->load( $self->new_value );
        return _( "Reminder '%1' reopened", $ticket->subject );

    },
    ResolveReminder => sub {
        my $self   = shift;
        my $ticket = RT::Model::Ticket->new;
        $ticket->load( $self->new_value );
        return _( "Reminder '%1' completed", $ticket->subject );

    }
);

# }}}

# {{{ Utility methods

# {{{ sub is_inbound

=head2 is_inbound

Returns true if the creator of the transaction is a requestor of the ticket.
Returns false otherwise

=cut

sub is_inbound {
    my $self = shift;
    $self->object_type eq 'RT::Model::Ticket' or return undef;
    return ( $self->ticket_obj->is_requestor( $self->creator_obj->principal_id ) );
}

# }}}

# }}}

# {{{ sub _set

sub _set {
    my $self = shift;
    return ( 0, _('Transactions are immutable') );
}

# }}}

# {{{ sub _value

=head2 _value

Takes the name of a table column.
Returns its value as a string, if the user passes an ACL check

=cut

sub _value {
    my $self  = shift;
    my $field = shift;

    #if the field is public, return it.
    if ( $field eq 'object_type' ) {
        return $self->SUPER::_value($field);
    }

    unless ( $self->current_user_can_see ) {
        return undef;
    }

    return $self->SUPER::_value($field);
}

# }}}

# {{{ sub current_user_has_right

=head2 current_user_has_right RIGHT

Calls $self->current_user->has_queue_right for the right passed in here.
passed in here.

=cut

sub current_user_has_right {
    my $self  = shift;
    my $right = shift;
    return $self->current_user->has_right(
        right  => $right,
        object => $self->object
    );
}

=head2 current_user_can_see

Returns true if current user has rights to see this particular transaction.

This fact depends on type of the transaction, type of an object the transaction
is attached to and may be other conditions, so this method is prefered over
custom implementations.

=cut

sub current_user_can_see {
    my $self = shift;

    # If it's a comment, we need to be extra special careful
    my $type = $self->__value('type');
    if ( $type eq 'comment' ) {
        unless ( $self->current_user_has_right('ShowTicketcomments') ) {
            return 0;
        }
    } elsif ( $type eq 'commentEmailRecord' ) {
        unless ( $self->current_user_has_right('ShowTicketcomments')
            && $self->current_user_has_right('ShowOutgoingEmail') )
        {
            return 0;
        }
    } elsif ( $type eq 'EmailRecord' ) {
        unless ( $self->current_user_has_right('ShowOutgoingEmail') ) {
            return 0;
        }
    }

    # Make sure the user can see the custom field before showing that it changed
    elsif ( $type eq 'custom_field' and my $cf_id = $self->__value('field') ) {
        my $cf = RT::Model::CustomField->new;
        $cf->load($cf_id);
        return 0 unless $cf->current_user_has_right('SeeCustomField');
    }

    #if they ain't got rights to see, don't let em
    elsif ( $self->__value('object_type') eq "RT::Model::Ticket" ) {
        unless ( $self->current_user_has_right('ShowTicket') ) {
            return 0;
        }
    }

    return 1;
}

# }}}

sub ticket {
    my $self = shift;
    return $self->object_id;
}

sub ticket_obj {
    my $self = shift;
    return $self->object;
}

sub old_value {
    my $self = shift;
    if (    my $type = $self->__value('reference_type')
        and my $id = $self->__value('old_reference') )
    {
        my $object = $type->new;
        $object->load($id);
        return $object->content;
    } else {
        return $self->__value('old_value');
    }
}

sub new_value {
    my $self = shift;
    if (    my $type = $self->__value('reference_type')
        and my $id = $self->__value('new_reference') )
    {
        my $object = $type->new;
        $object->load($id);
        return $object->content;
    } else {
        return $self->__value('new_value');
    }
}

sub object {
    my $self   = shift;
    my $object = $self->__value('object_type')->new;
    $object->load( $self->__value('object_id') );
    return $object;
}

sub friendlyobject_type {
    my $self = shift;
    my $type = $self->object_type or return undef;
    $type =~ s/^RT::Model:://;
    return _($type);
}

=head2 update_custom_fields
    
    Takes a hash of 

    CustomField-<<Id>> => Value
        or 

    object-RT::Model::Transaction-CustomField-<<Id>> => Value parameters to update
    this transaction's custom fields

=cut

sub update_custom_fields {
    my $self = shift;
    my %args = (@_);

    # This method used to have an API that took a hash of a single
    # value "args_ref", which was a reference to a hash of arguments.
    # This was insane. The next few lines of code preserve that API
    # while giving us something saner.

    # TODO: 3.6: DEPRECATE OLD API

    my $args;

    if ( $args{'args_ref'} ) {
        $args = $args{args_ref};
    } else {
        $args = \%args;
    }

    foreach my $arg ( keys %$args ) {
        next
            unless ( $arg =~ /^(?:object-RT::Model::Transaction--)?CustomField-(\d+)/ );
        next if $arg =~ /-magic$/;
        my $cfid   = $1;
        my $values = $args->{$arg};
        foreach my $value ( UNIVERSAL::isa( $values, 'ARRAY' ) ? @$values : $values ) {
            next unless length($value);
            $self->add_custom_field_value(
                field              => $cfid,
                value              => $value,
                record_transaction => 0,
            );
        }
    }
}

=head2 custom_field_values

 Do name => id mapping (if needed) before falling back to RT::Record's custom_field_values

 See L<RT::Record>

=cut

sub custom_field_values {
    my $self  = shift;
    my $field = shift;

    if ( UNIVERSAL::can( $self->object, 'queue_obj' ) ) {

        # XXX: $field could be undef when we want fetch values for all CFs
        #      do we want to cover this situation somehow here?
        unless ( defined $field && $field =~ /^\d+$/o ) {
            my $CFs = RT::Model::CustomFieldCollection->new;
            $CFs->limit( column => 'name', value => $field );
            $CFs->limit_to_lookup_type( $self->custom_field_lookup_type );
            $CFs->limit_to_global_or_object_id( $self->object->queue_obj->id );
            $field = $CFs->first->id if $CFs->first;
        }
    }
    return $self->SUPER::custom_field_values($field);
}

# }}}

# {{{ sub custom_field_lookup_type

=head2 custom_fieldlookup_type

Returns the RT::Model::Transaction lookup type, which can 
be passed to RT::Model::CustomField->create() via the 'lookup_type' hash key.

=cut

# }}}

sub custom_field_lookup_type {
    "RT::Model::Queue-RT::Model::Ticket-RT::Model::Transaction";
}

=item DeferredRecipients($freq, $include_sent )

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
    my $self         = shift;
    my $freq         = shift;
    my $include_sent = @_ ? shift : 0;

    my $attr = $self->first_attribute('DeferredRecipients');

    return () unless ($attr);

    my $deferred = $attr->content;

    return () unless ( ref($deferred) eq 'HASH' && exists $deferred->{$freq} );

    # Skip it.

    for my $user ( keys %{ $deferred->{$freq} } ) {
        if ( $deferred->{$freq}->{$user}->{_sent} && !$include_sent ) {
            delete $deferred->{$freq}->{$user};
        }
    }

    # Now get our users.  Easy.

    return keys %{ $deferred->{$freq} };
}

# Transactions don't change. by adding this cache config directive, we don't lose pathalogically on long tickets.
sub _cache_config {
    {   'cache_p'       => 1,
        'fast_update_p' => 1,
        'cache_for_sec' => 6000,
    };
}
1;
