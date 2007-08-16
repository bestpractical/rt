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
package RT::Interface::Web::Request;

use strict;
use warnings;

our $VERSION = '0.30';
use base qw(HTML::Mason::Request);

sub new {
    my $class = shift;

    my $new_class = $HTML::Mason::ApacheHandler::VERSION ?
        'HTML::Mason::Request::ApacheHandler' :
            $HTML::Mason::CGIHandler::VERSION ?
                'HTML::Mason::Request::CGI' :
                    'HTML::Mason::Request';

    $class->alter_superclass( $new_class );
    $class->valid_params( %{ $new_class->valid_params } );
    return $class->SUPER::new(@_);
}

=head2 callback

Method replaces deprecated component C<Element/Callback>.

Takes hash with optional C<CallbackPage>, C<CallbackName>
and C<CallabckOnce> arguments, other arguments are passed
throught to callback components.

=over4

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
        $RT::Logger->error("Coulnd't get a page name for callbacks");
        return;
    }

    my $CacheKey = "$page--$name";
    return 1 if delete $args{'CallbackOnce'} && $called{ $CacheKey };
    ++$called{ $CacheKey };

    my $callbacks = $cache{ $CacheKey };
    unless ( $callbacks ) {
        my $path  = "/Callbacks/*$page/$name";
        my @roots = map $_->[1],
                        $HTML::Mason::VERSION <= 1.28
                            ? $self->interp->resolver->comp_root_array
                            : $self->interp->comp_root_array;

        my %seen;
        @$callbacks = sort map { 
                # Skip backup files, files without a leading package name,
                # and files we've already seen
                grep !$seen{$_}++ && !m{/\.} && !m{~$} && m{^/Callbacks/[^/]+\Q$page/$name\E$},
                $self->interp->resolver->glob_path($path, $_);
            } @roots;

        $cache{ $CacheKey } = $callbacks unless RT->Config->Get('DevelMode');
    }

    my @rv;
    push @rv, scalar $self->comp( $_, %args) foreach @$callbacks;
    return @rv;
}
}

1;
