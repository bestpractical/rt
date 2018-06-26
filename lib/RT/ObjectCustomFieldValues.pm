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

package RT::ObjectCustomFieldValues;

use strict;
use warnings;
use 5.010;

use base 'RT::SearchBuilder';

use RT::ObjectCustomFieldValue;

# Set up the OCFV cache for faster comparison on add/update
our $_OCFV_CACHE;
ClearOCFVCache();

sub Table { 'ObjectCustomFieldValues'}

sub _Init {
    my $self = shift;
    $self->{'with_disabled_column'} = 1;

  # By default, order by SortOrder
  $self->OrderByCols(
         { ALIAS => 'main',
           FIELD => 'SortOrder',
           ORDER => 'ASC' },
         { ALIAS => 'main',
           FIELD => 'id',
           ORDER => 'ASC' },
     );

    return ( $self->SUPER::_Init(@_) );
}

=head2 ClearOCFVCache

Cleans out and reinitializes the OCFV cache

=cut

sub ClearOCFVCache {
    $_OCFV_CACHE = {}
}

# {{{ sub LimitToCustomField

=head2 LimitToCustomField FIELD

Limits the returned set to values for the custom field with Id FIELD

=cut
  
sub LimitToCustomField {
    my $self = shift;
    my $cf = shift;
    return $self->Limit(
        FIELD => 'CustomField',
        VALUE => $cf,
    );
}



=head2 LimitToObject OBJECT

Limits the returned set to values for the given OBJECT

=cut

sub LimitToObject {
    my $self = shift;
    my $object = shift;
    $self->Limit(
        FIELD => 'ObjectType',
        VALUE => ref($object),
    );
    return $self->Limit(
        FIELD => 'ObjectId',
        VALUE => $object->Id,
    );

}


=head2 HasEntry CONTENT LARGE_CONTENT

If this collection has an entry with content that eq CONTENT and large content
that eq LARGE_CONTENT then returns the entry, otherwise returns undef.

=cut


sub HasEntry {
    my $self = shift;
    my $value = shift;
    my $large_content = shift;
    return undef unless defined $value && length $value;

    my $first = $self->First;
    return undef unless $first;  # No entries to check

    # Key should be the same for all values of the same ocfv
    my $ocfv_key = $first->GetOCFVCacheKey;

    # This cache relieves performance issues when adding large numbers of values
    # to a CF since each add compares against the full list each time.

    unless ( $_OCFV_CACHE->{$ocfv_key} ) {
        # Load the cache with existing values
        foreach my $item ( @{$self->ItemsArrayRef} ) {
            push @{$_OCFV_CACHE->{$ocfv_key}}, {
                'ObjectId'       => $item->Id,
                'CustomFieldObj' => $item->CustomFieldObj,
                'Content'        => $item->_Value('Content'),
                'LargeContent'   => $item->LargeContent };
        }
    }

    my %canon_value;
    my $item_id;
    foreach my $item ( @{$_OCFV_CACHE->{$ocfv_key}} ) {
        my $cf = $item->{'CustomFieldObj'};
        my $args = $canon_value{ $cf->Type };
        if ( !$args ) {
            $args = { Content => $value, LargeContent => $large_content };
            my ($ok, $msg) = $cf->_CanonicalizeValue( $args );
            next unless $ok;
            $canon_value{ $cf->Type } = $args;
        }

        if ( $cf->Type eq 'Select' ) {
            # select is case insensitive
            $item_id = $item->{'ObjectId'} if lc $item->{'Content'} eq lc $args->{Content};
        }
        else {
            if ( ($item->{'Content'} // '') eq $args->{Content} ) {
                if ( defined $item->{'LargeContent'} ) {
                    $item_id = $item->{'ObjectId'}
                      if defined $args->{LargeContent}
                      && $item->{'LargeContent'} eq $args->{LargeContent};
                }
                else {
                    $item_id = $item->{'ObjectId'} unless defined $args->{LargeContent};
                }
            } elsif ( $item->{'LargeContent'} && $args->{Content} ) {
                $item_id = $item->{'ObjectId'} if ($item->{'LargeContent'} eq $args->{Content});
            }
        }
        last if $item_id;
    }

    if ( $item_id ) {
        my $ocfv = RT::ObjectCustomFieldValue->new( $self->CurrentUser );
        my ($ret, $msg) = $ocfv->Load($item_id);
        RT::Logger->error("Unable to load object custom field value from id: $item_id $msg")
            unless $ret;
        return $ocfv;
    }
    else {
        return undef;
    }
}

sub _DoSearch {
    my $self = shift;

    if ( exists $self->{'find_expired_rows'} ) {
        RT->Deprecated( Arguments => "find_expired_rows", Instead => 'find_disabled_rows', Remove => '4.6' );
        $self->{'find_disabled_rows'} = $self->{'find_expired_rows'};
    }

    return $self->SUPER::_DoSearch(@_);
}

sub _DoCount {
    my $self = shift;

    if ( exists $self->{'find_expired_rows'} ) {
        RT->Deprecated( Arguments => "find_expired_rows", Instead => 'find_disabled_rows', Remove => '4.6' );
        $self->{'find_disabled_rows'} = $self->{'find_expired_rows'};
    }

    return $self->SUPER::_DoCount(@_);
}

RT::Base->_ImportOverlays();

# Clear the OCVF cache on exit to release connected RT::Ticket objects.
#
# Without this, there could be warnings generated like "Too late to safely run
# transaction-batch scrips...". You can test this by commenting it out and running
# some cf tests, e.g. perl -Ilib t/customfields/enter_one.t
END { ClearOCFVCache(); }


1;
