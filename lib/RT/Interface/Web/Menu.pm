# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2018 Best Practical Solutions, LLC
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

package RT::Interface::Web::Menu;

use strict;
use warnings;


use base qw/Class::Accessor::Fast/;
use URI;
use Scalar::Util qw(weaken);

__PACKAGE__->mk_accessors(qw(
    key title description raw_html escape_title sort_order target class attributes
));

=head1 NAME

RT::Interface::Web::Menu - Handle the API for menu navigation

=head1 METHODS

=head2 new PARAMHASH

Creates a new L<RT::Interface::Web::Menu> object.  Possible keys in the
I<PARAMHASH> are L</parent>, L</title>, L</description>, L</path>,
L</raw_html>, L<escape_title>, L</sort_order>, L</class>, L</target>,
L<attributes>, and L</active>.  See the subroutines with the respective name
below for each option's use.

=cut

sub new {
    my $package = shift;
    my $args = ref($_[0]) eq 'HASH' ? shift @_ : {@_};

    my $parent = delete $args->{'parent'};
    $args->{sort_order} ||= 0;

    # Class::Accessor only wants a hashref;
    my $self = $package->SUPER::new( $args );

    # make sure our reference is weak
    $self->parent($parent) if defined $parent;

    return $self;
}


=head2 title [STRING]

Sets or returns the string that the menu item will be displayed as.

=head2 escape_title [BOOLEAN]

Sets or returns whether or not to HTML escape the title before output.

=head2 parent [MENU]

Gets or sets the parent L<RT::Interface::Web::Menu> of this item; this defaults
to null. This ensures that the reference is weakened.

=head2 raw_html [STRING]

Sets the content of this menu item to a raw blob of HTML. When building the
menu, rather than constructing a link, we will return this raw content. No
escaping is done.

=cut

sub parent {
    my $self = shift;
    if (@_) {
        $self->{parent} = shift;
        weaken $self->{parent};
    }

    return $self->{parent};
}


=head2 sort_order [NUMBER]

Gets or sets the sort order of the item, as it will be displayed under
the parent.  This defaults to adding onto the end.

=head2 target [STRING]

Get or set the frame or pseudo-target for this link. something like L<_blank>

=head2 class [STRING]

Gets or sets the CSS class the menu item should have in addition to the default
classes.  This is only used if L</raw_html> isn't specified.

=head2 attributes [HASHREF]

Gets or sets a hashref of HTML attribute name-value pairs that the menu item
should have in addition to the attributes which have their own accessor, like
L</class> and L</target>.  This is only used if L</raw_html> isn't specified.

=head2 path

Gets or sets the URL that the menu's link goes to.  If the link
provided is not absolute (does not start with a "/"), then is is
treated as relative to it's parent's path, and made absolute.

=cut

sub path {
    my $self = shift;
    if (@_) {
        if (defined($self->{path} = shift)) {
            my $base  = ($self->parent and $self->parent->path) ? $self->parent->path : "";
               $base .= "/" unless $base =~ m{/$};
            my $uri = URI->new_abs($self->{path}, $base);
            $self->{path} = $uri->as_string;
        }
    }
    return $self->{path};
}

=head2 active [BOOLEAN]

Gets or sets if the menu item is marked as active.  Setting this
cascades to all of the parents of the menu item.

This is currently B<unused>.

=cut

sub active {
    my $self = shift;
    if (@_) {
        $self->{active} = shift;
        $self->parent->active($self->{active}) if defined $self->parent;
    }
    return $self->{active};
}

=head2 child KEY [, PARAMHASH]

If only a I<KEY> is provided, returns the child with that I<KEY>.

Otherwise, creates or overwrites the child with that key, passing the
I<PARAMHASH> to L<RT::Interface::Web::Menu/new>.  Additionally, the paramhash's
L</title> defaults to the I<KEY>, and the L</sort_order> defaults to the
pre-existing child's sort order (if a C<KEY> is being over-written) or
the end of the list, if it is a new C<KEY>.

If the paramhash contains a key called C<menu>, that will be used instead
of creating a new RT::Interface::Web::Menu.


=cut

sub child {
    my $self  = shift;
    my $key   = shift;
    my $proto = ref $self || $self;

    if ( my %args = @_ ) {

        # Clear children ordering cache
        delete $self->{children_list};

        my $child;
        if ( $child = $args{menu} ) {
            $child->parent($self);
        } else {
            $child = $proto->new(
                {   parent      => $self,
                    key         => $key,
                    title       => $key,
                    escape_title=> 1,
                    %args
                }
            );
        }
        $self->{children}{$key} = $child;

        $child->sort_order( $args{sort_order} || (scalar values %{ $self->{children} })  )
            unless ($child->sort_order());

        # URL is relative to parents, and cached, so set it up now
        $child->path( $child->{path} );

        # Figure out the URL
        my $path = $child->path;

        # Activate it
        if ( defined $path and length $path ) {
            my $base_path = $HTML::Mason::Commands::r->path_info;
            my $query     = $HTML::Mason::Commands::m->cgi_object->query_string;
            $base_path =~ s!/+!/!g;
            $base_path .= "?$query" if defined $query and length $query;

            $base_path =~ s/index\.html$//;
            $base_path =~ s/\/+$//;
            $path =~ s/index\.html$//;
            $path =~ s/\/+$//;

            if ( $path eq $base_path ) {
                $self->{children}{$key}->active(1);
            }
        }
    }

    return $self->{children}{$key};
}

