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

package RT::CustomFieldValues;

use strict;
use warnings;

use base 'RT::SearchBuilder';

use RT::CustomFieldValue;

sub Table { 'CustomFieldValues'}

sub _Init {
    my $self = shift;

  # By default, order by SortOrder
  $self->OrderByCols(
         { ALIAS => 'main',
           FIELD => 'SortOrder',
           ORDER => 'ASC' },
         { ALIAS => 'main',
           FIELD => 'Name',
           ORDER => 'ASC' },
         { ALIAS => 'main',
           FIELD => 'id',
           ORDER => 'ASC' },
     );

    return ( $self->SUPER::_Init(@_) );
}
# {{{ sub LimitToCustomField

=head2 LimitToCustomField FIELD

Limits the returned set to values for the custom field with Id FIELD

=cut
  
sub LimitToCustomField {
    my $self = shift;
    my $cf = shift;
    return $self->Limit(
        FIELD    => 'CustomField',
        VALUE    => $cf,
        OPERATOR => '=',
    );
}

=head2 SetCustomFieldObject

Store the CustomField object which loaded this CustomFieldValues collection.
Consumers of CustomFieldValues collection (such as External Custom Fields)
can now work out how they were loaded (off a Queue or Ticket or something else)
by inspecting the CustomField.

=cut

sub SetCustomFieldObject {
    my $self = shift;
    return $self->{'custom_field'} = shift;
}

=head2 CustomFieldObject

Returns the CustomField object used to load this CustomFieldValues collection.
Relies on $CustomField->Values having been called, is not set on manual loads.

=cut

sub CustomFieldObject {
    my $self = shift;
    return $self->{'custom_field'};
}

=head2 AddRecord

Propagates the CustomField object from the Collection
down to individual CustomFieldValue objects.

=cut

sub AddRecord {
    my $self = shift;
    my $CFV = shift;

    $CFV->SetCustomFieldObj($self->CustomFieldObject);

    push @{$self->{'items'}}, $CFV;
    $self->{'rows'}++;
}


RT::Base->_ImportOverlays();

1;
