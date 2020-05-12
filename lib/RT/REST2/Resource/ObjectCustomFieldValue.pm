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

package RT::REST2::Resource::ObjectCustomFieldValue;
use strict;
use warnings;

use Moose;
use namespace::autoclean;
use RT::REST2::Util qw( error_as_json );

extends 'RT::REST2::Resource::Record';
with 'RT::REST2::Resource::Record::WithETag';

sub dispatch_rules {
    Path::Dispatcher::Rule::Regex->new(
        regex => qr{^/download/cf/(\d+)/?$},
        block => sub { { record_class => 'RT::ObjectCustomFieldValue', record_id => shift->pos(1) } },
    )
}

sub allowed_methods { ['GET', 'HEAD'] }

sub content_types_provided {
    my $self = shift;
    { [ {$self->record->ContentType || 'text/plain; charset=utf-8' => 'to_binary'} ] };
}

sub forbidden {
    my $self = shift;
    return 0 unless $self->record->id;
    return !$self->record->CurrentUserHasRight('SeeCustomField');
}

sub to_binary {
    my $self = shift;
    unless ($self->record->CustomFieldObj->Type =~ /^(?:Image|Binary)$/) {
        return error_as_json(
            $self->response,
            \400, "Only Image and Binary CustomFields can be downloaded");
    }

    my $content_type = $self->record->ContentType || 'text/plain; charset=utf-8';
    if (RT->Config->Get('AlwaysDownloadAttachments')) {
        $self->response->headers_out->{'Content-Disposition'} = "attachment";
    }
    elsif (!RT->Config->Get('TrustHTMLAttachments')) {
        $content_type = 'text/plain; charset=utf-8' if ($content_type =~ /^text\/html/i);
    }

    $self->response->content_type($content_type);

    my $content = $self->record->LargeContent;
    $self->response->content_length(length $content);
    $self->response->body($content);
}

__PACKAGE__->meta->make_immutable;

1;
