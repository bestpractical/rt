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

package RT::Interface::Web::Handler;
use warnings;
use strict;

use CGI qw/-private_tempfiles/;
use MIME::Entity;
use Text::Wrapper;
use CGI::Cookie;
use Time::HiRes;
use HTML::Scrubber;
use RT::Interface::Web;
use RT::Interface::Web::Request;
use File::Path qw( rmtree );
use File::Glob qw( bsd_glob );
use File::Spec::Unix;
use HTTP::Message::PSGI;
use HTTP::Request;
use HTTP::Response;

sub DefaultHandlerArgs  { (
    comp_root            => [
        RT::Interface::Web->ComponentRoots( Names => 1 ),
    ],
    default_escape_flags => 'h',
    data_dir             => "$RT::MasonDataDir",
    allow_globals        => [qw(%session $DECODED_ARGS)],
    # Turn off static source if we're in developer mode.
    static_source        => (RT->Config->Get('DevelMode') ? '0' : '1'), 
    use_object_files     => (RT->Config->Get('DevelMode') ? '0' : '1'), 
    autoflush            => 0,
    error_format         => (RT->Config->Get('DevelMode') ? 'html': 'rt_error'),
    request_class        => 'RT::Interface::Web::Request',
    named_component_subs => $INC{'Devel/Cover.pm'} ? 1 : 0,
) };

sub InitSessionDir {
    # Activate the following if running httpd as root (the normal case).
    # Resets ownership of all files created by Mason at startup.
    # Note that mysql uses DB for sessions, so there's no need to do this.
    unless ( RT->Config->Get('DatabaseType') =~ /(?:mysql|Pg)/ ) {

        # Clean up our umask to protect session files
        umask(0077);

        if ($CGI::MOD_PERL and $CGI::MOD_PERL < 1.9908 ) {

            chown( Apache->server->uid, Apache->server->gid,
                $RT::MasonSessionDir )
            if Apache->server->can('uid');
        }

        # Die if WebSessionDir doesn't exist or we can't write to it
        stat($RT::MasonSessionDir);
        die "Can't read and write $RT::MasonSessionDir"
        unless ( ( -d _ ) and ( -r _ ) and ( -w _ ) );
    }

}


sub NewHandler {
    my $class = shift;
    $class->require or die $!;
    my $handler = $class->new(
        DefaultHandlerArgs(),
        RT->Config->Get('MasonParameters'),
        @_
    );
  
    $handler->interp->set_escape( h => \&RT::Interface::Web::EscapeHTML );
    $handler->interp->set_escape( u => \&RT::Interface::Web::EscapeURI  );
    $handler->interp->set_escape( j => \&RT::Interface::Web::EscapeJS   );
    return($handler);
}

=head2 _mason_dir_index

=cut

sub _mason_dir_index {
    my ($self, $interp, $path) = @_;
    $path =~ s!/$!!;
    if (   !$interp->comp_exists( $path )
         && $interp->comp_exists( $path . "/index.html" ) )
    {
        return $path . "/index.html";
    }

    return $path;
}


=head2 CleanupRequest

Clean ups globals, caches and other things that could be still
there from previous requests:

=over 4

=item Rollback any uncommitted transaction(s)

=item Flush the ACL cache

=item Flush records cache of the L<DBIx::SearchBuilder> if
WebFlushDbCacheEveryRequest option is enabled, what is true by default
and is not recommended to change.

=item Clean up state of RT::Action::SendEmail using 'CleanSlate' method

=item Flush tmp crypt key preferences

=back

=cut

sub CleanupRequest {

    if ( $RT::Handle && $RT::Handle->TransactionDepth ) {
        $RT::Handle->ForceRollback;
        $RT::Logger->crit(
            "Transaction not committed. Usually indicates a software fault."
            . "Data loss may have occurred" );
    }

    # Clean out the ACL cache. the performance impact should be marginal.
    # Consistency is imprived, too.
    RT::Principal->InvalidateACLCache();
    DBIx::SearchBuilder::Record::Cachable->FlushCache
      if ( RT->Config->Get('WebFlushDbCacheEveryRequest')
        and UNIVERSAL::can(
            'DBIx::SearchBuilder::Record::Cachable' => 'FlushCache' ) );

    # cleanup global squelching of the mails
    require RT::Action::SendEmail;
    RT::Action::SendEmail->CleanSlate;
    
    if (RT->Config->Get('Crypt')->{'Enable'}) {
        RT::Crypt->UseKeyForEncryption();
        RT::Crypt->UseKeyForSigning( undef );
    }

    %RT::Ticket::MERGE_CACHE = ( effective => {}, merged => {} );

    # RT::System persists between requests, so its attributes cache has to be
    # cleared manually. Without this, for example, subject tags across multiple
    # processes will remain cached incorrectly
    delete $RT::System->{attributes};

    # Explicitly remove any tmpfiles that GPG opened, and close their
    # filehandles.  unless we are doing inline psgi testing, which kills all the tmp file created by tests.
    File::Temp::cleanup()
            unless $INC{'Test/WWW/Mechanize/PSGI.pm'};

    RT::ObjectCustomFieldValues::ClearOCFVCache();
}


sub HTML::Mason::Exception::as_rt_error {
    my ($self) = @_;
    $RT::Logger->error( $self->as_text );
    return "An internal RT error has occurred.  Your administrator can find more details in RT's log files.";
}

=head1 CheckModPerlHandler

Make sure we're not running with SetHandler perl-script.

=cut

