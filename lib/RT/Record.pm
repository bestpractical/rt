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

=head1 NAME

  RT::Record - base class for RT record objects

=head1 SYNOPSIS


=head1 description



=head1 METHODS

=cut

package RT::Record;

use strict;
use warnings;

use RT::Model::User;
use RT::Model::AttributeCollection;
use RT::Model::Attribute;
use Encode qw();

our $_TABLE_ATTR = {};
use base qw(Jifty::Record);
use base qw(RT::Base);


sub table {
    my $class = shift;

    $class = ref($class) || $class;
    $class =~ s/^(.*):://g;
    return $class;
}

sub current_user_can {1}    # For now, we're using RT's auth, not jifty's

sub __set {
    my $self = shift;
    my %args = (@_);

    unless ( defined $args{'value'} ) {
        $args{'value'} ||= delete $args{'value'};
    }

    unless ( defined $args{'column'} ) {
        $args{'column'} ||= delete $args{'field'};
    }
    $self->SUPER::__set(%args);

}

=head2 delete

Delete this record object from the database.

=cut

sub delete {
    my $self = shift;
    my ($rv) = $self->SUPER::delete;
    if ($rv) {
        return ( $rv, _("Object deleted") );
    } else {

        return ( 0, _("Object could not be deleted") );
    }
}

=head2 object_type_str

Returns a string which is this object's type.  The type is the class,
without the "RT::" prefix.


=cut

sub object_type_str {
    my $self = shift;
    if ( ref($self) =~ /^.*::(\w+)$/ ) {
        return _($1);
    } else {
        return _( ref($self) );
    }
}

=head2 attributes

Return this object's attributes as an RT::Model::AttributeCollection object

=cut

sub attributes {
    my $self = shift;

    unless ( $self->{'attributes'} ) {
        $self->{'attributes'} = RT::Model::AttributeCollection->new( current_user => $self->current_user );
        $self->{'attributes'}->limit_to_object($self);
    }
    return ( $self->{'attributes'} );

}

=head2 add_attribute { name, description, content }

Adds a new attribute for this object.

=cut

sub add_attribute {
    my $self = shift;
    my %args = (
        name        => undef,
        description => undef,
        content     => undef,
        @_
    );

    my $attr = RT::Model::Attribute->new( current_user => $self->current_user );
    my ( $id, $msg ) = $attr->create(
        object      => $self,
        name        => $args{'name'},
        description => $args{'description'},
        content     => $args{'content'}
    );

    # XXX TODO: Why won't redo_search work here?
    $self->attributes->_do_search;

    return ( $id, $msg );
}

=head2 set_attribute { name, description, content }

Like add_attribute, but replaces all existing attributes with the same name.

=cut

sub set_attribute {
    my $self = shift;
    my %args = (
        name        => undef,
        description => undef,
        content     => undef,
        @_
    );

    my @AttributeObjs = $self->attributes->named( $args{'name'} )
        or return $self->add_attribute(%args);

    my $AttributeObj = pop(@AttributeObjs);
    $_->delete foreach @AttributeObjs;

    $AttributeObj->set_description( $args{'description'} );
    $AttributeObj->set_content( $args{'content'} );

    $self->attributes->redo_search;
    return 1;
}

=head2 delete_attribute name

Deletes all attributes with the matching name for this object.

=cut

sub delete_attribute {
    my $self = shift;
    my $name = shift;
    return $self->attributes->delete_entry( name => $name );
}

=head2 first_attribute name

Returns the first attribute with the matching name for this object (as an
L<RT::Model::Attribute> object), or C<undef> if no such attributes exist.

Note that if there is more than one attribute with the matching name on the
object, the choice of which one to return is basically arbitrary.  This may be
made well-defined in the future.

=cut

sub first_attribute {
    my $self = shift;
    my $name = shift;
    return ( $self->attributes->named($name) )[0];
}


=head2  Create PARAMHASH

Takes a PARAMHASH of Column -> value pairs.
If any Column has a Validate$PARAMname subroutine defined and the 
value provided doesn't pass validation, this routine returns
an error.

If this object's table has any of the following atetributes defined as
'Auto', this routine will automatically fill in their values.

=cut

sub create {
    my $self    = shift;
    my %attribs = (@_);
    foreach my $key ( keys %attribs ) {
        my $method = $self->can("validate_$key");
        if ($method) {
            unless ( $method->( $self, $attribs{$key} ) ) {
                if (wantarray) {
                    return ( 0, _( 'Invalid value for %1', $key ) );
                } else {
                    return (0);
                }
            }
        }
    }

    my ($id) = $self->SUPER::create(%attribs);
    if ( UNIVERSAL::isa( $id, 'Class::ReturnValue' ) ) {
        if ( $id->errno ) {
            if (wantarray) {
                return ( 0, _( "Internal Error: %1", $id->{error_message} ) );
            } else {
                return (0);
            }
        }
    }

    # If the object was Created in the database,
    # load it up now, so we're sure we get what the database
    # has.  Arguably, this should not be necessary, but there
    # isn't much we can do about it.

    unless ($id) {
        if (wantarray) {
            return ( $id, _('Object could not be created') );
        } else {
            return ($id);
        }

    }

    if ( UNIVERSAL::isa( 'errno', $id ) ) {
        return (undef);
    }

    $self->load($id) if ($id);

    if (wantarray) {
        return ( $id, _('Object created') );
    } else {
        return ($id);
    }

}



