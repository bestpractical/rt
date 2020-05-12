# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2019 Best Practical Solutions, LLC
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

package RT::REST2::Resource::Record::Readable;
use strict;
use warnings;

use Moose::Role;
use namespace::autoclean;

requires 'record';
requires 'record_class';
requires 'current_user';
requires 'base_uri';

with 'RT::REST2::Resource::Record::WithETag';

use JSON ();
use RT::REST2::Util qw( serialize_record );
use Scalar::Util qw( blessed );

sub serialize {
    my $self = shift;
    my $record = $self->record;
    my $data = serialize_record($record);

    for my $field (keys %$data) {
        my $result = $data->{$field};
        if ($record->can($field . 'Obj')) {
            my $method = $field . 'Obj';
            my $obj = $record->$method;
            my $param_field = "fields[$field]";
            my @subfields = split(/,/, $self->request->param($param_field) || '');

            for my $subfield (@subfields) {
                my $subfield_result = $self->expand_field($obj, $subfield, $param_field);
                $result->{$subfield} = $subfield_result if defined $subfield_result;
            }
        }
        $data->{$field} = $result;
    }

    if ($self->does('RT::REST2::Resource::Record::Hypermedia')) {
        $data->{_hyperlinks} = $self->hypermedia_links;
    }

    return $data;
}

sub charsets_provided { [ 'utf-8' ] }
sub default_charset   {   'utf-8'   }

sub content_types_provided { [
    { 'application/json' => 'to_json' },
] }

sub to_json {
    my $self = shift;
    return JSON::to_json($self->serialize, { pretty => 1 });
}

1;
