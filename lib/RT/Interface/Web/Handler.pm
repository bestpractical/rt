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
use CGI::Cookie;
use Time::ParseDate;
use Time::HiRes;
use HTML::Entities;
use HTML::Scrubber;
use RT::Interface::Web::Handler;
use RT::Interface::Web::Request;
use File::Path qw( rmtree );
use File::Glob qw( bsd_glob );
use File::Spec::Unix;

sub default_handler_args {
    (   comp_root => [ [ local => $RT::MasonLocalComponentRoot ], ( map { [ "plugin-" . $_->name => $_->component_root ] } @{ RT->plugins } ), [ standard => $RT::MasonComponentRoot ] ],
        error_format => ( RT->config->get('DevelMode') ? 'html' : 'brief' ),
        request_class => 'RT::Interface::Web::Request',
        named_component_subs => $INC{'Devel/Cover.pm'} ? 1 : 0,
    );
}

# {{{ sub new

=head2 new

  Constructs a web handler of the appropriate class.
  Takes options to pass to the constructor.

=cut

sub new {
    my $class = shift;
    my $self  = {};
    bless $self, $class;
    return $self;
}

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
    Jifty::DBI::Record::Cachable->flush_cache
        if ( RT->config->get('WebFlushDbCacheEveryRequest')
        and UNIVERSAL::can( 'Jifty::DBI::Record::Cachable' => 'flush_cache' ) );

    # cleanup global squelching of the mails
    require RT::ScripAction::SendEmail;
    RT::ScripAction::SendEmail->clean_slate;

    if ( RT->config->get('GnuPG')->{'enable'} ) {
        require RT::Crypt::GnuPG;
        RT::Crypt::GnuPG::use_key_for_encryption();
        RT::Crypt::GnuPG::use_key_for_signing(undef);
    }
}

# }}}

1;