=head2 load_by_cols

Override Jifty::DBI::load_by_cols to do case-insensitive loads if the 
DB is case sensitive

=cut

sub load_by_id { shift->load_by_cols( id => shift ) }

sub _set {
    my $self = shift;

    my %args = (
        column          => undef,
        value           => undef,
        is_sql_function => undef,
        @_
    );

    unless ( $args{'column'} ) {
        Carp::confess("Field not converted to column");
    }

    #if the user is trying to modify the record
    # TODO: document _why_ this code is here

    if ( ( !defined( $args{'column'} ) ) || ( !defined( $args{'value'} ) ) ) {
        $args{'value'} = 0;
    }

    my $old_val = $self->__value( $args{'column'} );
    my $ret = $self->SUPER::_set(
        column          => $args{'column'},
        value           => $args{'value'},
        is_sql_function => $args{'is_sql_function'}
    );
    my ( $status, $msg ) = $ret->as_array();

    # @values has two values, a status code and a message.

    # $ret is a Class::Returnvalue object. as such, in a boolean context, it's a bool
    # we want to change the standard "success" message
    if ($status) {
        $msg = _( "%1 changed from %2 to %3", _($args{'column'}), ( $old_val ? "'$old_val'" : _("(no value)") ), '"' . ( $self->__value( $args{'column'} ) || 'weird undefined value' ) . '"' );
    } else {

        $msg = _($msg);
    }
    return wantarray ? ( $status, $msg ) : $ret;

}



=head2 set_last_updated

This routine updates the last_updated and last_updated_by columns of the row in question
It takes no options. Arguably, this is a bug

=cut

sub set_last_updated {
    my $self = shift;
    my $now = RT::DateTime->now;

    my ( $msg, $val ) = $self->__set(
        column => 'last_updated',
        value  => $now,
    );
    ( $msg, $val ) = $self->__set(
        column => 'last_updated_by',
        value  => $self->current_user ? $self->current_user->id : 0
    );
}

=head2 last_updated_by_obj

Returns an L<RT::Model::User> object of the last user to touch this
object

=cut

sub last_updated_by_obj {
    my $self = shift;
    unless ( exists $self->{last_updated_by_obj} ) {
        $self->{'last_updated_by_obj'} = RT::Model::User->new( current_user => $self->current_user );
        $self->{'last_updated_by_obj'}->load( $self->last_updated_by );
    }
    return $self->{'last_updated_by_obj'};
}



=head2 uri

Returns this record's URI

=cut

sub uri {
    my $self = shift;
    my $uri  = RT::URI::fsck_com_rt->new;
    return ( $uri->uri_for_object($self) );
}


=head2 validatename name

Validate the name of the record we're creating. Mostly, just make sure it's not a numeric ID, which is invalid for name

=cut

sub validate_name {
    my $self  = shift;
    my $value = shift;
    if ( $value && $value =~ /^\d+$/ ) {
        return (0);
    } else {
        return (1);
    }
}

=head2 _encode_lob BODY MIME_TYPE

Takes a potentially large attachment. Returns (content_encoding, EncodedBody) based on system configuration and selected database

=cut

sub _encode_lob {
    my $self     = shift;
    my $body     = shift;
    my $mime_type = shift;

    my $content_encoding = 'none';

    #get the max attachment length from RT
    my $MaxSize = RT->config->get('max_attachment_size');

    #if the current attachment contains nulls and the
    #database doesn't support embedded nulls

    if ( RT->config->get('always_use_base64') ) {

        # set a flag telling us to mimencode the attachment
        $content_encoding = 'base64';

        #cut the max attchment size by 25% (for mime-encoding overhead.
        Jifty->log->debug("Max size is $MaxSize");
        $MaxSize = $MaxSize * 3 / 4;

        # Some databases (postgres) can't handle non-utf8 data
    } elsif (
        0    #   !Jifty->handle->binary_safe_blobs
        && $mime_type !~ /text\/plain/gi 
        && !Encode::is_utf8( $body, 1 )
        )
    {
        $content_encoding = 'quoted-printable';
    }

    #if the attachment is larger than the maximum size
    if ( ($MaxSize) and ( $MaxSize < length($body) ) ) {

        # if we're supposed to truncate large attachments
        if ( RT->config->get('truncate_long_attachments') ) {

            # truncate the attachment to that length.
            $body = substr( $body, 0, $MaxSize );

        }

        # elsif we're supposed to drop large attachments on the floor,
        elsif ( RT->config->get('drop_long_attachments') ) {

            # drop the attachment on the floor
            Jifty->log->info(
                "$self: Dropped an attachment of size " . length($body) );
            Jifty->log->info( "It started: " . substr( $body, 0, 60 ) );
            return ( "none", "Large attachment dropped" );
        }
    }

    # if we need to mimencode the attachment
    if ( $content_encoding eq 'base64' ) {

        # base64 encode the attachment
        Encode::_utf8_off($body);
        $body = MIME::Base64::encode_base64($body);

    } elsif ( $content_encoding eq 'quoted-printable' ) {
        Encode::_utf8_off($body);
        $body = MIME::QuotedPrint::encode($body);
    }

    return ( $content_encoding, $body );

}