=head2 active_child

Returns the first active child node, or C<undef> is there is none.

=cut

sub active_child {
    my $self = shift;
    foreach my $kid ($self->children) {
        return $kid if $kid->active;
    }
    return undef;
}


=head2 delete KEY

Removes the child with the provided I<KEY>.

=cut

sub delete {
    my $self = shift;
    my $key = shift;
    delete $self->{children_list};
    delete $self->{children}{$key};
}


=head2 has_children

Returns true if there are any children on this menu

=cut

sub has_children {
    my $self = shift;
    if (@{ $self->children}) {
        return 1
    } else {
        return 0;
    }
}


=head2 children

Returns the children of this menu item in sorted order; as an array in
array context, or as an array reference in scalar context.

=cut

sub children {
    my $self = shift;
    my @kids;
    if ($self->{children_list}) {
        @kids = @{$self->{children_list}};
    } else {
        @kids = values %{$self->{children} || {}};
        @kids = sort {$a->{sort_order} <=> $b->{sort_order}} @kids;
        $self->{children_list} = \@kids;
    }
    return wantarray ? @kids : \@kids;
}

=head2 add_after

Called on a child, inserts a new menu item after it and shifts any other
menu items at this level to the right.

L<child> by default would insert at the end of the list of children, unless you
did manual sort_order calculations.

Takes all the regular arguments to L<child>.

=cut

sub add_after { shift->_insert_sibling("after", @_) }

=head2 add_before

Called on a child, inserts a new menu item at the child's location and shifts
the child and the other menu items at this level to the right.

L<child> by default would insert at the end of the list of children, unless you
did manual sort_order calculations.

Takes all the regular arguments to L<child>.

=cut

sub add_before { shift->_insert_sibling("before", @_) }

sub _insert_sibling {
    my $self = shift;
    my $where = shift;
    my $parent = $self->parent;
    my $sort_order;
    for my $contemporary ($parent->children) {
        if ( $contemporary->key eq $self->key ) {
            if ($where eq "before") {
                # Bump the current child and the following
                $sort_order = $contemporary->sort_order;
            }
            elsif ($where eq "after") {
                # Leave the current child along, bump the rest
                $sort_order = $contemporary->sort_order + 1;
                next;
            }
            else {
                # never set $sort_order, act no differently than ->child()
            }
        }
        if ( $sort_order ) {
            $contemporary->sort_order( $contemporary->sort_order + 1 );
        }
    }
    $parent->child( @_, sort_order => $sort_order );
}

=head2 RemoveDashboardMenuItems

Remove dashboards from individual user and system dash menus.

Requires a hash with DashboardId and CurrentUser object.

    $menu->RemoveDashboardMenuItem( DashboardId => $id, CurrentUser => $session{CurrentUser}->UserObj );

=cut

sub RemoveDashboardMenuItem {
    my $self = shift;
    my %args = @_;

    return unless $args{'DashboardId'} and $args{'CurrentUser'};
    my $dashboard_id = $args{'DashboardId'};
    my $current_user = $args{'CurrentUser'};

    # First clear from user's dashboards
    my $dashboards_in_menu = $current_user->Preferences('DashboardsInMenu', {} );

    my @dashboards = grep { $_ != $dashboard_id } @{$dashboards_in_menu->{'dashboards'}};
    $dashboards_in_menu->{'dashboards'} = \@dashboards || [];

    my ($ret, $msg) = $current_user->SetPreferences('DashboardsInMenu', $dashboards_in_menu);
    RT::Logger->warn("Unable to update dashboard for user " . $current_user->Name . ": $msg")
        unless $ret;

    # Now update the system dashboard
    my $system = RT::System->new( $current_user );
    my ($default_dashboards) = $system->Attributes->Named('DashboardsInMenu');

    if ($default_dashboards) {
        $dashboards_in_menu = $default_dashboards->Content;
        my @dashboards = grep { $_ != $dashboard_id } @{$dashboards_in_menu->{'dashboards'}};

        # Update only if we removed one
        if ( @{$dashboards_in_menu->{'dashboards'}} > @dashboards ){
            $dashboards_in_menu->{'dashboards'} = \@dashboards || [];

            ($ret, $msg) = $default_dashboards->SetContent($dashboards_in_menu);
            RT::Logger->warn("Unable to update system dashboard menu: $msg")
                unless $ret;
        }
    }
    return;
}

1;
