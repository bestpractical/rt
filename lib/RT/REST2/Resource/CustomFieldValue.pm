# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2026 Best Practical Solutions, LLC
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

package RT::REST2::Resource::CustomFieldValue;
use strict;
use warnings;

use Moose;
use namespace::autoclean;
use JSON ();
use RT::REST2::Util qw(expand_uid error_as_json);

extends 'RT::REST2::Resource::Record';
with 'RT::REST2::Resource::Record::Readable',
     'RT::REST2::Resource::Record::Hypermedia',
     'RT::REST2::Resource::Record::Deletable',
     'RT::REST2::Resource::Record::Writable';

has 'customfield' => (
    is  => 'ro',
    isa => 'RT::CustomField',
);

sub dispatch_rules {
    Path::Dispatcher::Rule::Regex->new(
        regex => qr{^/customfield/(\d+)/value/?$},
        block => sub {
            my ($match, $req) = @_;
            my $cf_id = $match->pos(1);
            my $cf = RT::CustomField->new($req->env->{"rt.current_user"});
            $cf->Load($cf_id);
            return { record_class => 'RT::CustomFieldValue', customfield => $cf }
        },
    ),
    Path::Dispatcher::Rule::Regex->new(
        regex => qr{^/customfield/(\d+)/value/(\d+)/?$},
        block => sub {
            my ($match, $req) = @_;
            my $cf_id = $match->pos(1);
            my $cf = RT::CustomField->new($req->env->{"rt.current_user"});
            $cf->Load($cf_id);
            return { record_class => 'RT::CustomFieldValue', record_id => shift->pos(2), customfield => $cf }
        },
    )
}

sub forbidden {
    my $self = shift;
    my $method = $self->request->method;
    if ($method eq 'GET') {
        return !$self->customfield->CurrentUserHasRight('SeeCustomField');
    } else {
        return !($self->customfield->CurrentUserHasRight('AdminCustomField') ||$self->customfield->CurrentUserHasRight('AdminCustomFieldValues'));
    }
}

# Allow both HASH (single value) and ARRAY (bulk values) JSON bodies.
# The Writable role's RequestBodyIsJSON only accepts HASH, so we
# override the check here.
around 'malformed_request' => sub {
    my $orig = shift;
    my $self = shift;

    my $request = $self->request;
    return 0 unless $request->method =~ /^(PUT|POST)$/;
    return 0 unless $request->header('Content-Type') =~ /^application\/json/;
    return 0 unless $request->content;

    my $json = eval { JSON::from_json($request->content) };
    if ($@ or not $json) {
        my $error = $@;
        $error =~ s/ at \S+? line \d+\.?$//;
        error_as_json($self->response, undef, "JSON parse error: $error");
        return 1;
    }
    elsif (ref $json ne 'HASH' && ref $json ne 'ARRAY') {
        error_as_json($self->response, undef, "JSON object must be a HASH or ARRAY");
        return 1;
    }

    return 0;
};

# Wrap from_json to handle bulk creation when an array is POSTed.
# Single-object POSTs fall through to the standard Writable behavior.
around 'from_json' => sub {
    my $orig = shift;
    my $self = shift;
    my $json = JSON::decode_json($self->request->content);

    # Single value — delegate to the standard Writable flow
    return $self->$orig(@_) if ref $json eq 'HASH';

    # Bulk creation
    my @results;
    for my $item (@$json) {
        my ($ok, $msg) = $self->create_record($item);
        if ($ok && !ref($ok)) {
            push @results, {
                type => 'customfieldvalue',
                id   => $self->record->id + 0,
                _url => RT::REST2->base_uri . '/customfield/' . $self->customfield->id . '/value/' . $self->record->id,
            };
        }
        else {
            push @results, { message => $msg || "Create failed for unknown reason" };
        }
    }

    $self->response->body(JSON::encode_json(\@results));
    return;
};

sub create_record {
    my $self = shift;
    my $data = shift;

    my ($ok, $msg) = $self->customfield->AddValue(%$data);
    $self->record->Load($ok) if $ok;
    return ($ok, $msg);
}

sub delete_resource {
    my $self = shift;

    my ($ok, $msg) = $self->customfield->DeleteValue($self->record->id);
    return $ok;
}

sub hypermedia_links {
    my $self = shift;
    my $record = $self->record;
    my $cf = $self->customfield;

    my $class = blessed($record);
    $class =~ s/^RT:://;
    $class = lc $class;
    my $id = $record->id;

    my $cf_class = blessed($cf);
    $cf_class =~ s/^RT:://;
    $cf_class = lc $cf_class;
    my $cf_id = $cf->id;

    my $cf_entry = expand_uid($cf->UID);

    my $links = [
        {
            ref  => 'self',
            type => $class,
            id   => $id,
            _url => RT::REST2->base_uri . "/$cf_class/$cf_id/$class/$id",
        },
        {
            %$cf_entry,
            ref  => 'customfield',
        },
    ];

    return $links;
}

RT::Base->_ImportOverlays();

__PACKAGE__->meta->make_immutable;

1;
