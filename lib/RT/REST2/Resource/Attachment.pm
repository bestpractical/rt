# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2022 Best Practical Solutions, LLC
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

package RT::REST2::Resource::Attachment;
use strict;
use warnings;

use MIME::Base64;
use Encode;

use Moose;
use namespace::autoclean;

extends 'RT::REST2::Resource::Record';
with 'RT::REST2::Resource::Record::Readable',
     'RT::REST2::Resource::Record::Hypermedia';

sub dispatch_rules {
    Path::Dispatcher::Rule::Regex->new(
        regex => qr{^/attachment/?$},
        block => sub { { record_class => 'RT::Attachment' } },
    ),
    Path::Dispatcher::Rule::Regex->new(
        regex => qr{^/attachment/(\d+)/?$},
        block => sub { { record_class => 'RT::Attachment', record_id => shift->pos(1) } },
    )
}

# Tweak serialize to base-64-encode Content
around 'serialize' => sub {
    my ($orig, $self) = @_;
    my $data = $self->$orig(@_);
    return $data unless defined $data->{Content};

    # Encode as UTF-8 if it's an internal Perl Unicode string, or if it
    # contains wide characters.  If the raw data does indeed contain
    # wide characters, encode_base64 will die anyway, so encoding
    # seems like a safer choice.
    if (utf8::is_utf8($data->{Content}) || $data->{Content} =~ /[^\x00-\xFF]/) {
        # Encode internal Perl string to UTF-8
        $data->{Content} = encode('UTF-8', $data->{Content}, Encode::FB_PERLQQ);
    }
    $data->{Content} = encode_base64($data->{Content});
    return $data;
};

__PACKAGE__->meta->make_immutable;

1;

