# BEGIN BPS TAGGED BLOCK {{{
# 
# COPYRIGHT:
#  
# This software is Copyright (c) 1996-2009 Best Practical Solutions, LLC 
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
use File::Path qw( rmtree );
use File::Glob qw( bsd_glob );
use File::Spec::Unix;

sub DefaultHandlerArgs  { (
    comp_root => [
        [ local    => $RT::MasonLocalComponentRoot ],
        [ standard => $RT::MasonComponentRoot ]
    ],
    default_escape_flags => 'h',
    data_dir             => "$RT::MasonDataDir",
    allow_globals        => [qw(%session)],
    # Turn off static source if we're in developer mode.
    static_source        => ($RT::DevelMode ? '0' : '1'), 
    use_object_files     => ($RT::DevelMode ? '0' : '1'), 
    autoflush            => 0
) };

# {{{ sub new 

=head2 new

  Constructs a web handler of the appropriate class.
  Takes options to pass to the constructor.

=cut

sub new {
    my $class = shift;
    $class->InitSessionDir;

    if ( $mod_perl::VERSION && $mod_perl::VERSION >= 1.9908 ) {
        goto &NewApacheHandler;
    }
    elsif ($CGI::MOD_PERL) {
        goto &NewApacheHandler;
    }
    else {
        goto &NewCGIHandler;
    }
}

sub InitSessionDir {
    # Activate the following if running httpd as root (the normal case).
    # Resets ownership of all files created by Mason at startup.
    # Note that mysql uses DB for sessions, so there's no need to do this.
    unless ( $RT::DatabaseType =~ /(?:mysql|Pg)/ ) {

        # Clean up our umask to protect session files
        umask(0077);

        if ($CGI::MOD_PERL) { local $@; eval {

            chown( Apache->server->uid, Apache->server->gid,
                $RT::MasonSessionDir )
        }} 

        # Die if WebSessionDir doesn't exist or we can't write to it
        stat($RT::MasonSessionDir);
        die "Can't read and write $RT::MasonSessionDir"
        unless ( ( -d _ ) and ( -r _ ) and ( -w _ ) );
    }

}

# }}}

# {{{ sub NewApacheHandler 

=head2 NewApacheHandler

  Takes extra options to pass to HTML::Mason::ApacheHandler->new
  Returns a new Mason::ApacheHandler object

=cut

sub NewApacheHandler {
    require HTML::Mason::ApacheHandler;
    return NewHandler('HTML::Mason::ApacheHandler', args_method => "CGI", @_);
}

# }}}

# {{{ sub NewApache2Handler 

=head2 NewApache2Handler

  Takes extra options to pass to MasonX::Apache2Handler->new
  Returns a new MasonX::Apache2Handler object

=cut

sub NewApache2Handler {
    require MasonX::Apache2Handler;
    return NewHandler('MasonX::Apache2Handler', args_method => "CGI", @_);
}

# }}}

# {{{ sub NewCGIHandler 

=head2 NewCGIHandler

  Returns a new Mason::CGIHandler object

=cut

sub NewCGIHandler {
    require HTML::Mason::CGIHandler;
    return NewHandler('HTML::Mason::CGIHandler', @_);
}

sub NewHandler {
    my $class = shift;
    my $handler = $class->new(
        DefaultHandlerArgs(),
        @_
    );
  
    $handler->interp->set_escape( h => \&RT::Interface::Web::EscapeUTF8 );
    $handler->interp->set_escape( u => \&RT::Interface::Web::EscapeURI  );
    return($handler);
}

=head2 CleanupRequest

Rollback any uncommitted transaction.
Flush the ACL cache
Flush the searchbuilder query cache

=cut

sub CleanupRequest {

    if ( $RT::Handle->TransactionDepth ) {
        $RT::Handle->ForceRollback;
        $RT::Logger->crit(
            "Transaction not committed. Usually indicates a software fault."
            . "Data loss may have occurred" );
    }

    # Clean out the ACL cache. the performance impact should be marginal.
    # Consistency is imprived, too.
    RT::Principal->InvalidateACLCache();
    DBIx::SearchBuilder::Record::Cachable->FlushCache
      if ( $RT::WebFlushDbCacheEveryRequest
        and UNIVERSAL::can(
            'DBIx::SearchBuilder::Record::Cachable' => 'FlushCache' ) );

}
# }}}

1;
