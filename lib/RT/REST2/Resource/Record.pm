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

package RT::REST2::Resource::Record;
use strict;
use warnings;

use Moose;
use namespace::autoclean;

extends 'RT::REST2::Resource';

use Web::Machine::Util qw( create_date );
use RT::REST2::Util qw( record_type );

has 'record_class' => (
    is  => 'ro',
    isa => 'ClassName',
);

has 'record_id' => (
    is  => 'ro',
    isa => 'Int',
);

has 'record' => (
    is          => 'ro',
    isa         => 'RT::Record',
    required    => 1,
    lazy_build  => 1,
);

sub _build_record {
    my $self = shift;
    my $class = $self->record_class;
    my $id = $self->record_id;

    $class->require;

    my $record = $class->new( $self->current_user );
    $record->Load($id) if $id;
    return $record;
}

sub base_uri {
    my $self = shift;
    my $base = RT::REST2->base_uri;
    my $type = lc record_type($self);
    return join '/', $base, $type;
}

sub resource_exists {
    $_[0]->record->id
}

sub forbidden {
    my $self = shift;
    return 0 unless $self->record->id;

    my $can_see = $self->record->can("CurrentUserCanSee");
    return 1 if $can_see and not $self->record->$can_see();
    return 0;
}

sub last_modified {
    my $self = shift;
    return unless $self->record->_Accessible("LastUpdated" => "read");
    my $updated = $self->record->LastUpdatedObj->RFC2616
        or return;
    return create_date($updated);
}

sub allowed_methods {
    my $self = shift;
    my @ok;
    push @ok, 'GET', 'HEAD' if $self->DOES("RT::REST2::Resource::Record::Readable");
    push @ok, 'DELETE'      if $self->DOES("RT::REST2::Resource::Record::Deletable");
    push @ok, 'PUT', 'POST' if $self->DOES("RT::REST2::Resource::Record::Writable");
    return \@ok;
}

sub finish_request {
    my $self = shift;
    # Ensure the record object is destroyed before the request finishes, for
    # any cleanup that may need to happen (i.e. TransactionBatch).
    $self->clear_record;
    return $self->SUPER::finish_request(@_);
}

__PACKAGE__->meta->make_immutable;

1;
