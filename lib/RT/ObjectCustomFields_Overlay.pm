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

sub LimitToParentAndComposite {
    my $self = shift;
    my %args = @_;
    my $composite = $args{Composite} or die "Must specify Composite";
    my $ParentObj = $args{Parent};
    my $ParentType = $args{ParentType} || ref($ParentObj) or die "Must specify ParentType";
    my $ParentId = $args{ParentId} || ($ParentObj ? $ParentObj->Id || 0 : 0);
    $self->Limit( FIELD => 'ParentId', VALUE => $ParentId );

    # $self->Limit( FIELD => 'ParentId', VALUE => '0' ) if $ParentId;
    # XXX - Join CF here and limit its composites 
}

sub HasEntryForCustomField {
    my $self = shift;
    my $id = shift;

    my @items = grep {$_->CustomField == $id } @{$self->ItemsArrayRef};

    if ($#items > 1) {
	die "$self HasEntry had a list with more than one of $id in it. this can never happen";
    }
    if ($#items == -1 ) {
	return undef;
    }
    else {
	return ($items[0]);
    }  
}

1;
