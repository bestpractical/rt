# BEGIN BPS TAGGED BLOCK {{{
# 
# COPYRIGHT:
#  
# This software is Copyright (c) 1996-2005 Best Practical Solutions, LLC 
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


sub Delete {
    my $self = shift;
    $self->SetDisabled(1);
}

1;
