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

sub LimitToCustomField {
    my $self = shift;
    my $id = shift;
    $self->Limit( FIELD => 'CustomField', VALUE => $id );
}

sub LimitToObjectId {
    my $self = shift;
    my $id = shift;
    $self->Limit( FIELD => 'ObjectId', VALUE => $id );
}

sub LimitToLookupType {
    my $self = shift;
    my $lookup = shift;
    my $cfs = $self->NewAlias('CustomFields');
    $self->Join( ALIAS1 => 'main',
                FIELD1 => 'CustomField',
                ALIAS2 => $cfs,
                FIELD2 => 'id' );
    $self->Limit( ALIAS           => $cfs,
                 FIELD           => 'LookupType',
                 OPERATOR        => '=',
                 VALUE           => $lookup );
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
