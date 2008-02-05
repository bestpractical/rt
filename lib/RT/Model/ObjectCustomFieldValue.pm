
use strict;
use warnings;

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
package RT::Model::ObjectCustomFieldValue;

no warnings qw(redefine);

use base qw/RT::Record/;
sub table {'ObjectCustomFieldValues'}
use Jifty::DBI::Schema;
use Jifty::DBI::Record schema {
    column
        content_type => type is 'varchar(80)',
        max_length is 80, default is '';
    column large_content => type is 'blob', default is '';
    column Creator => type is 'int(11)', max_length is 11, default is '0';
    column object_id => type is 'int(11)', max_length is 11, default is '0';
    column
        last_updated_by => type is 'int(11)',
        max_length is 11, default is '0';
    column disabled => type is 'smallint(6)', max_length is 6, default is '0';
    column sort_order => type is 'int(11)', max_length is 11, default is '0';
    column Created => type is 'datetime', default is '';
    column custom_field => type is 'int(11)', max_length is 11, default is '0';
    column
        content => type is 'varchar(255)',
        max_length is 255, default is '';
    column
        content_encoding => type is 'varchar(80)',
        max_length is 80, default is '';
    column LastUpdated => type is 'datetime', default is '';
    column
        object_type => type is 'varchar(255)',
        max_length is 255, default is '';

};

sub custom_field_obj {

    my $self = shift;
    unless ( $self->{cf} ) {
        $self->{cf} = RT::Model::CustomField->new;
        $self->{cf}->load( $self->custom_field );
    }
    return $self->{cf};
}

sub create {
    my $self = shift;
    my %args = (
        custom_field     => 0,
        object_type     => '',
        object_id       => 0,
        disabled        => 0,
        content         => '',
        large_content    => undef,
        content_type     => '',
        content_encoding => '',
        @_,
    );

    if ( defined $args{'content'} && length( $args{'content'} ) > 255 ) {
        if ( defined $args{'large_content'} && length $args{'large_content'} ) {
            Jifty->log->error(
                "content is longer than 255 and large_content specified");
        } else {
            $args{'large_content'} = $args{'content'};
            $args{'content'}      = '';
            $args{'content_type'} ||= 'text/plain';
        }
    }

    ( $args{'content_encoding'}, $args{'large_content'} )
        = $self->_encode_lob( $args{'large_content'}, $args{'content_type'} )
        if defined $args{'large_content'};

    return $self->SUPER::create(
        custom_field     => $args{'custom_field'},
        object_type     => $args{'object_type'},
        object_id       => $args{'object_id'},
        disabled        => $args{'disabled'},
        content         => $args{'content'},
        large_content    => $args{'large_content'},
        content_type     => $args{'content_type'},
        content_encoding => $args{'content_encoding'},
    );
}

sub large_content {
    my $self = shift;
    return $self->_decode_lob( $self->content_type, $self->content_encoding,
        $self->_value( 'large_content', decode_utf8 => 0 ) );
}

=head2 LoadByTicketContentAndCustomField { Ticket => TICKET, custom_field => customfield, content => CONTENT }

Loads a custom field value by Ticket, content and which custom_field it's tied to

=cut

sub load_by_ticket_content_and_custom_field {
    my $self = shift;
    my %args = (
        ticket      => undef,
        custom_field => undef,
        content     => undef,
        @_
    );

    return $self->load_by_cols(
        content     => $args{'content'},
        custom_field => $args{'custom_field'},
        object_type => 'RT::Model::Ticket',
        object_id   => $args{'ticket'},
        disabled    => 0
    );
}

sub load_by_object_content_and_custom_field {
    my $self = shift;
    my %args = (
        object      => undef,
        custom_field => undef,
        content     => undef,
        @_
    );

    my $obj = $args{'object'} or return;

    return $self->load_by_cols(
        content     => $args{'content'},
        custom_field => $args{'custom_field'},
        object_type => ref($obj),
        object_id   => $obj->id,
        disabled    => 0
    );
}

=head2 content

Return this custom field's content. If there's no "regular"
content, try "large_content"

=cut

sub content {
    my $self    = shift;
    my $content = $self->_value('content');
    if ( !( defined $content && length $content )
        && $self->content_type eq 'text/plain' )
    {
        return $self->large_content;
    } else {
        return $content;
    }
}

=head2 object

Returns the object this value applies to

=cut

sub object {
    my $self   = shift;
    my $object = $self->__value('object_type')->new;
    $object->load_by_id( $self->__value('object_id') );
    return $object;
}

=head2 Delete

Disable this value. Used to remove "current" values from records while leaving them in the history.

=cut

sub delete {
    my $self = shift;
    return $self->set_disabled(1);
}

=head2 _FillInTemplateURL URL

Takes a URL containing placeholders and returns the URL as filled in for this 
ObjectCustomFieldValue.

Available placeholders:

=over

=item __id__

The id of the object in question.

=item __CustomField__

The value of this custom field for the object in question.

=back

=cut

sub _fill_in_template_url {

    my $self = shift;

    my $url = shift;

    $url =~ s/__id__/@{[$self->object_id]}/g;
    $url =~ s/__CustomField__/@{[$self->content]}/g;

    return $url;
}

=head2 ValueLinkURL

Returns a filled in URL template for this ObjectCustomFieldValue, suitable for 
constructing a hyperlink in RT's webui. Returns undef if this custom field doesn't have
a link_value_to

=cut

sub link_value_to {
    my $self = shift;
    return $self->_fill_in_template_url(
        $self->custom_field_obj->link_value_to );
}

=head2 ValueIncludeURL

Returns a filled in URL template for this ObjectCustomFieldValue, suitable for 
constructing a hyperlink in RT's webui. Returns undef if this custom field doesn't have
a include_content_for_value

=cut

sub include_content_for_value {
    my $self = shift;
    return $self->_fill_in_template_url(
        $self->custom_field_obj->include_content_for_value );
}

1;
