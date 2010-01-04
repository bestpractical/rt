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
use warnings;
use strict;

package RT::View::Admin::CustomFields::Values;
use Jifty::View::Declare -base;
use base 'RT::View::CRUD';

use constant page_title      => 'Custom Field Values Management';
use constant object_type     => 'CustomFieldValue';

use constant display_columns => qw(id name description sort_order);
use constant edit_columns => qw(name description sort_order custom_field);
use constant create_columns => qw(name description sort_order custom_field);

sub _current_collection {
    my $self = shift; 
    my $collection = $self->SUPER::_current_collection( @_ );
    $collection->limit_to_custom_field( get('custom_field') );
    return $collection;    
}

sub create_field_custom_field {
    my $self   = shift;
    my %args   = @_;
    my $action = $args{action};
    render_param(
        $action, 'custom_field',
        render_as     => 'hidden',
        default_value => get('custom_field'),
    );
}

# overwrote this to set custom_field info
private template 'new_item_region' => sub {
    my $self                  = shift;
    my $fragment_for_new_item = get('fragment_for_new_item')
      || $self->fragment_for('new_item');
    my $object_type = $self->object_type;

    return unless $self->record_class->new->current_user_can('create');

    if ($fragment_for_new_item) {
        render_region(
            name     => 'new_item',
            path     => $fragment_for_new_item,
            defaults => { object_type => $object_type, custom_field => get('custom_field') },
        );
    }
};

1;

