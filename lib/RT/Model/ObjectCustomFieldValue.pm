
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
sub table {'Objectcustom_field_values'}
use Jifty::DBI::Schema;
use Jifty::DBI::Record schema {
    column
        ContentType => type is 'varchar(80)',
        max_length is 80, default is '';
    column LargeContent => type is 'longtext', default is '';
    column Creator => type is 'int(11)', max_length is 11, default is '0';
    column object_id => type is 'int(11)', max_length is 11, default is '0';
    column
        LastUpdatedBy => type is 'int(11)',
        max_length is 11, default is '0';
    column disabled => type is 'smallint(6)', max_length is 6, default is '0';
    column SortOrder => type is 'int(11)', max_length is 11, default is '0';
    column Created => type is 'datetime', default is '';
    column CustomField => type is 'int(11)', max_length is 11, default is '0';
    column
        Content => type is 'varchar(255)',
        max_length is 255, default is '';
    column
        ContentEncoding => type is 'varchar(80)',
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
        $self->{cf}->load( $self->CustomField );
    }
    return $self->{cf};
}

sub create {
    my $self = shift;
    my %args = (
        CustomField     => 0,
        object_type     => '',
        object_id       => 0,
        disabled        => 0,
        Content         => '',
        LargeContent    => undef,
        ContentType     => '',
        ContentEncoding => '',
        @_,
    );

    if ( defined $args{'Content'} && length( $args{'Content'} ) > 255 ) {
        if ( defined $args{'LargeContent'} && length $args{'LargeContent'} ) {
            Jifty->log->error(
                "Content is longer than 255 and LargeContent specified");
        } else {
            $args{'LargeContent'} = $args{'Content'};
            $args{'Content'}      = '';
            $args{'ContentType'} ||= 'text/plain';
        }
    }

    ( $args{'ContentEncoding'}, $args{'LargeContent'} )
        = $self->_encode_lob( $args{'LargeContent'}, $args{'ContentType'} )
        if defined $args{'LargeContent'};

    return $self->SUPER::create(
        CustomField     => $args{'CustomField'},
        object_type     => $args{'object_type'},
        object_id       => $args{'object_id'},
        disabled        => $args{'disabled'},
        Content         => $args{'Content'},
        LargeContent    => $args{'LargeContent'},
        ContentType     => $args{'ContentType'},
        ContentEncoding => $args{'ContentEncoding'},
    );
}

sub large_content {
    my $self = shift;
    return $self->_decode_lob( $self->content_type, $self->ContentEncoding,
        $self->_value( 'LargeContent', decode_utf8 => 0 ) );
}

=head2 LoadByTicketContentAndCustomField { Ticket => TICKET, CustomField => customfield, Content => CONTENT }

Loads a custom field value by Ticket, Content and which CustomField it's tied to

=cut

sub load_by_ticket_content_and_custom_field {
    my $self = shift;
    my %args = (
        Ticket      => undef,
        CustomField => undef,
        Content     => undef,
        @_
    );

    return $self->load_by_cols(
        Content     => $args{'Content'},
        CustomField => $args{'CustomField'},
        object_type => 'RT::Model::Ticket',
        object_id   => $args{'Ticket'},
        disabled    => 0
    );
}

sub load_by_object_content_and_custom_field {
    my $self = shift;
    my %args = (
        Object      => undef,
        CustomField => undef,
        Content     => undef,
        @_
    );

    my $obj = $args{'Object'} or return;

    return $self->load_by_cols(
        Content     => $args{'Content'},
        CustomField => $args{'CustomField'},
        object_type => ref($obj),
        object_id   => $obj->id,
        disabled    => 0
    );
}

=head2 Content

Return this custom field's content. If there's no "regular"
content, try "LargeContent"

=cut

sub content {
    my $self    = shift;
    my $content = $self->_value('Content');
    if ( !( defined $content && length $content )
        && $self->content_type eq 'text/plain' )
    {
        return $self->large_content;
    } else {
        return $content;
    }
}

=head2 Object

Returns the object this value applies to

=cut

sub object {
    my $self   = shift;
    my $Object = $self->__value('object_type')->new;
    $Object->load_by_id( $self->__value('object_id') );
    return $Object;
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
    $url =~ s/__CustomField__/@{[$self->Content]}/g;

    return $url;
}

=head2 ValueLinkURL

Returns a filled in URL template for this ObjectCustomFieldValue, suitable for 
constructing a hyperlink in RT's webui. Returns undef if this custom field doesn't have
a LinkValueTo

=cut

sub link_value_to {
    my $self = shift;
    return $self->_fill_in_template_url(
        $self->custom_field_obj->LinkValueTo );
}

=head2 ValueIncludeURL

Returns a filled in URL template for this ObjectCustomFieldValue, suitable for 
constructing a hyperlink in RT's webui. Returns undef if this custom field doesn't have
a IncludeContentForValue

=cut

sub include_content_for_value {
    my $self = shift;
    return $self->_fill_in_template_url(
        $self->custom_field_obj->IncludeContentForValue );
}

1;