sub _decode_lob {
    my $self             = shift;
    my $content_type     = shift || '';
    my $content_encoding = shift || 'none';
    my $content          = shift;

    if ( $content_encoding eq 'base64' ) {
        $content = MIME::Base64::decode_base64($content);
    } elsif ( $content_encoding eq 'quoted-printable' ) {
        $content = MIME::QuotedPrint::decode($content);
    } elsif ( $content_encoding && $content_encoding ne 'none' ) {
        return ( _( "Unknown content_encoding %1", $content_encoding ) );
    }
    if ( RT::I18N::is_textual_content_type($content_type) ) {
        $content = Encode::decode_utf8($content)
            unless Encode::is_utf8($content);
    }
    return ($content);
}

# A helper table for links mapping to make it easier
# to build and parse links between tickets

use vars '%LINKDIRMAP';

%LINKDIRMAP = (
    MemberOf => {
        base   => 'MemberOf',
        target => 'has_member',
    },
    RefersTo => {
        base   => 'RefersTo',
        target => 'ReferredToBy',
    },
    DependsOn => {
        base   => 'DependsOn',
        target => 'DependedOnBy',
    },
    MergedInto => {
        base   => 'MergedInto',
        target => 'MergedInto',
    },

);

=head2 update  ARGSHASH

Updates fields on an object for you using the proper set methods,
skipping unchanged values.

 args_ref => a hashref of attributes => value for the update
 attributes_ref => an arrayref of keys in args_ref that should be updated
 attriubte_prefix => a prefix that should be added to the attributes in attributes_ref
                    when looking up values in args_ref
                    Bare attributes are tried before prefixed attributes

Returns a list of localized results of the update

=cut

sub update {
    my $self = shift;
    my $class = ref($self) || $self;

    my %args = (
        args_ref         => undef,
        attributes_ref   => undef,
        attribute_prefix => undef,
        @_
    );

    my $attributes = $args{'attributes_ref'};
    my $args_ref   = $args{'args_ref'};
    my @results;

    foreach my $attribute (@$attributes) {
        my $value;
        if ( defined $args_ref->{$attribute} ) {
            $value = $args_ref->{$attribute};
        } elsif ( defined( $args{'attribute_prefix'} )
            && defined( $args_ref->{ $args{'attribute_prefix'} . "-" . $attribute } ) )
        {
            $value = $args_ref->{ $args{'attribute_prefix'} . "-" . $attribute };

        } else {
            next;
        }

        $value =~ s/\r\n/\n/gs;

        # If queue is 'General', we want to resolve the queue name for
        # the object.

        # This is in an eval block because $object might not exist.
        # and might not have a name method.
        # If it fails, we don't care
        eval {
            my $object = $attribute . "_obj";
            next if ( $self->can($object) && $self->$object->name eq $value );
        };
        my $current_value = $self->$attribute();
        next if ( $value eq ( defined $current_value ? $current_value : '' ) );
        my $method = "set_$attribute";
        my ( $code, $msg ) = $self->$method($value);
        my ($prefix) = ref($self) =~ /RT(?:.*)::(\w+)/;

        # Default to $id, but use name if we can get it.
        my $label = $self->id;
        $label = $self->name if ( UNIVERSAL::can( $self, 'name' ) );

        # this requires model names to be loc'ed.

=for loc

    "Ticket" # loc
    "User" # loc
    "Group" # loc
    "Queue" # loc
=cut

        push @results, _($prefix) . " $label: " . $msg;

=for loc

                                   "%1 could not be set to %2.",       # loc
                                   "That is already the current value",    # loc
                                   "No value sent to _set!\n",             # loc
                                   "Illegal value for %1",               # loc
                                   "The new value has been set.",          # loc
                                   "No column specified",                  # loc
                                   "Immutable field",                      # loc
                                   "Nonexistant field?",                   # loc
                                   "Invalid data",                         # loc
                                   "Couldn't find row",                    # loc
                                   "Missing a primary key?: %1",         # loc
                                   "Found object",                         # loc

=cut

    }

    return @results;
}




=head2 members

This returns an L<RT::Model::LinkCollection> object which references
all the tickets which are 'MembersOf' this ticket

=cut

