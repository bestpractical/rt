# BEGIN LICENSE BLOCK
# 
# Copyright (c) 1996-2003 Jesse Vincent <jesse@bestpractical.com>
# 
# (Except where explictly superceded by other copyright notices)
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
# Unless otherwise specified, all modifications, corrections or
# extensions to this work which alter its source code become the
# property of Best Practical Solutions, LLC when submitted for
# inclusion in the work.
# 
# 
# END LICENSE BLOCK

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
