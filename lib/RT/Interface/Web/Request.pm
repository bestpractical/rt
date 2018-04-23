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

package RT::Interface::Web::Request;

use strict;
use warnings;

use HTML::Mason::PSGIHandler;
use base qw(HTML::Mason::Request::PSGI);
use Params::Validate qw(:all);

my %deprecated = (
    '/Admin/CustomFields/Modify.html' => {
        'AfterUpdateCustomFieldValue' => { Remove => '4.6' },
    },
);

sub new {
    my $class = shift;
    $class->valid_params( %{ $class->valid_params },cgi_request => { type => OBJECT, optional => 1 } );
    return $class->SUPER::new(@_);
}


=head2 callback

Takes hash with optional C<CallbackPage>, C<CallbackName>
and C<CallbackOnce> arguments, other arguments are passed
throught to callback components.

=over 4

=item CallbackPage

Page path relative to the root, leading slash is mandatory.
By default is equal to path of the caller component.

=item CallbackName

Name of the callback. C<Default> is used unless specified.

=item CallbackOnce

By default is false, otherwise runs callbacks only once per
process of the server. Such callbacks can be used to fill
structures.

=back

Searches for callback components in
F<< /Callbacks/<any dir>/CallbackPage/CallbackName >>, for
example F</Callbacks/MyExtension/autohandler/Default> would
be called as default callback for F</autohandler>.

=cut

{
my %cache = ();
my %called = ();
sub callback {
    my ($self, %args) = @_;

    my $name = delete $args{'CallbackName'} || 'Default';
    my $page = delete $args{'CallbackPage'} || $self->callers(0)->path;
    unless ( $page ) {
        $RT::Logger->error("Couldn't get a page name for callbacks");
        return;
    }

    my $CacheKey = "$page--$name";
    return 1 if delete $args{'CallbackOnce'} && $called{ $CacheKey };
    $called{ $CacheKey } = 1;

    my $callbacks = $cache{ $CacheKey };
    unless ( $callbacks ) {
        $callbacks = [];
        my $path  = "/Callbacks/*$page/$name";
        my @roots = RT::Interface::Web->ComponentRoots;
        my %seen;
        @$callbacks = (
            grep defined && length,
            # Skip backup files, files without a leading package name,
            # and files we've already seen
            grep !$seen{$_}++ && !m{/\.} && !m{~$} && m{^/Callbacks/[^/]+\Q$page/$name\E$},
            map { sort $self->interp->resolver->glob_path($path, $_) }
            @roots
        );
        foreach my $comp (keys %seen) {
            next unless $seen{$comp} > 1;
            $RT::Logger->error("Found more than one occurrence of the $comp callback.  This may cause only one of the callbacks to run.  Look for the duplicate Callback in your @roots");
        }

        $cache{ $CacheKey } = $callbacks unless RT->Config->Get('DevelMode');

        if (@{ $callbacks } && $deprecated{$page}{$name}) {
            RT->Deprecated(
                Message => "The callback $name on page $page is deprecated",
                Detail  => "Callback list:\n" . join("\n", @{ $callbacks }),
                Stack   => 0,
                %{ $deprecated{$page}{$name} },
            );
        }
    }

    my @rv;
    foreach my $cb ( @$callbacks ) {
        push @rv, scalar $self->comp( $cb, %args );
    }
    return @rv;
}

sub clear_callback_cache {
    %cache = %called = ();
}
}

=head2 request_path

Returns path of the request.

Very close to C<< $m->request_comp->path >>, but if called in a dhandler returns
path of the request without dhandler name, but with dhandler arguments instead.

=cut

sub request_path {
    my $self = shift;

    my $path = $self->request_comp->path;
    # disabled dhandlers, not RT case, but anyway
    return $path unless my $dh_name = $self->dhandler_name;
    # not a dhandler
    return $path unless substr($path, -length("/$dh_name")) eq "/$dh_name";
    substr($path, -length $dh_name) = $self->dhandler_arg;
    return $path;
}

=head2 abort

Logs any recorded SQL statements for this request before calling the standard
abort.

=cut

sub abort {
    my $self = shift;
    RT::Interface::Web::LogRecordedSQLStatements(
        RequestData => {
            Path => $self->request_path,
        },
    );
    return $self->SUPER::abort(@_);
}

1;