sub members {
    my $self = shift;
    return ( $self->_links( 'target', 'MemberOf' ) );
}



=head2 member_of

This returns an L<RT::Model::LinkCollection> object which references all
the tickets that this ticket is a 'MemberOf'

=cut

sub member_of {
    my $self = shift;
    return ( $self->_links( 'base', 'MemberOf' ) );
}



=head2 refers_to

This returns an L<RT::Model::LinkCollection> object which shows all
references for which this ticket is a base

=cut

sub refers_to {
    my $self = shift;
    return ( $self->_links( 'base', 'RefersTo' ) );
}



=head2 referred_to_by

This returns an L<RT::Model::LinkCollection> object which shows all
references for which this ticket is a target

=cut

sub referred_to_by {
    my $self = shift;
    return ( $self->_links( 'target', 'RefersTo' ) );
}



=head2 depended_on_by

This returns an L<RT::Model::LinkCollection> object which references
all the tickets that depend on this one

=cut

sub depended_on_by {
    my $self = shift;
    return ( $self->_links( 'target', 'DependsOn' ) );
}


=head2 has_unresolved_dependencies

Takes a paramhash of type (default to '__any').  Returns the number of
unresolved dependencies, if $self->unresolved_dependencies returns an
object with one or more members of that type.  Returns false
otherwise.



=cut

sub has_unresolved_dependencies {
    my $self = shift;
    my %args = (
        type => undef,
        @_
    );

    my $deps = $self->unresolved_dependencies;

    if ( $args{'type'} ) {
        $deps->limit(
            column   => 'type',
            operator => '=',
            value    => $args{'type'}
        );
    } else {
        $deps->ignore_type;
    }

    if ( $deps->count > 0 ) {
        return $deps->count;
    } else {
        return (undef);
    }
}


=head2 unresolved_dependencies

