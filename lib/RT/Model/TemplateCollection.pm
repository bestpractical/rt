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

=head1 name

  RT::Model::TemplateCollection - a collection of RT template objects

=head1 SYNOPSIS

  use RT::Model::TemplateCollection;

=head1 description


=head1 METHODS


=cut

use strict;
use warnings;

package RT::Model::TemplateCollection;
use base qw/RT::SearchBuilder/;

# {{{ sub _init

=head2 _init

  Returns RT::Model::TemplateCollection specific init info like table and primary key names

=cut

sub _init {

    my $self = shift;
    $self->{'table'}       = "Templates";
    $self->{'primary_key'} = "id";
    return ( $self->SUPER::_init(@_) );
}

# }}}

# {{{ limit_ToNotInQueue

=head2 limit_to_not_in_queue

Takes a queue id # and limits the returned set of templates to those which 
aren't that queue's templates.

=cut

sub limit_to_not_in_queue {
    my $self     = shift;
    my $queue_id = shift;
    $self->limit(
        column   => 'queue',
        value    => "$queue_id",
        operator => '!='
    );
}

# }}}

# {{{ limit_ToGlobal

=head2 limit_to_global

Takes no arguments. Limits the returned set to "Global" templates
which can be used with any queue.

=cut

sub limit_to_global {
    my $self     = shift;
    my $queue_id = shift;
    $self->limit(
        column   => 'queue',
        value    => "0",
        operator => '='
    );
}

# }}}

# {{{ limit_ToQueue

=head2 limit_to_queue

Takes a queue id # and limits the returned set of templates to that queue's
templates

=cut

sub limit_to_queue {
    my $self     = shift;
    my $queue_id = shift;
    $self->limit(
        column   => 'queue',
        value    => "$queue_id",
        operator => '='
    );
}

# }}}

# {{{ sub new_item

=head2 new_item

Returns a new empty template object

=cut

sub new_item {
    my $self = shift;

    use RT::Model::Template;
    my $item = RT::Model::Template->new();
    return ($item);
}

# }}}

# {{{ sub next

=head2 next

Returns the next template that this user can see.

=cut

sub next {
    my $self = shift;

    my $templ = $self->SUPER::next();
    if ( ( defined($templ) ) and ( ref($templ) ) ) {

        # If it's part of a queue, and the user can read templates in
        # that queue, or the user can globally read templates, show it
        if ($templ->queue && $templ->current_user_has_queue_right('ShowTemplate')
            or $templ->current_user->has_right(
                object => RT->system,
                right  => 'ShowTemplate'
            )
            )
        {
            return ($templ);
        }

        #If the user doesn't have the right to show this template
        else {
            return ( $self->next() );
        }
    }

    #if there never was any template
    else {
        return (undef);
    }

}

# }}}

1;

