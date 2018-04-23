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

use strict;
use warnings;

package RT::ObjectCustomFields;
use base 'RT::SearchBuilder::AddAndSort';

use RT::CustomField;
use RT::ObjectCustomField;

sub Table { 'ObjectCustomFields'}

sub LimitToCustomField {
    my $self = shift;
    my $id = shift;
    $self->Limit( FIELD => 'CustomField', VALUE => $id );
}

sub LimitToLookupType {
    my $self = shift;
    my $lookup = shift;

    $self->{'_cfs_alias'} ||= $self->Join(
        ALIAS1 => 'main',
        FIELD1 => 'CustomField',
        TABLE2 => 'CustomFields',
        FIELD2 => 'id',
    );
    $self->Limit(
        ALIAS    => $self->{'_cfs_alias'},
        FIELD    => 'LookupType',
        OPERATOR => '=',
        VALUE    => $lookup,
    );
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

sub _DoSearch {
    my $self = shift;
    if ($self->{'_cfs_alias'}) {
    $self->Limit( ALIAS           => $self->{'_cfs_alias'},
                 FIELD           => 'Disabled',
                 OPERATOR        => '!=',
                 VALUE           =>  1);
    }
    $self->SUPER::_DoSearch()
}

RT::Base->_ImportOverlays();

1;
