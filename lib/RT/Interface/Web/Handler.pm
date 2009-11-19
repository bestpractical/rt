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
package RT::Interface::Web::Handler;

use CGI qw/-private_tempfiles/;
use MIME::Entity;
use Text::Wrapper;
use Time::ParseDate;
use Time::HiRes;
use HTML::Entities;
use HTML::Scrubber;

=head2 cleanup_request

Clean ups globals, caches and other things that could be still
there from previous requests:

=over 4

=item Rollback any uncommitted transaction(s)

=item Flush the ACL cache

=item Flush records cache of the L<DBIx::SearchBuilder> if
WebFlushDbCacheEveryRequest option is enabled, what is true by default
and is not recommended to change.

=item Clean up state of RT::ScripAction::SendEmail using 'clean_slate' method

=item Flush tmp GnuPG key preferences

=back

=cut

sub cleanup_request {

    if ( Jifty->handle && Jifty->handle->transaction_depth ) {
        Jifty->handle->force_rollback;
        Jifty->log->fatal( "Transaction not committed. Usually indicates a software fault." . "Data loss may have occurred" );
    }

    # Clean out the ACL cache. the performance impact should be marginal.
    # Consistency is imprived, too.
    RT::Model::Principal->invalidate_acl_cache();

    my $record_base_class = Jifty->config->framework('Database')->{'RecordBaseClass'};
    $record_base_class->flush_cache
        if $record_base_class->can("flush_cache") &&
           RT->config->get('web_flush_db_cache_every_request');

    # cleanup global squelching of the mails
    require RT::ScripAction::SendEmail;
    RT::ScripAction::SendEmail->clean_slate;

    if ( RT->config->get('gnupg')->{'enable'} ) {
        require RT::Crypt::GnuPG;
        RT::Crypt::GnuPG::use_key_for_encryption();
        RT::Crypt::GnuPG::use_key_for_signing(undef);
    }
}

package Jifty::View::Mason::Handler;
{
    no warnings 'redefine';
    my $oldsub = \&config;
    *config = sub {
        my %config = $oldsub->();
        push @{ $config{comp_root} },
          [ local => RT->local_html_path ];
        for my $plugin ( @{ RT->plugins } ) {
            push @{ $config{comp_root} },
              [ 'plugin-' . $plugin->name => $plugin->component_root ];
        }
        %config = ( 
            %config,
            error_format => ( Jifty->config->framework('DevelMode') ? 'html' : 'brief' ),
        );
        return %config;
    };
}

=head2 callback

Takes hash with optional C<callback_page>, C<callback_name>
and C<callback_once> arguments, other arguments are passed
throught to callback components.

=over 4

=item callback_page

Page path relative to the root, leading slash is mandatory.
By default is equal to path of the caller component.

=item callback_name

name of the callback. C<Default> is used unless specified.

=item callback_once

By default is false, otherwise runs callbacks only once per
process of the server. Such callbacks can be used to fill
structures.

=back

Searches for callback components in
F<< /Callbacks/<any dir>/callback_page/callback_name >>, for
example F</Callbacks/MyExtension/autohandler/Default> would
be called as default callback for F</autohandler>.

=cut

{
    package Jifty::View::Mason::Request;

    no warnings 'redefine';
    my %cache  = ();
    my %called = ();

    sub callback {
        my ( $self, %args ) = @_;

        my $name = delete $args{'callback_name'} || 'Default';
        my $page = delete $args{'callback_page'} || $self->callers(0)->path;
        unless ($page) {
            Jifty->log->error("Couldn't get a page name for callbacks");
            return;
        }

        my $CacheKey = "$page--$name";
        return 1 if delete $args{'callback_once'} && $called{$CacheKey};
        $called{$CacheKey} = 1;

        my $callbacks = $cache{$CacheKey};
        unless ($callbacks) {
            $callbacks = [];
            my $path = "/Callbacks/*$page/$name";
            my @roots
                = map $_->[1], $HTML::Mason::VERSION <= 1.28
                ? $self->interp->resolver->comp_root_array
                : $self->interp->comp_root_array;

            my %seen;
            @$callbacks = (
                sort grep defined && length,

                # Skip backup files, files without a leading package name,
                # and files we've already seen
                grep !$seen{$_}++
                    && !m{/\.}
                    && !m{~$}
                    && m{^/Callbacks/[^/]+\Q$page/$name\E$},
                map $self->interp->resolver->glob_path( $path, $_ ),
                @roots
            );

            $cache{$CacheKey} = $callbacks
                unless Jifty->config->framework('DevelMode');
        }

        my @rv;
        push @rv, scalar $self->comp( $_, %args ) foreach @$callbacks;
        return @rv;
    }
}


1;