sub CheckModPerlHandler{
    my $self = shift;
    my $env = shift;

    # Plack::Handler::Apache2 masks MOD_PERL, so use MOD_PERL_API_VERSION
    return unless( $env->{'MOD_PERL_API_VERSION'}
                   and $env->{'MOD_PERL_API_VERSION'} == 2);

    my $handler = $env->{'psgi.input'}->handler;

    return unless defined $handler && $handler eq 'perl-script';

    $RT::Logger->critical(<<MODPERL);
RT has problems when SetHandler is set to perl-script.
Change SetHandler in your in httpd.conf to:

    SetHandler modperl

For a complete example mod_perl configuration, see:

https://bestpractical.com/rt/docs/@{[$RT::VERSION =~ /^(\d\.\d)/]}/web_deployment.html#mod_perl-2.xx
MODPERL

    my $res = Plack::Response->new(500);
    $res->content_type("text/plain");
    $res->body("Server misconfiguration; see error log for details");
    return $res;
}

# PSGI App

use RT::Interface::Web::Handler;
use CGI::Emulate::PSGI;
use Plack::Builder;
use Plack::Request;
use Plack::Response;
use Plack::Util;

sub PSGIApp {
    my $self = shift;

    # XXX: this is fucked
    require HTML::Mason::CGIHandler;
    require HTML::Mason::PSGIHandler::Streamy;
    my $h = RT::Interface::Web::Handler::NewHandler('HTML::Mason::PSGIHandler::Streamy');

    $self->InitSessionDir;

    my $mason = sub {
        my $env = shift;

        # mod_fastcgi starts with an empty %ENV, but provides it on each
        # request.  Pick it up and cache it during the first request.
        $ENV{PATH} //= $env->{PATH};

        # HTML::Mason::Utils::cgi_request_args uses $ENV{QUERY_STRING} to
        # determine if to call url_param or not
        # (see comments in HTML::Mason::Utils::cgi_request_args)
        $ENV{QUERY_STRING} = $env->{QUERY_STRING};

        {
            my $res = $self->CheckModPerlHandler($env);
            return $self->_psgi_response_cb( $res->finalize ) if $res;
        }

        unless (RT->InstallMode) {
            unless (eval { RT::ConnectToDatabase() }) {
                my $res = Plack::Response->new(503);
                $res->content_type("text/plain");
                $res->body("Database inaccessible; contact the RT administrator (".RT->Config->Get("OwnerEmail").")");
                return $self->_psgi_response_cb( $res->finalize, sub { $self->CleanupRequest } );
            }
        }

        my $req = Plack::Request->new($env);

        # CGI.pm normalizes .. out of paths so when you requested
        # /NoAuth/../Ticket/Display.html we saw Ticket/Display.html
        # PSGI doesn't normalize .. so we have to deal ourselves.
        if ( $req->path_info =~ m{(^|/)\.\.?(/|$)} ) {
            $RT::Logger->crit("Invalid request for ".$req->path_info." aborting");
            my $res = Plack::Response->new(400);
            return $self->_psgi_response_cb($res->finalize,sub { $self->CleanupRequest });
        }
        $env->{PATH_INFO} = $self->_mason_dir_index( $h->interp, $req->path_info);

        return $self->_psgi_response_cb($h->handle_psgi($env), sub { $self->CleanupRequest() });
    };

    my $app = $self->StaticWrap($mason);
    for my $plugin (RT->Config->Get("Plugins")) {
        my $wrap = $plugin->can("PSGIWrap")
            or next;
        $app = $wrap->($plugin, $app);
    }
    return $app;
}

sub StaticWrap {
    my $self    = shift;
    my $app     = shift;
    my $builder = Plack::Builder->new;

    my $headers = RT::Interface::Web::GetStaticHeaders(Time => 'forever');

    for my $static ( RT->Config->Get('StaticRoots') ) {
        if ( ref $static && ref $static eq 'HASH' ) {
            $builder->add_middleware(
                '+RT::Interface::Web::Middleware::StaticHeaders',
                path => $static->{'path'},
                headers => $headers,
            );
            $builder->add_middleware(
                'Plack::Middleware::Static',
                pass_through => 1,
                %$static
            );
        }
        else {
            $RT::Logger->error(
                "Invalid config StaticRoots: item can only be a hashref" );
        }
    }

    my $path = sub { s!^/static/!! };
    $builder->add_middleware(
        '+RT::Interface::Web::Middleware::StaticHeaders',
        path => $path,
        headers => $headers,
    );
    for my $root (RT::Interface::Web->StaticRoots) {
        $builder->add_middleware(
            'Plack::Middleware::Static',
            path         => $path,
            root         => $root,
            pass_through => 1,
        );
    }
    return $builder->to_app($app);
}

sub _psgi_response_cb {
    my $self = shift;
    my ($ret, $cleanup) = @_;
    Plack::Util::response_cb
            ($ret,
             sub {
                 my $res = shift;

                 if ( RT->Config->Get('Framebusting') ) {
                     # XXX TODO: Do we want to make the value of this header configurable?
                     Plack::Util::header_set($res->[1], 'X-Frame-Options' => 'DENY');
                 }

                 return sub {
                     if (!defined $_[0]) {
                         $cleanup->();
                         return '';
                     }
                     # XXX: Ideally, responses should flag if they need
                     # to be encoded, rather than relying on the UTF-8
                     # flag
                     return Encode::encode("UTF-8",$_[0]) if utf8::is_utf8($_[0]);
                     return $_[0];
                 };
             });
}

sub GetStatic {
    my $class  = shift;
    my $path   = shift;
    my $static = $class->StaticWrap(
        # Anything the static wrap doesn't handle gets 404'd.
        sub { [404, [], []] }
    );
    my $response = HTTP::Response->from_psgi(
        $static->( HTTP::Request->new(GET => $path)->to_psgi )
    );
    return $response;
}

1;
