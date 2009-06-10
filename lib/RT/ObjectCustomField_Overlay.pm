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
package RT::ObjectCustomField;

use strict;
no warnings qw(redefine);

sub Create {
    my $self = shift;
    my %args = ( 
                CustomField => '0',
                ObjectId => '0',
		SortOrder => undef,
		  @_);

    if (!defined $args{SortOrder}) {
	my $CF = $self->CustomFieldObj($args{'CustomField'});
	my $ObjectCFs = RT::ObjectCustomFields->new($self->CurrentUser);
	$ObjectCFs->LimitToObjectId($args{'ObjectId'});
	$ObjectCFs->LimitToLookupType($CF->LookupType);

	$args{SortOrder} = $ObjectCFs->Count + 1;
    }

    $self->SUPER::Create(
                         CustomField => $args{'CustomField'},
                         ObjectId => $args{'ObjectId'},
                         SortOrder => $args{'SortOrder'},
		     );
}

sub Delete {
    my $self = shift;

    my $ObjectCFs = RT::ObjectCustomFields->new($self->CurrentUser);
    $ObjectCFs->LimitToObjectId($self->ObjectId);
    $ObjectCFs->LimitToLookupType($self->CustomFieldObj->LookupType);

    # Move everything below us up
    my $sort_order = $self->SortOrder;
    while (my $OCF = $ObjectCFs->Next) {
	my $this_order = $OCF->SortOrder;
	next if $this_order <= $sort_order; 
	$OCF->SetSortOrder($this_order - 1);
    }

    $self->SUPER::Delete;
}

sub CustomFieldObj {
    my $self = shift;
    my $id = shift || $self->CustomField;
    my $CF = RT::CustomField->new($self->CurrentUser);
    $CF->Load($id) or die "Cannot load CustomField $id";
    return $CF;
}

1;
