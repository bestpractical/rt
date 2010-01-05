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

package RT::View::Admin::CustomFields;
use Jifty::View::Declare -base;
use base 'RT::View::CRUD';

require RT::View::Admin::CustomFields::Values;
alias RT::View::Admin::CustomFields::Values under 'values/';

use constant page_title      => 'Custom Field Management';
use constant object_type     => 'CustomField';
use constant display_columns =>
  qw(id name description type lookup_type max_values pattern
  sort_order repeated link_value_to include_content_for_value values_class disabled );

use constant create_columns =>
  qw(name description type lookup_type max_values pattern
  sort_order repeated link_value_to include_content_for_value disabled );

template 'objects' => page { title => _('Applied Objects for Custom Field') }
content {
    my $self = shift;
    my $cf = RT::Model::CustomField->new;
    $cf->load( get('id') );
    my $moniker = 'cf_select_ocfs';
    my $action = new_action(
        class   => 'SelectObjectCustomFields',
        moniker => $moniker,
    );

    $action->record($cf);

    with( name => $moniker ), form {
        render_action($action);
        form_submit( label => _('Save') );
    };

};

template 'group_rights' => page { title => _('Group Rights for Custom Field') }
content {
    my $self = shift;
    show( 'rights', 'group' );

};

template 'user_rights' => page { title => _('User Rights for Custom Field') } content {
    my $self = shift;
    show( 'rights', 'user' );

};

private template 'rights' => sub {
    my $self = shift;
    my $type = shift || 'user';

    my $class   = 'Edit' . ucfirst($type) . 'Rights';
    my $moniker = 'cf_edit_' . $type . '_rights';

    my $rights = new_action(
        class   => $class,
        moniker => $moniker,
    );

    my $cf = RT::Model::CustomField->new;
    $cf->load(get('id'));
    $rights->record( $cf );

    with( name => $moniker ), form {
        render_action($rights);
        form_submit( label => _('Save') );
    };
};
sub _current_collection {
    my $self = shift; 
    my $collection = $self->SUPER::_current_collection( @_ );
    $collection->{'find_disabled_rows'} = get('include_disabled');
    return $collection;    
}


1;

