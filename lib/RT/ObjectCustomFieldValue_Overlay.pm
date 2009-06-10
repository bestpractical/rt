# BEGIN BPS TAGGED BLOCK {{{
# 
# COPYRIGHT:
#  
# This software is Copyright (c) 1996-2009 Best Practical Solutions, LLC 
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
package RT::ObjectCustomFieldValue;

use strict;
no warnings qw(redefine);


sub Create {
    my $self = shift;
    my %args = (
                CustomField => '0',
                ObjectType => '',
                ObjectId => '0',
                Disabled => '0',
                Content => '',
                LargeContent => '',
                ContentType => '',
                ContentEncoding => '',

          @_);

   
    if( $args{'Content'} && length($args{'Content'}) > 255 && !$args{'LargeContent'} ) {

        $args{'LargeContent'} = $args{'Content'};
        $args{'Content'} = '';
        $args{'ContentType'} = 'text/plain';
    }

    ( $args{'ContentEncoding'}, $args{'LargeContent'} ) =
      $self->_EncodeLOB( $args{'LargeContent'}, $args{'ContentType'} )
      if ( $args{'LargeContent'} );

    $self->SUPER::Create(
                         CustomField => $args{'CustomField'},
                         ObjectType => $args{'ObjectType'},
                         ObjectId => $args{'ObjectId'},
                         Disabled => $args{'Disabled'},
                         Content => $args{'Content'},
                         LargeContent => $args{'LargeContent'},
                         ContentType => $args{'ContentType'},
                         ContentEncoding => $args{'ContentEncoding'},
);



}


sub LargeContent {
    my $self = shift;
    $self->_DecodeLOB( $self->ContentType, $self->ContentEncoding,
        $self->_Value( 'LargeContent', decode_utf8 => 0 ) );

}




=head2 LoadByTicketContentAndCustomField { Ticket => TICKET, CustomField => CUSTOMFIELD, Content => CONTENT }

Loads a custom field value by Ticket, Content and which CustomField it's tied to

=cut


sub LoadByTicketContentAndCustomField {
    my $self = shift;
    my %args = ( Ticket => undef,
                CustomField => undef,
                Content => undef,
                @_
                );


    $self->LoadByCols( Content => $args{'Content'},
                         CustomField => $args{'CustomField'},
                         ObjectType => 'RT::Ticket',
                         ObjectId => $args{'Ticket'},
			 Disabled => 0
			 );

    
}

sub LoadByObjectContentAndCustomField {
    my $self = shift;
    my %args = ( Object => undef,
                CustomField => undef,
                Content => undef,
                @_
                );

    my $obj = $args{'Object'} or return;

    $self->LoadByCols( Content => $args{'Content'},
                         CustomField => $args{'CustomField'},
                         ObjectType => ref($obj),
                         ObjectId => $obj->Id,
			 Disabled => 0
			 );

}


=head2 Content

Return this custom field's content. If there's no "regular"
content, try "LargeContent"

=cut


sub Content {
    my $self = shift;
    my $content = $self->SUPER::Content;
    if (!$content && $self->ContentType eq 'text/plain') {
       return $self->LargeContent(); 
    } else {
        return $content;
    }
}


=head2 Object

Returns the object this value applies to

=cut

sub Object {
    my $self  = shift;
    my $Object = $self->__Value('ObjectType')->new($self->CurrentUser);
    $Object->Load($self->__Value('ObjectId'));
    return($Object);
}


=head2 Delete

Disable this value. Used to remove "current" values from records while leaving them in the history.

=cut


sub Delete {
    my $self = shift;
    $self->SetDisabled(1);
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

sub _FillInTemplateURL {

    my $self = shift;

    my $url = shift;

    $url =~ s/__id__/@{[$self->ObjectId]}/g;
    $url =~ s/__CustomField__/@{[$self->Content]}/g;

    return $url;
}


=head2 ValueLinkURL

Returns a filled in URL template for this ObjectCustomFieldValue, suitable for 
constructing a hyperlink in RT's webui. Returns undef if this custom field doesn't have
a LinkValueTo

=cut

sub LinkValueTo {
    my $self = shift;
    return $self->_FillInTemplateURL($self->CustomFieldObj->LinkValueTo);
}



=head2 ValueIncludeURL

Returns a filled in URL template for this ObjectCustomFieldValue, suitable for 
constructing a hyperlink in RT's webui. Returns undef if this custom field doesn't have
a IncludeContentForValue

=cut

sub IncludeContentForValue {
    my $self = shift;
    return $self->_FillInTemplateURL($self->CustomFieldObj->IncludeContentForValue);
}




1;
