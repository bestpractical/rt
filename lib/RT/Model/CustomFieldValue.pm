use warnings;
use strict;

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

package RT::Model::CustomFieldValue;

no warnings qw/redefine/;
use base qw/RT::Record/;
sub table {'CustomFieldValues'}
use Jifty::DBI::Schema;
use Jifty::DBI::Record schema {
    column creator => type is 'int(11)', max_length is 11, default is '0';
    column
        last_updated_by => type is 'int(11)',
        max_length is 11, default is '0';
    column sort_order   => type is 'int(11)', max_length is 11, default is '0';
    column custom_field => type is 'int(11)', max_length is 11, default is '0';
    column created     => type is 'datetime', default is '';
    column last_updated => type is 'datetime', default is '';
    column name => type is 'varchar(200)', max_length is 200, default is '';
    column
        description => type is 'varchar(255)',
        max_length is 255, default is '';

};

=head2 Validatename

Override the default Validatename method that stops custom field values
from being integers.

=cut

sub create {
    my $self = shift;
    my %args = (
        custom_field => 0,
        name        => '',
        description => '',
        sort_order   => 0,
        category    => '',
        @_,
    );

    my $cf_id
        = ref $args{'custom_field'}
        ? $args{'custom_field'}->id
        : $args{'custom_field'};

    my $cf = RT::Model::CustomField->new;
    $cf->load($cf_id);
    unless ( $cf->id ) {
        return ( 0, _( "Couldn't load Custom Field #%1", $cf_id ) );
    }
    unless ( $cf->current_user_has_right('AdminCustomField') ) {
        return ( 0, _('Permission denied') );
    }

    my ( $id, $msg ) = $self->SUPER::create(
        custom_field => $cf_id,
        map { $_ => $args{$_} } qw(name description sort_order)
    );
    return ( $id, $msg ) unless $id;

    if ( defined $args{'category'} && length $args{'category'} ) {

        # $self would be loaded at this stage
        my ( $status, $msg ) = $self->set_category( $args{'category'} );
        unless ($status) {
            Jifty->log->error("Couldn't set category: $msg");
        }
    }

    return ( $id, $msg );
}

sub category {
    my $self = shift;
    my $attr = $self->first_attribute('category') or return undef;
    return $attr->content;
}

sub set_category {
    my $self     = shift;
    my $category = shift;
    if ( defined $category && length $category ) {
        return $self->set_attribute(
            name    => 'category',
            Content => $category,
        );
    } else {
        my ( $status, $msg ) = $self->delete_attribute('category');
        unless ($status) {
            Jifty->log->warn("Couldn't delete atribute: $msg");
        }

        # return true even if there was no category
        return ( 1, _('category unset') );
    }
}

sub validate_name {
    return defined $_[1] && length $_[1];
}

1;