Returns an RT::Model::TicketCollection object of tickets which this ticket depends on
and which have a status of new, open or stalled. (That list comes from
RT::Model::Queue->status_schema->active

=cut

sub unresolved_dependencies {
    my $self = shift;
    my $deps = RT::Model::TicketCollection->new( current_user => $self->current_user );

    my @live_statuses = RT::Model::Queue->status_schema->valid('initial', 'active');
    foreach my $status (@live_statuses) {
        $deps->limit_status( value => $status );
    }
    $deps->limit_depended_on_by( $self->id );

    return ($deps);

}



=head2 all_depended_on_by

Returns an array of RT::Model::Ticket objects which (directly or indirectly)
depends on this ticket; takes an optional 'type' argument in the param
hash, which will limit returned tickets to that type, as well as cause
tickets with that type to serve as 'leaf' nodes that stops the recursive
dependency search.

=cut

sub all_depended_on_by {
    my $self = shift;
    return $self->_all_linked_tickets(
        link_type  => 'DependsOn',
        direction => 'target',
        @_
    );
}

=head2 all_depends_on

Returns an array of RT::Model::Ticket objects which this ticket (directly or
indirectly) depends on; takes an optional 'type' argument in the param
hash, which will limit returned tickets to that type, as well as cause
tickets with that type to serve as 'leaf' nodes that stops the
recursive dependency search.

=cut

sub all_depends_on {
    my $self = shift;
    return $self->_all_linked_tickets(
        link_type  => 'DependsOn',
        direction => 'base',
        @_
    );
}

sub _all_linked_tickets {
    my $self = shift;
    my %args = (
        link_type  => undef,
        direction => undef,
        type      => undef,
        _found    => {},
        _top      => 1,
        @_
    );

    my $dep = $self->_links( $args{direction}, $args{link_type} );
    while ( my $link = $dep->next() ) {
        my $uri =
          $args{direction} eq 'target' ? $link->base_uri : $link->targetURI;
        next unless ( $uri->is_local() );
        my $obj =
          $args{direction} eq 'target' ? $link->base_obj : $link->target_obj;
        next if $args{_found}{ $obj->id };

        if ( !$args{'type'} ) {
            $args{_found}{ $obj->id } = $obj;
            $obj->_all_linked_tickets( %args, _top => 0 );
        }
        elsif ( $obj->type eq $args{type} ) {
            $args{_found}{ $obj->id } = $obj;
        }
        else {
            $obj->_all_linked_tickets( %args, _top => 0 );
          }
        
    }

    if ( $args{_top} ) {
        return map { $args{_found}{$_} } sort keys %{ $args{_found} };
    } else {
        return 1;
    }
}



=head2 depends_on

This returns an L<RT::Model::LinkCollection> object which references
all the tickets that this ticket depends on

=cut

sub depends_on {
    my $self = shift;
    return ( $self->_links( 'base', 'DependsOn' ) );
}



=head2 links DIRECTION [TYPE]

Return links (L<RT::Model::LinkCollection>) to/from this object.

DIRECTION is either 'base' or 'target'.

TYPE is a type of links to return, it can be omitted to get
links of any type.

=cut

*Links = \&_Links;

sub _links {
    my $self = shift;

    #TODO: Field isn't the right thing here. but I ahave no idea what mnemonic ---
    #tobias meant by $f
    my $field = shift;
    my $type = shift || "";

    unless ( $self->{"$field$type"} ) {
        $self->{"$field$type"} = RT::Model::LinkCollection->new( current_user => $self->current_user );

        # at least to myself
        $self->{"$field$type"}->limit(
            column           => $field,
            value            => $self->uri,
            entry_aggregator => 'OR'
        );
        $self->{"$field$type"}->limit(
            column => 'type',
            value  => $type
        ) if ($type);
    }
    return ( $self->{"$field$type"} );
}






=head2 format_type

Takes a type and returns a string that is more human readable.

=cut

sub format_type {
    my $self = shift;
    my %args = (
        type => '',
        @_
    );
    $args{type} =~ s/([A-Z])/" " . lc $1/ge;
    return $args{type};
}



=head2 format_link

Takes either a target or a base and returns a string of human friendly text.

=cut

sub format_link {
    my $self = shift;
    my %args = (
        object   => undef,
        fall_back => '',
        @_
    );
    my $text = "URI " . $args{fall_back};
    if ( $args{object} && $args{object}->isa("RT::Model::Ticket") ) {
        $text = "Ticket " . $args{object}->id;
    }
    return $text;
}


=head2 _add_link

Takes a paramhash of type and one of base or target. Adds that link to this object.

Returns C<link id>, C<message> and C<exist> flag.


=cut

sub _add_link {
    my $self = shift;
    my %args = (
        target => '',
        base   => '',
        type   => '',
        silent => undef,
        @_
    );

    # Remote_link is the URI of the object that is not this ticket
    my $remote_link;
    my $direction;

    if ( $args{'base'} and $args{'target'} ) {
        Jifty->log->debug( "$self tried to create a link. both base and target were specified" );
        return ( 0, _("Can't specifiy both base and target") );
    } elsif ( $args{'base'} ) {
        $args{'target'} = $self->uri();
        $remote_link    = $args{'base'};
        $direction      = 'target';
    } elsif ( $args{'target'} ) {
        $args{'base'} = $self->uri();
        $remote_link  = $args{'target'};
        $direction    = 'base';
    } else {
        return ( 0, _('Either base or target must be specified') );
    }

    # {{{ Check if the link already exists - we don't want duplicates
    use RT::Model::Link;
    my $old_link = RT::Model::Link->new( current_user => $self->current_user );
    $old_link->load_by_params(
        base   => $args{'base'},
        type   => $args{'type'},
        target => $args{'target'}
    );
    if ( $old_link->id ) {
        Jifty->log->debug("$self Somebody tried to duplicate a link");
        return ( $old_link->id, _("Link already exists"), 1 );
    }

    # }}}

    # Storing the link in the DB.
    my $link = RT::Model::Link->new( current_user => $self->current_user );
    my ( $linkid, $linkmsg ) = $link->create(
        target => $args{target},
        base   => $args{base},
        type   => $args{'type'}
    );

    unless ($linkid) {
        Jifty->log->error( "Link could not be Created: " . $linkmsg );
        return ( 0, _("Link could not be Created") );
    }
    my $basetext = $self->format_link(
        object   => $link->base_obj,
        fall_back => $args{base}
    );
    my $targettext = $self->format_link(
        object   => $link->target_obj,
        fall_back => $args{target}
    );
    my $typetext = $self->format_type( type => $args{type} );
    my $trans_string =
      "$basetext $typetext $targettext.";
    return ( $linkid, $trans_string );

}



=head2 _delete_link

Delete a link. takes a paramhash of base, target and Type.
Either base or target must be null. The null value will 
be replaced with this ticket\'s id

=cut

sub _delete_link {
    my $self = shift;
    my %args = (
        base   => undef,
        target => undef,
        type   => undef,
        @_
    );

    #we want one of base and target. we don't care which
    #but we only want _one_

    my $direction;
    my $remote_link;

    if ( $args{'base'} and $args{'target'} ) {
        Jifty->log->debug("$self ->_delete_link. got both base and target");
        return ( 0, _("Can't specifiy both base and target") );
    } elsif ( $args{'base'} ) {
        $args{'target'} = $self->uri();
        $remote_link    = $args{'base'};
        $direction      = 'target';
    } elsif ( $args{'target'} ) {
        $args{'base'} = $self->uri();
        $remote_link  = $args{'target'};
        $direction    = 'base';
    } else {
        Jifty->log->error("base or target must be specified");
        return ( 0, _('Either base or target must be specified') );
    }

    my $link = RT::Model::Link->new( current_user => $self->current_user );
    Jifty->log->debug( "Trying to load link: " . $args{'base'} . " " . $args{'type'} . " " . $args{'target'} );

    $link->load_by_params(
        base   => $args{'base'},
        type   => $args{'type'},
        target => $args{'target'}
    );

    #it's a real link.
    if ( $link->id ) {
        my $basetext = $self->format_link(
            object   => $link->base_obj,
            fall_back => $args{base}
        );
        my $targettext = $self->format_link(
            object   => $link->target_obj,
            fall_back => $args{target}
        );
        my $typetext = $self->format_type( type => $args{type} );
        my $linkid = $link->id;
        $link->delete();
        my $TransString = "$basetext no longer $typetext $targettext.";
        return ( 1, $TransString );
    }

    #if it's not a link we can find
    else {
        Jifty->log->debug("Couldn't find that link");
        return ( 0, _("Link not found") );
    }
}





=head2 _new_transaction  PARAMHASH

Private function to create a RT::Model::Transaction->new Object for this ticket update

=cut

sub _new_transaction {
    my $self = shift;
    my %args = (
        time_taken      => undef,
        type            => undef,
        old_value       => undef,
        new_value       => undef,
        old_reference   => undef,
        new_reference   => undef,
        reference_type  => undef,
        data            => undef,
        field           => undef,
        mime_obj        => undef,
        activate_scrips => 1,
        commit_scrips   => 1,
        @_
    );

    my $old_ref  = $args{'old_reference'};
    my $new_ref  = $args{'new_reference'};
    my $ref_type = $args{'reference_type'};
    if ( $old_ref or $new_ref ) {
        $ref_type ||= ref($old_ref) || ref($new_ref);
        if ( !$ref_type ) {
            Jifty->log->error("Reference type not specified for transaction");
            return;
        }
        $old_ref = $old_ref->id if ref($old_ref);
        $new_ref = $new_ref->id if ref($new_ref);
    }

    my $trans = RT::Model::Transaction->new( current_user => $self->current_user );
    my ( $transaction, $msg ) = $trans->create(
        object_id       => $self->id,
        object_type     => ref($self),
        time_taken      => $args{'time_taken'},
        type            => $args{'type'},
        data            => $args{'data'},
        field           => $args{'field'},
        new_value       => $args{'new_value'},
        old_value       => $args{'old_value'},
        new_reference   => $new_ref,
        old_reference   => $old_ref,
        reference_type  => $ref_type,
        mime_obj        => $args{'mime_obj'},
        activate_scrips => $args{'activate_scrips'},
        commit_scrips   => $args{'commit_scrips'},
    );

    # Rationalize the object since we may have done things to it during the caching.
    $self->load( $self->id );

    Jifty->log->warn($msg) unless $transaction;

    if ( defined $args{'time_taken'} and $self->can('_update_time_taken') ) {
        $self->_update_time_taken( $args{'time_taken'} );
    }
    if ( RT->config->get('use_transaction_batch') and $transaction ) {
        push @{ $self->{_transaction_batch} }, $trans
            if $args{'commit_scrips'};
    }
    return ( $transaction, $msg, $trans );
}



=head2 transactions

Returns an L<RT::Model::TransactionCollection> object of all
transactions on this record object

=cut

sub transactions {
    my $self = shift;

    use RT::Model::TransactionCollection;
    my $transactions = RT::Model::TransactionCollection->new( current_user => $self->current_user );

    #If the user has no rights, return an empty object
    $transactions->limit(
        column => 'object_id',
        value  => $self->id,
    );
    $transactions->limit(
        column => 'object_type',
        value  => ref($self),
    );

    return ($transactions);
}

#

sub custom_fields {
    my $self = shift;
    my $cfs  = RT::Model::CustomFieldCollection->new( current_user => $self->current_user );

    # XXX handle multiple types properly
    $cfs->limit_to_lookup_type( $self->custom_field_lookup_type );
    $cfs->limit_to_global_or_object_id( $self->_lookup_id( $self->custom_field_lookup_type ) );

    return $cfs;
}

# TODO: This _only_ works for RT::Class classes. it doesn't work, for example, for RT::FM classes.

sub _lookup_id {
    my $self    = shift;
    my $lookup  = shift;
    my @classes = ( $lookup =~ /RT::Model::(\w+)-/g );

    my $object = $self;
    foreach my $class ( reverse @classes ) {

        # Convert FooBar into foo_bar
        $class =~ s/.([[:upper:]])/_$1/g;

        my $method = lc($class);
        $object = $object->$method;
    }

    return $object->id;
}

=head2 custom_field_lookup_type

Returns the path RT uses to figure out which custom fields apply to this object.

=cut

sub custom_field_lookup_type {
    my $self = shift;
    return ref($self);
}


=head2 add_custom_field_value { Field => column, value => value }

value should be a string. column can be any identifier of a CustomField
supported by L</load_custom_field_by_identifier> method.

Adds value as a value of CustomField column. If this is a single-value custom field,
deletes the old value.
If value is not a valid value for the custom field, returns
(0, 'Error message' ) otherwise, returns ($id, 'Success Message') where
$id is ID of Created L<RT::Model::ObjectCustomFieldValue> object.

=cut

sub add_custom_field_value {
    my $self = shift;
    $self->_add_custom_field_value(@_);
}

sub _add_custom_field_value {
    my $self = shift;
    my %args = (
        field              => undef,
        value              => undef,
        large_content      => undef,
        content_type       => undef,
        record_transaction => 1,
        @_
    );
    if ( !defined $args{'field'} ) {
        $args{'field'} ||= delete $args{'column'};
        unless ( $args{'field'} ) {
            Carp::cluck( "Field argument missing. maybe a mistaken s// changed Field to Column?" );

        }
    }

    my $cf = $self->load_custom_field_by_identifier( $args{'field'} );
    unless ( $cf->id ) {
        return ( 0, _( "Custom field %1 not found", $args{'field'} ) );
    }

    my $OCFs = $self->custom_fields;
    $OCFs->limit( column => 'id', value => $cf->id );
    unless ( $OCFs->count ) {
        return ( 0, _( "Custom field %1 does not apply to this object", $args{'field'} ) );
    }

    # empty string is not correct value of any CF, so undef it
    foreach (qw(value large_content)) {
        $args{$_} = undef if defined $args{$_} && !length $args{$_};
    }

    if ( $cf->can('validate_value') ) {
        unless ( $cf->validate_value( $args{'value'} ) ) {
            return ( 0, _("Invalid value for custom field") );
        }
    }

    # If the custom field only accepts a certain # of values, delete the existing
    # value and record a "changed from foo to bar" transaction
    unless ( $cf->unlimited_values ) {

        # Load up a ObjectCustomFieldValues object for this custom field and this ticket
        my $values = $cf->values_for_object($self);

        # We need to whack any old values here.  In most cases, the custom field should
        # only have one value to delete.  In the pathalogical case, this custom field
        # used to be a multiple and we have many values to whack....
        my $cf_values = $values->count;

        if ( $cf_values > $cf->max_values ) {
            my $i = 0;    #We want to delete all but the max we can currently have , so we can then
                          # execute the same code to "change" the value from old to new
            while ( my $value = $values->next ) {
                $i++;
                if ( $i < $cf_values ) {
                    my ( $val, $msg ) = $cf->delete_value_for_object(
                        object  => $self,
                        content => $value->content
                    );
                    unless ($val) {
                        return ( 0, $msg );
                    }
                    my ( $transaction_id, $Msg, $transaction_obj ) = $self->_new_transaction(
                        type          => 'custom_field',
                        field         => $cf->id,
                        old_reference => $value,
                    );
                }
            }
            $values->redo_search
                if $i;    # redo search if have deleted at least one value
        }

        my ( $old_value, $old_content );
        if ( $old_value = $values->first ) {
            $old_content = $old_value->content;
            $old_content = undef
                if defined $old_content && !length $old_content;

            my $is_the_same = 1;
            if ( defined $args{'value'} ) {
                $is_the_same = 0
                    unless defined $old_content
                        && lc $old_content eq lc $args{'value'};
            } else {
                $is_the_same = 0 if defined $old_content;
            }
            if ($is_the_same) {
                my $old_content = $old_value->large_content;
                if ( defined $args{'large_content'} ) {
                    $is_the_same = 0
                        unless defined $old_content
                            && $old_content eq $args{'large_content'};
                } else {
                    $is_the_same = 0 if defined $old_content;
                }
            }

            return $old_value->id if $is_the_same;
        }

        my ( $new_value_id, $value_msg ) = $cf->add_value_for_object(
            object        => $self,
            content       => $args{'value'},
            large_content => $args{'large_content'},
            content_type  => $args{'content_type'},
        );

        unless ($new_value_id) {
            return ( 0, _( "Could not add new custom field value: %1", $value_msg ) );
        }

        my $new_value = RT::Model::ObjectCustomFieldValue->new( current_user => $self->current_user );
        $new_value->load($new_value_id);

        # now that adding the new value was successful, delete the old one
        if ($old_value) {
            my ( $val, $msg ) = $old_value->delete();
            return ( 0, $msg ) unless $val;
        }

        if ( $args{'record_transaction'} ) {
            my ( $transaction_id, $Msg, $transaction_obj ) = $self->_new_transaction(
                type          => 'custom_field',
                field         => $cf->id,
                old_reference => $old_value,
                new_reference => $new_value,
            );
        }

        my $new_content = $new_value->content;
        unless ( defined $old_content && length $old_content ) {
            return ( $new_value_id, _( "%1 %2 added", $cf->name, $new_content ) );
        } elsif ( !defined $new_content || !length $new_content ) {
            return ( $new_value_id, _( "%1 %2 deleted", $cf->name, $old_content ) );
        } else {
            return ( $new_value_id, _( "%1 %2 changed to %3", $cf->name, $old_content, $new_content ) );
        }

    }

    # otherwise, just add a new value and record "new value added"
    else {
        my ( $new_value_id, $msg ) = $cf->add_value_for_object(
            object        => $self,
            content       => $args{'value'},
            large_content => $args{'large_content'},
            content_type  => $args{'content_type'},
        );

        unless ($new_value_id) {
            return ( 0, _( "Could not add new custom field value: %1", $msg ) );
        }
        if ( $args{'record_transaction'} ) {
            my ( $tid, $msg ) = $self->_new_transaction(
                type           => 'custom_field',
                field          => $cf->id,
                new_reference  => $new_value_id,
                reference_type => 'RT::Model::ObjectCustomFieldValue',
            );
            unless ($tid) {
                return ( 0, _( "Couldn't create a transaction: %1", $msg ) );
            }
        }
        return ( $new_value_id, _( "%1 added as a value for %2", $args{'value'}, $cf->name ) );
    }
}



=head2 delete_custom_field_value { Field => column, value => value }

Deletes value as a value of CustomField column.

value can be a string, a CustomFieldValue or a ObjectCustomFieldValue.

If value is not a valid value for the custom field, returns
(0, 'Error message' ) otherwise, returns (1, 'Success Message')

=cut

sub delete_custom_field_value {
    my $self = shift;
    my %args = (
        field    => undef,
        value    => undef,
        value_id => undef,
        @_
    );

    my $cf = $self->load_custom_field_by_identifier( $args{'field'} );
    unless ( $cf->id ) {
        return ( 0, _( "Custom field %1 not found", $args{'field'} ) );
    }

    my ( $val, $msg ) = $cf->delete_value_for_object(
        object  => $self,
        id      => $args{'value_id'},
        content => $args{'value'},
    );
    unless ($val) {
        return ( 0, $msg );
    }

    my ( $transaction_id, $Msg, $transaction_obj ) = $self->_new_transaction(
        type           => 'custom_field',
        field          => $cf->id,
        old_reference  => $val,
        reference_type => 'RT::Model::ObjectCustomFieldValue',
    );
    unless ($transaction_id) {
        return ( 0, _( "Couldn't create a transaction: %1", $Msg ) );
    }

    return ( $transaction_id, _( "%1 is no longer a value for custom field %2", $transaction_obj->old_value, $cf->name ) );
}



=head2 first_custom_field_value column

Return the content of the first value of CustomField column for this ticket
Takes a field id or name

=cut

sub first_custom_field_value {
    my $self   = shift;
    my $field  = shift;
    my $values = $self->custom_field_values($field);
    return undef unless my $first = $values->first;
    return $first->content;
}


=head2 custom_field_values column

Return a ObjectCustomFieldValues object of all values of the CustomField whose
id or name is column for this record.

Returns an RT::Model::ObjectCustomFieldValueCollection object

=cut

sub custom_field_values {
    my $self  = shift;
    my $field = shift;

    if ($field) {
        my $cf = $self->load_custom_field_by_identifier($field);

        # we were asked to search on a custom field we couldn't find
        unless ( $cf->id ) {
            Jifty->log->warn("Couldn't load custom field by '$field' identifier");
            return RT::Model::ObjectCustomFieldValueCollection->new( current_user => $self->current_user );
        }
        return ( $cf->values_for_object($self) );
    }

    # we're not limiting to a specific custom field;
    my $ocfs = RT::Model::ObjectCustomFieldValueCollection->new( current_user => $self->current_user );
    $ocfs->limit_to_object($self);
    return $ocfs;
}

=head2 load_custom_field_by_identifier IDENTIFER

Find the custom field has id or name IDENTIFIER for this object.

If no valid field is found, returns an empty RT::Model::CustomField object.

=cut

sub load_custom_field_by_identifier {
    my $self  = shift;
    my $field = shift;

    unless ( defined $field ) {
        Carp::confess;
    }
    my $cf = RT::Model::CustomField->new( current_user => $self->current_user );

    if ( UNIVERSAL::isa( $field, "RT::Model::CustomField" ) ) {
        $cf->load_by_id( $field->id );
    } elsif ( $field =~ /^\d+$/ ) {
        $cf = RT::Model::CustomField->new( current_user => $self->current_user );
        $cf->load_by_id($field);
    } else {

        my $cfs = $self->custom_fields();
        $cfs->limit( column => 'name', value => $field, case_sensitive => 0 );
        $cf = $cfs->first || RT::Model::CustomField->new( current_user => $self->current_user );
    }
    return $cf;
}




sub wiki_base {
    return RT->config->get('web_path') . "/index.html?q=";
}

=head2 _get_current_user

This overridden version of C<_get_current_user> allows user object to
be coerced into CurrentUser object during C<Model->new( current_user => $u)>.

=cut

sub _get_current_user {
    my ($self, %args) = @_;
    return if ( ref($self) && $self->current_user );

    if ( my $cu = $args{'current_user'}) {
        $args{'current_user'} = RT::CurrentUser->new(user_object => $cu)
            if $cu->isa('RT::Model::User');
    }

    return $self->SUPER::_get_current_user(%args);
}

1;
