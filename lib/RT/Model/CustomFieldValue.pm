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
package RT::Model::CustomFieldValue;
use base qw/RT::Record/;
sub table {'CustomFieldValues'}
use Jifty::DBI::Schema;
use Jifty::DBI::Record schema {
    column sort_order      => type is 'int', max_length is 11, default is '0';
    column custom_field    => type is 'int', max_length is 11, default is '0';
    column name            => type is 'varchar(200)', max_length is 200,
           display_length is 20, default is '';
    column
        description => type is 'varchar(255)', display_length is 60,
        max_length is 255, default is '';

};
use Jifty::Plugin::ActorMetadata::Mixin::Model::ActorMetadata map => {
    created_by => 'creator',
    created_on => 'created',
    updated_by => 'last_updated_by',
    updated_on => 'last_updated'
};


=head2 validatename

Override the default Validatename method that stops custom field values
from being integers.

=cut

sub create {
    my $self = shift;
    my %args = (
        custom_field => 0,
        name         => '',
        description  => '',
        sort_order   => 0,
        @_,
    );

    my $cf_id
        = ref $args{'custom_field'}
        ? $args{'custom_field'}->id
        : $args{'custom_field'};

    my $cf = RT::Model::CustomField->new( current_user => $self->current_user );
    $cf->load($cf_id);
    unless ( $cf->id ) {
        return ( 0, _( "Couldn't load Custom Field #%1", $cf_id ) );
    }
    unless ( $cf->current_user_has_right('AdminCustomField') ) {
        return ( 0, _('Permission Denied') );
    }

    my ( $id, $msg ) = $self->SUPER::create(
        custom_field => $cf_id,
        map { $_ => $args{$_} } qw(name description sort_order)
    );
    return ( $id, $msg ) unless $id;

    return ( $id, $msg );
}

sub validate_name {
    return defined $_[1] && length $_[1];
}

1;

