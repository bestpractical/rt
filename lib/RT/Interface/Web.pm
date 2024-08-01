# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2024 Best Practical Solutions, LLC
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

## Portions Copyright 2000 Tobias Brox <tobix@fsck.com>

## This is a library of static subs to be used by the Mason web
## interface to RT

=head1 NAME

RT::Interface::Web


=cut

use strict;
use warnings;
use 5.010;

package RT::Interface::Web;

use RT::SavedSearches;
use RT::CustomRoles;
use URI qw();
use URI::QueryParam;
use RT::Interface::Web::Menu;
use RT::Interface::Web::Session;
use RT::Interface::Web::Scrubber;
use RT::Interface::Web::Scrubber::Permissive;
use RT::Util ();
use Digest::MD5 ();
use List::MoreUtils qw();
use JSON qw();
use Plack::Util;
use HTTP::Status qw();
use Regexp::Common;
use RT::Shortener;
use RT::Interface::Web::ReportsRegistry;
use MIME::Base64;
use Digest::SHA 'sha1_hex';

our @SHORTENER_SEARCH_FIELDS
    = qw/Class ObjectType BaseQuery Query Format RowsPerPage Order OrderBy ExtraQueryParams ResultPage/;
our @SHORTENER_CHART_FIELDS = qw/Width Height ChartStyle GroupBy ChartFunction StackedGroupBy ChartOrderBy ChartOrder ChartLimit ChartLimitType/;

=head2 SquishedCSS $style

=cut

my %SQUISHED_CSS;
sub SquishedCSS {
    my $style = shift or die "need name";
    return $SQUISHED_CSS{$style} if $SQUISHED_CSS{$style};
    require RT::Squish::CSS;
    my $css = RT::Squish::CSS->new( Style => $style );
    $SQUISHED_CSS{ $css->Style } = $css;
    return $css;
}

=head2 SquishedJS

=cut

my $SQUISHED_JS;
sub SquishedJS {
    return $SQUISHED_JS if $SQUISHED_JS;

    require RT::Squish::JS;
    my $js = RT::Squish::JS->new();
    $SQUISHED_JS = $js;
    return $js;
}

=head2 JSFiles

=cut

sub JSFiles {
    return qw{
        htmx.min.js
        jquery-3.6.0.min.js
        jquery_noconflict.js
        jquery-ui.min.js
        jquery-ui-timepicker-addon.js
        jquery-ui-patch-datepicker.js
        selectize.min.js
        bootstrap.bundle.min.js
        bootstrap-select.min.js
        bootstrap-combobox.js
        i18n.js
        util.js
        autocomplete.js
        history-folding.js
        cascaded.js
        forms.js
        event-registration.js
        late.js
        mousetrap.min.js
        keyboard-shortcuts.js
        assets.js
        /static/RichText5/ckeditor.min.js
        dropzone.min.js
        quoteselection.js
        rights-inspector.js
        Chart.min.js
        chartjs-plugin-colorschemes.min.js
        jquery.jgrowl.min.js
        clipboard.min.js
        }, RT->Config->Get('JSFiles');
}

=head2 ClearSquished

Removes the cached CSS and JS entries, forcing them to be regenerated
on next use.

=cut

sub ClearSquished {
    undef $SQUISHED_JS;
    %SQUISHED_CSS = ();
}

=head2 EscapeHTML SCALARREF

Does a CSS-busting but minimalist escaping of whatever HTML you're passing in.

=cut

sub EscapeHTML {
    my $ref = shift;
    return unless defined $$ref;

    $$ref =~ s/&/&#38;/g;
    $$ref =~ s/</&lt;/g;
    $$ref =~ s/>/&gt;/g;
    $$ref =~ s/\(/&#40;/g;
    $$ref =~ s/\)/&#41;/g;
    $$ref =~ s/"/&#34;/g;
    $$ref =~ s/'/&#39;/g;
}

=head2 EscapeURI SCALARREF

Escapes URI component according to RFC2396

=cut

sub EscapeURI {
    my $ref = shift;
    return unless defined $$ref;

    use bytes;
    $$ref =~ s/([^a-zA-Z0-9_.!~*'()-])/uc sprintf("%%%02X", ord($1))/eg;
}

=head2 EncodeJSON SCALAR

Encodes the SCALAR to JSON and returns a JSON Unicode (B<not> UTF-8) string.
SCALAR may be a simple value or a reference.

=cut

sub EncodeJSON {
    my $s = JSON::to_json(shift, { allow_nonref => 1, @_ });
    $s =~ s{/}{\\/}g;
    return $s;
}

sub _encode_surrogates {
    my $uni = $_[0] - 0x10000;
    return ($uni /  0x400 + 0xD800, $uni % 0x400 + 0xDC00);
}

sub EscapeJS {
    my $ref = shift;
    return unless defined $$ref;

    $$ref = "'" . join('',
                 map {
                     chr($_) =~ /[a-zA-Z0-9]/ ? chr($_) :
                     $_  <= 255   ? sprintf("\\x%02X", $_) :
                     $_  <= 65535 ? sprintf("\\u%04X", $_) :
                     sprintf("\\u%X\\u%X", _encode_surrogates($_))
                 } unpack('U*', $$ref))
        . "'";
}

=head2 WebCanonicalizeInfo();

Different web servers set different environmental variables. This
function must return something suitable for REMOTE_USER. By default,
just downcase REMOTE_USER env

=cut

sub WebCanonicalizeInfo {
    return RequestENV('REMOTE_USER') ? lc RequestENV('REMOTE_USER') : RequestENV('REMOTE_USER');
}



=head2 WebRemoteUserAutocreateInfo($user);

Returns a hash of user attributes, used when WebRemoteUserAutocreate is set.

=cut

sub WebRemoteUserAutocreateInfo {
    my $user = shift;

    my %user_info;

    # default to making Privileged users, even if they specify
    # some other default Attributes
    if ( !$RT::UserAutocreateDefaultsOnLogin
        || ( ref($RT::UserAutocreateDefaultsOnLogin) && not exists $RT::UserAutocreateDefaultsOnLogin->{Privileged} ) )
    {
        $user_info{'Privileged'} = 1;
    }

    # Populate fields with information from Unix /etc/passwd
    my ( $comments, $realname ) = ( getpwnam($user) )[ 5, 6 ];
    $user_info{'Comments'} = $comments if defined $comments;
    $user_info{'RealName'} = $realname if defined $realname;

    # and return the wad of stuff
    return {%user_info};
}

sub MasonCacheCreatedDate {
    require File::Spec;
    return ( stat File::Spec->catdir( $RT::MasonDataDir, 'obj' ) )[9] // '';
}

sub HandleRequest {
    my $ARGS = shift;

    RT->SetCurrentInterface('Web');
    if (RT->Config->Get('DevelMode')) {
        require Module::Refresh;
        Module::Refresh->refresh;
    }
    else {
        my $mason_cache_created = MasonCacheCreatedDate();
        if ( $HTML::Mason::Commands::m->interp->{rt_mason_cache_created} ne $mason_cache_created ) {
            $HTML::Mason::Commands::m->interp->flush_code_cache;
            $HTML::Mason::Commands::m->clear_callback_cache;
            $HTML::Mason::Commands::m->interp->{rt_mason_cache_created} = $mason_cache_created;
        }
    }

    RT->Config->RefreshConfigFromDatabase();

    $HTML::Mason::Commands::r->content_type("text/html; charset=utf-8");

    $HTML::Mason::Commands::m->{'rt_base_time'} = [ Time::HiRes::gettimeofday() ];

    # Roll back any dangling transactions from a previous failed connection
    $RT::Handle->ForceRollback() if $RT::Handle and $RT::Handle->TransactionDepth;

    MaybeEnableSQLStatementLog();

    # avoid reentrancy, as suggested by masonbook
    local *HTML::Mason::Commands::session unless $HTML::Mason::Commands::m->is_subrequest;

    $HTML::Mason::Commands::m->autoflush( $HTML::Mason::Commands::m->request_comp->attr('AutoFlush') )
        if ( $HTML::Mason::Commands::m->request_comp->attr_exists('AutoFlush') );

    ValidateWebConfig();

    DecodeARGS($ARGS);
    local $HTML::Mason::Commands::DECODED_ARGS = $ARGS;
    PreprocessTimeUpdates($ARGS);

    if ( defined $ARGS->{ResultPage} && length $ARGS->{ResultPage}  ) {
        my $passed;
        my $page = $ARGS->{ResultPage};

        # Strip off web path
        if ( my $web_path = RT->Config->Get('WebPath') ) {
            $page =~ s!^$web_path!!;
        }

        for my $item (@RT::Interface::Web::WHITELISTED_RESULT_PAGES) {
            if ( ref $item eq 'Regexp' ) {
                $passed = 1 if $page =~ $item;
            }
            else {
                $passed = 1 if $page eq $item;
            }
            last if $passed;
        }

        if ( !$passed ) {
            RT->Logger->warning("ResultPage $ARGS->{ResultPage} is not whitelisted, ignoring");
            delete $ARGS->{ResultPage};
        }
    }

    InitializeMenu();
    MaybeShowInstallModePage();

    MaybeRebuildCustomRolesCache();
    RT->System->MaybeRebuildLifecycleCache();

    $HTML::Mason::Commands::m->comp( '/Elements/SetupSessionCookie', %$ARGS );
    SendSessionCookie();

    if ( _UserLoggedIn() ) {
        # make user info up to date
        $HTML::Mason::Commands::session{'CurrentUser'}
          ->Load( $HTML::Mason::Commands::session{'CurrentUser'}->id );
        undef $HTML::Mason::Commands::session{'CurrentUser'}->{'LangHandle'};
    }
    else {
        $HTML::Mason::Commands::session{'CurrentUser'} = RT::CurrentUser->new();
    }

    # Write changes back to persistent session
    RT::Interface::Web::Session::Set(
        Key   => 'CurrentUser',
        Value => $HTML::Mason::Commands::session{'CurrentUser'},
    );

    # attempt external auth
    $HTML::Mason::Commands::m->comp( '/Elements/DoAuth', %$ARGS )
        if @{ RT->Config->Get( 'ExternalAuthPriority' ) || [] };

    # Process session-related callbacks before any auth attempts
    $HTML::Mason::Commands::m->callback( %$ARGS, CallbackName => 'Session', CallbackPage => '/autohandler' );

    MaybeRejectPrivateComponentRequest();

    MaybeShowNoAuthPage($ARGS);

    AttemptExternalAuth($ARGS) if RT->Config->Get('WebRemoteUserContinuous') or not _UserLoggedIn();

    _ForceLogout() unless _UserLoggedIn();

    # attempt external auth
    $HTML::Mason::Commands::m->comp( '/Elements/DoAuth', %$ARGS )
        if @{ RT->Config->Get( 'ExternalAuthPriority' ) || [] };

    AttemptTokenAuthentication($ARGS) unless _UserLoggedIn();

    # Process per-page authentication callbacks
    $HTML::Mason::Commands::m->callback( %$ARGS, CallbackName => 'Auth', CallbackPage => '/autohandler' );

    if ( $ARGS->{'NotMobile'} ) {
        RT::Interface::Web::Session::Set(
            Key   => 'NotMobile',
            Value => 1,
        );
    }

    unless ( _UserLoggedIn() ) {
        _ForceLogout();

        # Authenticate if the user is trying to login via user/pass query args
        my ($authed, $msg) = AttemptPasswordAuthentication($ARGS);

        unless ($authed) {
            my $m = $HTML::Mason::Commands::m;

            # REST urls get a special 401 response
            if ($m->request_comp->path =~ m{^/REST/\d+\.\d+/}) {
                $HTML::Mason::Commands::r->content_type("text/plain; charset=utf-8");
                $m->error_format("text");
                $m->out("RT/$RT::VERSION 401 Credentials required\n");
                $m->out("\n$msg\n") if $msg;
                $m->abort;
            }
            # Specially handle /index.html and /m/index.html so that we get a nicer URL
            elsif ( $m->request_comp->path =~ m{^(/m)?/index\.html$} ) {
                my $mobile = $1 ? 1 : 0;
                my $next   = SetNextPage($ARGS);
                $m->comp('/NoAuth/Login.html',
                    next    => $next,
                    actions => [$msg],
                    mobile  => $mobile);
                $m->abort;
            }
            else {
                TangentForLogin($ARGS, results => ($msg ? LoginError($msg) : undef));
            }
        }
    }

    MaybeShowInterstitialCSRFPage($ARGS);

    # now it applies not only to home page, but any dashboard that can be used as a workspace
    if ( $ARGS->{'HomeRefreshInterval'} ) {
        RT::Interface::Web::Session::Set(
            Key   => 'home_refresh_interval',
            Value => $ARGS->{'HomeRefreshInterval'},
        );
    }

    # Process per-page global callbacks
    $HTML::Mason::Commands::m->callback( %$ARGS, CallbackName => 'Default', CallbackPage => '/autohandler' );

    ShowRequestedPage($ARGS);
    LogRecordedSQLStatements(RequestData => {
        Path => $HTML::Mason::Commands::m->request_path,
    });

    # Process per-page final cleanup callbacks
    $HTML::Mason::Commands::m->callback( %$ARGS, CallbackName => 'Final', CallbackPage => '/autohandler' );

    # Don't show the footer for htmx components
    if ( $HTML::Mason::Commands::m->request_path !~ /^\/Views/ ) {
        $HTML::Mason::Commands::m->comp( '/Elements/Footer', %$ARGS );
    }
}

sub _ForceLogout {

    RT::Interface::Web::Session::Delete(
        Key => 'CurrentUser',
    );
}

sub _UserLoggedIn {
    if ( $HTML::Mason::Commands::session{CurrentUser} && $HTML::Mason::Commands::session{'CurrentUser'}->id ) {
        return 1;
    } else {
        return undef;
    }

}

=head2 LoginError ERROR

Pushes a login error into the Actions session store and returns the hash key.

=cut

sub LoginError {
    my $new = shift;
    my $key = Digest::MD5::md5_hex( rand(1024) );

    my @actions = @{ $HTML::Mason::Commands::session{"Actions"}->{$key} ||= [] };
    push @actions, $new;
    RT::Interface::Web::Session::Set(
        Key   => 'Actions',
        Value => \@actions,
    );

    return $key;
}

=head2 SetNextPage ARGSRef [PATH]

Intuits and stashes the next page in the session hash.  If PATH is
specified, uses that instead of the value of L<IntuitNextPage()>.  Returns
the hash value.

=cut

sub SetNextPage {
    my $ARGS = shift;
    my $next = $_[0] ? $_[0] : IntuitNextPage();
    my $hash = Digest::MD5::md5_hex($next . $$ . rand(1024));
    my $page = { url => $next };

    # If an explicit URL was passed and we didn't IntuitNextPage, then
    # IsPossibleCSRF below is almost certainly unrelated to the actual
    # destination.  Currently explicit next pages aren't used in RT, but the
    # API is available.
    if (not $_[0] and RT->Config->Get("RestrictReferrer")) {
        # This isn't really CSRF, but the CSRF heuristics are useful for catching
        # requests which may have unintended side-effects.
        my ($is_csrf, $msg, @loc) = IsPossibleCSRF($ARGS);
        if ($is_csrf) {
            RT->Logger->notice(
                "Marking original destination as having side-effects before redirecting for login.\n"
               ."Request: $next\n"
               ."Reason: " . HTML::Mason::Commands::loc($msg, @loc)
            );
            $page->{'HasSideEffects'} = [$msg, @loc];
        }
    }

    RT::Interface::Web::Session::Set(
        Key    => 'NextPage',
        SubKey => $hash,
        Value  => $page,
    );

    return $hash;
}

=head2 FetchNextPage HASHKEY

Returns the stashed next page hashref for the given hash.

=cut

sub FetchNextPage {
    my $hash = shift || "";
    RT::Interface::Web::Session::Load(
        Id => $HTML::Mason::Commands::session{'_session_id'},
    );

    return $HTML::Mason::Commands::session{'NextPage'}->{$hash};
}

=head2 RemoveNextPage HASHKEY

Removes the stashed next page for the given hash and returns it.

=cut

sub RemoveNextPage {
    my $hash = shift || "";
    my $return_hash = $HTML::Mason::Commands::session{'NextPage'}->{$hash};
    RT::Interface::Web::Session::Delete(
        Key    => 'NextPage',
        SubKey => $hash,
    );
    return $return_hash;
}

=head2 TangentForLogin ARGSRef [HASH]

Redirects to C</NoAuth/Login.html>, setting the value of L<IntuitNextPage> as
the next page.  Takes a hashref of request %ARGS as the first parameter.
Optionally takes all other parameters as a hash which is dumped into query
params.

=cut

sub TangentForLogin {
    my $login = TangentForLoginURL(@_);
    Redirect( RT->Config->Get('WebBaseURL') . $login );
}

=head2 TangentForLoginURL [HASH]

Returns a URL suitable for tangenting for login.  Optionally takes a hash which
is dumped into query params.

=cut

sub TangentForLoginURL {
    my $ARGS  = shift;
    my $hash  = SetNextPage($ARGS);
    my %query = (@_, next => $hash);

    $query{mobile} = 1
        if $HTML::Mason::Commands::m->request_comp->path =~ m{^/m(/|$)};

    my $login = RT->Config->Get('WebPath') . '/NoAuth/Login.html?';
    $login .= $HTML::Mason::Commands::m->comp('/Elements/QueryString', %query);
    return $login;
}

=head2 TangentForLoginWithError ERROR

Localizes the passed error message, stashes it with L<LoginError> and then
calls L<TangentForLogin> with the appropriate results key.

=cut

sub TangentForLoginWithError {
    my $ARGS = shift;
    my $key  = LoginError(HTML::Mason::Commands::loc(@_));
    TangentForLogin( $ARGS, results => $key );
}

=head2 IntuitNextPage

Attempt to figure out the path to which we should return the user after a
tangent.  The current request URL is used, or failing that, the C<WebURL>
configuration variable.

=cut

sub IntuitNextPage {
    my $req_uri;

    # This includes any query parameters.  Redirect will take care of making
    # it an absolute URL.
    if (RequestENV('REQUEST_URI')) {
        $req_uri = RequestENV('REQUEST_URI');

        # collapse multiple leading slashes so the first part doesn't look like
        # a hostname of a schema-less URI
        $req_uri =~ s{^/+}{/};
    }

    my $next = defined $req_uri ? $req_uri : RT->Config->Get('WebURL');

    # sanitize $next
    my $uri = URI->new($next);

    # You get undef scheme with a relative uri like "/Search/Build.html"
    unless (!defined($uri->scheme) || $uri->scheme eq 'http' || $uri->scheme eq 'https') {
        $next = RT->Config->Get('WebURL');
    }

    # Make sure we're logging in to the same domain
    # You can get an undef authority with a relative uri like "index.html"
    my $uri_base_url = URI->new(RT->Config->Get('WebBaseURL'));
    unless (!defined($uri->authority) || $uri->authority eq $uri_base_url->authority) {
        $next = RT->Config->Get('WebURL');
    }

    return $next;
}

=head2 MaybeShowInstallModePage 

This function, called exclusively by RT's autohandler, dispatches
a request to RT's Installation workflow, only if Install Mode is enabled in the configuration file.

If it serves a page, it stops mason processing. Otherwise, mason just keeps running through the autohandler

=cut 

sub MaybeShowInstallModePage {
    return unless RT->InstallMode;

    my $m = $HTML::Mason::Commands::m;
    if ( $m->base_comp->path =~ RT->Config->Get('WebNoAuthRegex') ) {
        $m->call_next();
    } elsif ( $m->request_comp->path !~ m{^(/+)Install/} ) {
        RT::Interface::Web::Redirect( RT->Config->Get('WebURL') . "Install/index.html" );
    } else {
        $m->call_next();
    }
    $m->abort();
}

=head2 MaybeShowNoAuthPage  \%ARGS

This function, called exclusively by RT's autohandler, dispatches
a request to the page a user requested (but only if it matches the "noauth" regex.

If it serves a page, it stops mason processing. Otherwise, mason just keeps running through the autohandler

=cut 

sub MaybeShowNoAuthPage {
    my $ARGS = shift;

    my $m = $HTML::Mason::Commands::m;

    return unless $m->base_comp->path =~ RT->Config->Get('WebNoAuthRegex');

    # Don't show the login page to logged in users
    Redirect(RT->Config->Get('WebURL'))
        if $m->base_comp->path eq '/NoAuth/Login.html' and _UserLoggedIn();

    # If it's a noauth file, don't ask for auth.
    $m->comp( { base_comp => $m->request_comp }, $m->fetch_next, %$ARGS );
    $m->abort;
}

=head2 MaybeRejectPrivateComponentRequest

This function will reject calls to private components, like those under
C</Elements>. If the requested path is a private component then we will
abort with a C<403> error.

=cut

sub MaybeRejectPrivateComponentRequest {
    my $m = $HTML::Mason::Commands::m;
    my $path = $m->request_comp->path;

    # We do not check for dhandler here, because requesting our dhandlers
    # directly is okay. Mason will invoke the dhandler with a dhandler_arg of
    # 'dhandler'.

    if ($path =~ m{
            / # leading slash
            ( Elements    |
              _elements   | # mobile UI
              Callbacks   |
              Widgets     |
              autohandler | # requesting this directly is suspicious
              l (_unsafe)? ) # loc component
            ( $ | / ) # trailing slash or end of path
        }xi) {
            $m->abort(403);
    }

    return;
}

sub InitializeMenu {
    $HTML::Mason::Commands::m->notes('menu', RT::Interface::Web::Menu->new());
    $HTML::Mason::Commands::m->notes('page-menu', RT::Interface::Web::Menu->new());
    $HTML::Mason::Commands::m->notes('page-widgets', RT::Interface::Web::Menu->new());

}


=head2 ShowRequestedPage  \%ARGS

This function, called exclusively by RT's autohandler, dispatches
a request to the page a user requested (making sure that unprivileged users
can only see self-service pages.

=cut 

sub ShowRequestedPage {
    my $ARGS = shift;

    my $m = $HTML::Mason::Commands::m;

    # Ensure that the cookie that we send is up-to-date, in case the
    # session-id has been modified in any way
    SendSessionCookie();

    ExpandShortenerCode($ARGS);

    # precache all system level rights for the current user
    $HTML::Mason::Commands::session{CurrentUser}->PrincipalObj->HasRights( Object => RT->System );

    if ( $HTML::Mason::Commands::r->path_info =~ m{^(/+)User/Prefs.html} ) {
        RT->Deprecated(
            Message => '/User/Prefs.html is deprecated',
            Instead => "/Prefs/AboutMe.html",
            Stack   => 0,
        );
        RT::Interface::Web::Redirect( RT->Config->Get('WebURL') . 'Prefs/AboutMe.html' );
    }

    # If the user isn't privileged, they can only see SelfService
    unless ( $HTML::Mason::Commands::session{'CurrentUser'}->Privileged ) {

        # if the user is trying to access a ticket, redirect them
        if ( $m->request_comp->path =~ m{^(/+)Ticket/Display.html} && $ARGS->{'id'} ) {
            RT::Interface::Web::Redirect( RT->Config->Get('WebURL') . "SelfService/Display.html?id=" . $ARGS->{'id'} );
        }

        # otherwise, drop the user at the SelfService default page
        elsif ( $m->base_comp->path !~ RT->Config->Get('SelfServiceRegex') ) {
            RT::Interface::Web::Redirect( RT->Config->Get('WebURL') . "SelfService/" );
        }

        # if user is in SelfService dir let him do anything
        else {
            $m->comp( { base_comp => $m->request_comp }, $m->fetch_next, %$ARGS );
        }
    } else {
        $m->comp( { base_comp => $m->request_comp }, $m->fetch_next, %$ARGS );
    }

}

sub AttemptExternalAuth {
    my $ARGS = shift;

    return unless ( RT->Config->Get('WebRemoteUserAuth') );

    my $user = $ARGS->{user};
    my $m    = $HTML::Mason::Commands::m;

    my $logged_in_external_user = _UserLoggedIn() && $HTML::Mason::Commands::session{'WebExternallyAuthed'};

    # If RT is configured for external auth, let's go through and get REMOTE_USER

    # Do we actually have a REMOTE_USER or equivalent?  We only check auth if
    # 1) we have no logged in user, or 2) we have a user who is externally
    # authed.  If we have a logged in user who is internally authed, don't
    # check remote user otherwise we may log them out.
    if (RT::Interface::Web::WebCanonicalizeInfo()
        and (not _UserLoggedIn() or $logged_in_external_user) )
    {
        $user = RT::Interface::Web::WebCanonicalizeInfo();
        my $load_method = RT->Config->Get('WebRemoteUserGecos') ? 'LoadByGecos' : 'Load';

        my $next = RemoveNextPage($ARGS->{'next'});
           $next = $next->{'url'} if ref $next;
        InstantiateNewSession() unless _UserLoggedIn;
        $HTML::Mason::Commands::session{'CurrentUser'} = RT::CurrentUser->new();
        $HTML::Mason::Commands::session{'CurrentUser'}->$load_method($user);

        RT::Interface::Web::Session::Set(
            Key   => 'CurrentUser',
            Value => $HTML::Mason::Commands::session{'CurrentUser'},
        );

        if ( RT->Config->Get('WebRemoteUserAutocreate') and not _UserLoggedIn() ) {

            # Create users on-the-fly
            my $UserObj = RT::User->new(RT->SystemUser);
            my ( $val, $msg ) = $UserObj->Create(
                %{ ref RT->Config->Get('UserAutocreateDefaultsOnLogin') ? RT->Config->Get('UserAutocreateDefaultsOnLogin') : {} },
                Name  => $user,
                Gecos => $user,
            );

            if ($val) {

                # now get user specific information, to better create our user.
                my $new_user_info = RT::Interface::Web::WebRemoteUserAutocreateInfo($user);

                # set the attributes that have been defined.
                foreach my $attribute ( $UserObj->WritableAttributes, qw(Privileged Disabled) ) {
                    $m->callback(
                        Attribute    => $attribute,
                        User         => $user,
                        UserInfo     => $new_user_info,
                        CallbackName => 'NewUser',
                        CallbackPage => '/autohandler'
                    );
                    my $method = "Set$attribute";
                    $UserObj->$method( $new_user_info->{$attribute} ) if defined $new_user_info->{$attribute};
                }
                $HTML::Mason::Commands::session{'CurrentUser'}->Load($user);
                RT::Interface::Web::Session::Set(
                    Key   => 'CurrentUser',
                    Value => $HTML::Mason::Commands::session{'CurrentUser'},
                );
            } else {
                RT->Logger->error("Couldn't auto-create user '$user' when attempting WebRemoteUser: $msg");
                AbortExternalAuth( Error => "UserAutocreateDefaultsOnLogin" );
            }
        }

        if ( _UserLoggedIn() ) {
            RT->Logger->info("Session created from REMOTE_USER for user $user from " . RequestENV('REMOTE_ADDR'));

            RT::Interface::Web::Session::Set(
                Key   => 'WebExternallyAuthed',
                Value => 1,
            );

            $m->callback( %$ARGS, CallbackName => 'ExternalAuthSuccessfulLogin', CallbackPage => '/autohandler' );
            # It is possible that we did a redirect to the login page,
            # if the external auth allows lack of auth through with no
            # REMOTE_USER set, instead of forcing a "permission
            # denied" message.  Honor the $next.
            Redirect($next) if $next;
            # Unlike AttemptPasswordAuthentication below, we do not
            # force a redirect to / if $next is not set -- otherwise,
            # straight-up external auth would always redirect to /
            # when you first hit it.
        } else {
            # Couldn't auth with the REMOTE_USER provided because an RT
            # user doesn't exist and we're configured not to create one.
            RT->Logger->error("Couldn't find internal user for '$user' when attempting WebRemoteUser and RT is not configured for auto-creation. Refer to `perldoc $RT::BasePath/docs/authentication.pod` if you want to allow auto-creation.");
            AbortExternalAuth(
                Error => "NoInternalUser",
                User  => $user,
            );
        }
    }
    elsif ($logged_in_external_user) {
        # The logged in external user was deauthed by the auth system and we
        # should kick them out.
        AbortExternalAuth( Error => "Deauthorized" );
    }
    elsif (not RT->Config->Get('WebFallbackToRTLogin')) {
        # Abort if we don't want to fallback internally
        AbortExternalAuth( Error => "NoRemoteUser" );
    }
}

sub AbortExternalAuth {
    my %args  = @_;
    my $error = $args{Error} ? "/Errors/WebRemoteUser/$args{Error}" : undef;
    my $m     = $HTML::Mason::Commands::m;
    my $r     = $HTML::Mason::Commands::r;

    _ForceLogout();

    # Clear the decks, not that we should have partial content.
    $m->clear_buffer;

    $r->status(403);
    $m->comp($error, %args)
        if $error and $m->comp_exists($error);

    # Return a 403 Forbidden or we may fallback to a login page with no form
    $m->abort(403);
}

sub AttemptPasswordAuthentication {
    my $ARGS = shift;
    return unless defined $ARGS->{user} && defined $ARGS->{pass};

    my $user_obj = RT::CurrentUser->new();
    $user_obj->Load( $ARGS->{user} );

    # Load the RT system user as well to avoid timing side channel
    my $system_user = RT::CurrentUser->new();
    $system_user->Load(1);    # User with ID 1 should always exist!

    my $m = $HTML::Mason::Commands::m;

    my $remote_addr = RequestENV('REMOTE_ADDR');
    unless ( $user_obj->id && $user_obj->IsPassword( $ARGS->{pass} ) ) {
        if (!$user_obj->id) {
            # Avoid timing side channel... always run IsPassword
            $system_user->IsPassword( $ARGS->{pass} );
        }
        $RT::Logger->error("FAILED LOGIN for @{[$ARGS->{user}]} from $remote_addr");
        $m->callback( %$ARGS, CallbackName => 'FailedLogin', CallbackPage => '/autohandler' );
        return (0, HTML::Mason::Commands::loc('Your username or password is incorrect'));
    }
    else {
        $RT::Logger->info("Successful login for @{[$ARGS->{user}]} from $remote_addr");

        # It's important to nab the next page from the session before we blow
        # the session away
        my $next = RemoveNextPage($ARGS->{'next'});
           $next = $next->{'url'} if ref $next;

        InstantiateNewSession();

        RT::Interface::Web::Session::Set(
            Key   => 'CurrentUser',
            Value => $user_obj,
        );

        $m->callback( %$ARGS, CallbackName => 'SuccessfulLogin', CallbackPage => '/autohandler', RedirectTo => \$next );

        # Really the only time we don't want to redirect here is if we were
        # passed user and pass as query params in the URL.
        if ($next) {
            Redirect($next);
        }
        elsif ($ARGS->{'next'}) {
            # Invalid hash, but still wants to go somewhere, take them to /
            Redirect(RT->Config->Get('WebURL'));
        }

        return (1, HTML::Mason::Commands::loc('Logged in'));
    }
}

sub AttemptTokenAuthentication {
    my $ARGS = shift;
    my ($pass, $user) = ('', '');
    if ((RequestENV('HTTP_AUTHORIZATION')||'') =~ /^token (.*)$/i) {
        $pass ||= $1;
        my ($user_obj, $token) = RT::Authen::Token->UserForAuthString($pass, $user);
        if ( $user_obj ) {
            # log in
            my $remote_addr = RequestENV('REMOTE_ADDR');
            $RT::Logger->info("Successful login for @{[$user_obj->Name]} from $remote_addr using authentication token #@{[$token->Id]} (\"@{[$token->Description]}\")");

            # It's important to nab the next page from the session before we blow
            # the session away
            my $next = RT::Interface::Web::RemoveNextPage($ARGS->{'next'});
            $next = $next->{'url'} if ref $next;

            RT::Interface::Web::InstantiateNewSession();
            RT::Interface::Web::Session::Set(
                Key   => 'CurrentUser',
                Value => $user_obj,
            );

            # Really the only time we don't want to redirect here is if we were
            # passed user and pass as query params in the URL.
            if ($next) {
                RT::Interface::Web::Redirect($next);
            }
            elsif ($ARGS->{'next'}) {
                # Invalid hash, but still wants to go somewhere, take them to /
                RT::Interface::Web::Redirect(RT->Config->Get('WebURL'));
            }
        }
    }
}


=head2 LoadSessionFromCookie

Load or setup a session cookie for the current user.

=cut

sub _SessionCookieName {
    my $cookiename = "RT_SID_" . RT->Config->Get('rtname');
    $cookiename .= "." . RequestENV('SERVER_PORT') if RequestENV('SERVER_PORT');
    return $cookiename;
}

sub LoadSessionFromCookie {

    my %cookies       = CGI::Cookie->parse(RequestENV('HTTP_COOKIE'));
    my $cookiename    = _SessionCookieName();
    my $SessionCookie = ( $cookies{$cookiename} ? $cookies{$cookiename}->value : undef );

    RT::Interface::Web::Session::Load(
        Id => $SessionCookie,
    );

    unless ( $SessionCookie && $HTML::Mason::Commands::session{'_session_id'} eq $SessionCookie ) {
        InstantiateNewSession();
    }
    if ( int RT->Config->Get('AutoLogoff') ) {
        my $now = int( time / 60 );
        my $last_update = $HTML::Mason::Commands::session{'_session_last_update'} || 0;

        if ( $last_update && ( $now - $last_update - RT->Config->Get('AutoLogoff') ) > 0 ) {
            InstantiateNewSession();
        }

        # save session on each request when AutoLogoff is turned on
        if ( $now != $last_update ) {
            RT::Interface::Web::Session::Set(
                Key   => '_session_last_update',
                Value => $now,
            );
        }
    }
}

sub InstantiateNewSession {
    # Starting a new session, so clear out any existing one
    RT::Interface::Web::Session::Delete();

    RT::Interface::Web::Session::Load(
        Id => undef,
    );

    SendSessionCookie();
}

sub SendSessionCookie {
    my $cookie = CGI::Cookie->new(
        -name     => _SessionCookieName(),
        -value    => $HTML::Mason::Commands::session{_session_id},
        -path     => RT->Config->Get('WebPath'),
        -samesite => RT->Config->Get('WebSameSiteCookies'),
        -secure   => ( RT->Config->Get('WebSecureCookies') ? 1 : 0 ),
        -httponly => ( RT->Config->Get('WebHttpOnlyCookies') ? 1 : 0 ),
    );

    $HTML::Mason::Commands::r->err_headers_out->{'Set-Cookie'} = $cookie->as_string;
}

=head2 GetWebURLFromRequest

People may use different web URLs instead of C<$WebURL> in config.
Return the web URL current user is using.

=cut

sub GetWebURLFromRequest {

    my $uri = URI->new( RT->Config->Get('WebURL') );

    $uri->scheme(RequestENV('psgi.url_scheme') || 'http');

    # [rt3.fsck.com #12716] Apache recommends use of $SERVER_HOST
    $uri->host( RequestENV('SERVER_HOST') || RequestENV('HTTP_HOST') || RequestENV('SERVER_NAME') );
    $uri->port( RequestENV('SERVER_PORT') );
    return "$uri"; # stringify to be consistent with WebURL in config
}

=head2 Redirect URL

This routine tells the current user's browser to redirect to URL.  
Additionally, it unties the user's currently active session, helping to avoid 
A bug in Apache::Session 1.81 and earlier which clobbers sessions if we try to use 
a cached DBI statement handle twice at the same time.

=cut

sub Redirect {
    my $redir_to = shift;
    my $uri        = URI->new($redir_to);
    my $server_uri = URI->new( RT->Config->Get('WebURL') );

    # Make relative URIs absolute from the server host and scheme
    $uri->scheme($server_uri->scheme) if not defined $uri->scheme;
    if (not defined $uri->host) {
        $uri->host($server_uri->host);
        $uri->port($server_uri->port);
    }

    # If the user is coming in via a non-canonical
    # hostname, don't redirect them to the canonical host,
    # it will just upset them (and invalidate their credentials)
    # don't do this if $RT::CanonicalizeRedirectURLs is true
    if (   !RT->Config->Get('CanonicalizeRedirectURLs')
        && $uri->host eq $server_uri->host
        && $uri->port eq $server_uri->port )
    {
        my $env_uri = URI->new(GetWebURLFromRequest());
        $uri->scheme($env_uri->scheme);
        $uri->host($env_uri->host);
        $uri->port($env_uri->port);
    }

    if ( RequestENV('HTTP_HX_REQUEST') ) {
        # For htmx we need to return 200 and set HX-Location.
        # Without this, the new page can try to load inside of a section of
        # the current page.
        $HTML::Mason::Commands::r->status(200);
        $HTML::Mason::Commands::r->headers_out->{'HX-Location'} = EncodeJSON(
            {
                path   => "$uri",
                select => '.main-container',
                swap   => 'outerHTML show:top',
                target => '.main-container',
            }
        );
    }
    else {
        # not sure why, but on some systems without this call mason doesn't
        # set status to 302, but 200 instead and people see blank pages
        $HTML::Mason::Commands::r->status(302);

        # Perlbal expects a status message, but Mason's default redirect status
        # doesn't provide one. See also rt.cpan.org #36689.
        $HTML::Mason::Commands::m->redirect( $uri->canonical, "302 Found" );
    }

    $HTML::Mason::Commands::m->abort;
}

=head2 GetStaticHeaders

return an arrayref of Headers (currently, Cache-Control and Expires).

=cut

sub GetStaticHeaders {
    my %args = @_;

    my $Visibility = 'private';
    if ( ! defined $args{Time} ) {
        $args{Time} = 0;
    } elsif ( $args{Time} eq 'no-cache' ) {
        $args{Time} = 0;
    } elsif ( $args{Time} eq 'forever' ) {
        $args{Time} = 30 * 24 * 60 * 60;
        $Visibility = 'public';
    }

    my $CacheControl = $args{Time}
        ? sprintf "max-age=%d, %s", $args{Time}, $Visibility
        : 'no-cache'
    ;

    my $expires = RT::Date->new(RT->SystemUser);
    $expires->SetToNow;
    $expires->AddSeconds( $args{Time} ) if $args{Time};

    return [
        Expires => $expires->RFC2616,
        'Cache-Control' => $CacheControl,
    ];
}

=head2 CacheControlExpiresHeaders

set both Cache-Control and Expires http headers

=cut

sub CacheControlExpiresHeaders {
    Plack::Util::header_iter( GetStaticHeaders(@_), sub {
        my ( $key, $val ) = @_;
        $HTML::Mason::Commands::r->headers_out->{$key} = $val;
    } );
}

=head2 StaticFileHeaders 

Send the browser a few headers to try to get it to (somewhat aggressively)
cache RT's static JavaScript and CSS files.

This routine could really use _accurate_ heuristics. (XXX TODO)

=cut

sub StaticFileHeaders {
    # remove any cookie headers -- if it is cached publicly, it
    # shouldn't include anyone's cookie!
    delete $HTML::Mason::Commands::r->err_headers_out->{'Set-Cookie'};

    # Expire things in a month.
    CacheControlExpiresHeaders( Time => 'forever' );
}

=head2 ComponentPathIsSafe PATH

Takes C<PATH> and returns a boolean indicating that the user-specified partial
component path is safe.

Currently "safe" means that the path does not start with a dot (C<.>), does
not contain a slash-dot C</.>, and does not contain any nulls.

=cut

sub ComponentPathIsSafe {
    my $self = shift;
    my $path = shift;
    return($path !~ m{(?:^|/)\.} and $path !~ m{\0});
}

=head2 PathIsSafe

Takes a C<< Path => path >> and returns a boolean indicating that
the path is safely within RT's control or not. The path I<must> be
relative.

This function does not consult the filesystem at all; it is merely
a logical sanity checking of the path. This explicitly does not handle
symlinks; if you have symlinks in RT's webroot pointing outside of it,
then we assume you know what you are doing.

=cut

sub PathIsSafe {
    my $self = shift;
    my %args = @_;
    my $path = $args{Path};

    # Get File::Spec to clean up extra /s, ./, etc
    my $cleaned_up = File::Spec->canonpath($path);

    if (!defined($cleaned_up)) {
        $RT::Logger->info("Rejecting path that canonpath doesn't understand: $path");
        return 0;
    }

    # Forbid too many ..s. We can't just sum then check because
    # "../foo/bar/baz" should be illegal even though it has more
    # downdirs than updirs. So as soon as we get a negative score
    # (which means "breaking out" of the top level) we reject the path.

    my @components = split '/', $cleaned_up;
    my $score = 0;
    for my $component (@components) {
        if ($component eq '..') {
            $score--;
            if ($score < 0) {
                $RT::Logger->info("Rejecting unsafe path: $path");
                return 0;
            }
        }
        elsif ($component eq '.' || $component eq '') {
            # these two have no effect on $score
        }
        else {
            $score++;
        }
    }

    return 1;
}

=head2 SendStaticFile 

Takes a File => path and a Type => Content-type

If Type isn't provided and File is an image, it will
figure out a sane Content-type, otherwise it will
send application/octet-stream

Will set caching headers using StaticFileHeaders

=cut

sub SendStaticFile {
    my $self = shift;
    my %args = @_;
    my $file = $args{File};
    my $type = $args{Type};
    my $relfile = $args{RelativeFile};

    if (defined($relfile) && !$self->PathIsSafe(Path => $relfile)) {
        $HTML::Mason::Commands::r->status(400);
        $HTML::Mason::Commands::m->abort;
    }

    $self->StaticFileHeaders();

    unless ($type) {
        if ( $file =~ /\.(gif|png|jpe?g)$/i ) {
            $type = "image/$1";
            $type =~ s/jpg/jpeg/gi;
        }
        $type ||= "application/octet-stream";
    }
    $HTML::Mason::Commands::r->content_type($type);
    open( my $fh, '<', $file ) or die "couldn't open file: $!";
    binmode($fh);
    {
        local $/ = \16384;
        $HTML::Mason::Commands::m->out($_) while (<$fh>);
        $HTML::Mason::Commands::m->flush_buffer;
    }
    close $fh;
}



sub MobileClient {
    my $self = shift;

    return undef unless RT->Config->Get('ShowMobileSite');

if ((RequestENV('HTTP_USER_AGENT') || '') =~ /(?:hiptop|Blazer|Novarra|Vagabond|SonyEricsson|Symbian|NetFront|UP.Browser|UP.Link|Windows CE|MIDP|J2ME|DoCoMo|J-PHONE|PalmOS|PalmSource|iPhone|iPod|AvantGo|Nokia|Android|WebOS|S60|Mobile)/io && !$HTML::Mason::Commands::session{'NotMobile'})  {
    return 1;
} else {
    return undef;
}

}

=head2 ModernClient

This method identifies popular Perl http clients including L<LWP::UserAgent>
and L<WWW::Mechanize> for cases where we need to separate them from
other ordinary browsers that have JavaScript support.

Returns false if the user agent is empty or a L<LWP::UserAgent>/L<WWW::Mechanize>
client is detected, true otherwise.

This is mainly for classic RT tests that do not support lazy load.

This method does not identify end-user browsers based on feature support.
For example, it does not try to identify IE.

=cut

sub ModernClient {
    my $agent = RequestENV('HTTP_USER_AGENT') or return 0;
    return $agent =~ /libwww-perl|WWW-Mechanize/ ? 0 : 1;
}

sub StripContent {
    my %args    = @_;
    my $content = $args{Content};
    return '' unless $content;

    # Make the content have no 'weird' newlines in it
    $content =~ s/\r+\n/\n/g;

    my $return_content = $content;

    my $html = $args{ContentType} && $args{ContentType} eq "text/html";
    my $sigonly = $args{StripSignature};

    # massage content to easily detect if there's any real content
    $content =~ s/\s+//g; # yes! remove all the spaces
    if ( $html ) {
        # Remove the blank line added for signatures
        $content =~ s!<p>&nbsp;</p>!!g;
        # remove html version of spaces and newlines
        $content =~ s!&nbsp;!!g;
        $content =~ s!<br/?>!!g;
    }

    # Filter empty content when type is text/html
    return '' if $html && $content !~ /\S/;

    # If we aren't supposed to strip the sig, just bail now.
    return $return_content unless $sigonly;

    # Find the signature
    my $sig = $args{'CurrentUser'}->UserObj->Signature || '';
    $sig =~ s/\s+//g;

    # Check for plaintext sig
    return '' if not $html and $content =~ /^(--)?\Q$sig\E$/;

    # Check for html-formatted sig; we don't use EscapeHTML here
    # because we want to precisely match the escapting that FCKEditor
    # uses.

    if ($sig =~ /<.{1,5}>/) {
        # HTML sig
        $sig =~ s!&nbsp;!!g;
        $sig =~ s!<br/?>!!g;
        return ''
            if $html
            and $content =~ m{^(?:<p>)?(--)(?:<\/p>)?\Q$sig\E(?:</p>)?$};
    } else {
        # Backwards compatibility for old plaintext sigs in html content
        $sig =~ s/&/&amp;/g;
        $sig =~ s/</&lt;/g;
        $sig =~ s/>/&gt;/g;
        $sig =~ s/"/&quot;/g;
        $sig =~ s/'/&#39;/g;
        return '' if $html and $content =~ m{^(?:<p>)?(--)?\Q$sig\E(?:</p>)?$};
    }

    # Pass it through
    return $return_content;
}

sub DecodeARGS {
    my $ARGS = shift;

    # Later in the code we use
    # $m->comp( { base_comp => $m->request_comp }, $m->fetch_next, %ARGS );
    # instead of $m->call_next to avoid problems with UTF8 keys in
    # arguments.  Specifically, the call_next method pass through
    # original arguments, which are still the encoded bytes, not
    # characters.  "{ base_comp => $m->request_comp }" is copied from
    # mason's source to get the same results as we get from call_next
    # method; this feature is not documented.
    %{$ARGS} = map {

        # if they've passed multiple values, they'll be an array. if they've
        # passed just one, a scalar whatever they are, mark them as utf8
        my $type = ref($_);
        ( !$type )
            ? Encode::decode( 'UTF-8', $_, Encode::FB_PERLQQ )
            : ( $type eq 'ARRAY' )
            ? [ map { ref($_) ? $_ : Encode::decode( 'UTF-8', $_, Encode::FB_PERLQQ ) } @$_ ]
            : ( $type eq 'HASH' )
            ? { map { ref($_) ? $_ : Encode::decode( 'UTF-8', $_, Encode::FB_PERLQQ ) } %$_ }
            : $_
    } %$ARGS;
}

sub PreprocessTimeUpdates {
    my $ARGS = shift;

    my @msg;

    # This code validates and canonicalizes time inputs(including hours into minutes)
    foreach my $field ( keys %$ARGS ) {
        next unless $field =~ /^(.*)-TimeUnits$/i && $ARGS->{$1};
        my $local = $1;
        $ARGS->{$local} =~ s{\b (?: (\d+) \s+ )? (\d+)/(\d+) \b}
                      {($1 || 0) + $3 ? $2 / $3 : 0}xe;

        $ARGS->{$local} =~ s!^\s+!!;
        $ARGS->{$local} =~ s!\s+$!!;
        $ARGS->{$local} =~ s!,!!g;

        if ( $ARGS->{$local} && $ARGS->{$local} !~ /^$RE{num}{real}$/ ) {
            push @msg, HTML::Mason::Commands::loc( 'Invalid [_1]: it should be a number', HTML::Mason::Commands::loc( $local ) );
            next;
        }
        if ( $ARGS->{$field} && $ARGS->{$field} =~ /hours/i ) {
            $ARGS->{$local} *= 60;
        }

        # keep decimal part as the column in db is int
        $ARGS->{$local} = sprintf( '%.0f', $ARGS->{$local} );

        delete $ARGS->{$field};
    }

    return 1 unless @msg;
    return wantarray ? ( 0, @msg ) : 0;
}

sub MaybeEnableSQLStatementLog {

    my $log_sql_statements = RT->Config->Get('StatementLog');

    if ($log_sql_statements) {
        $RT::Handle->ClearSQLStatementLog;
        $RT::Handle->LogSQLStatements(1);
    }

}

my $role_cache_time = time;
sub MaybeRebuildCustomRolesCache {
    my $needs_update = RT->System->CustomRoleCacheNeedsUpdate;
    if ($needs_update > $role_cache_time) {
        RT::CustomRoles->RegisterRoles;
        $role_cache_time = $needs_update;
    }
}

sub LogRecordedSQLStatements {
    my %args = @_;

    my $log_sql_statements = RT->Config->Get('StatementLog');

    return unless ($log_sql_statements);

    my @log = $RT::Handle->SQLStatementLog;
    $RT::Handle->ClearSQLStatementLog;

    $RT::Handle->AddRequestToHistory({
        %{ $args{RequestData} },
        Queries => \@log,
    }) if $args{RequestData};

    my $current_user = $args{CurrentUser} || $HTML::Mason::Commands::session{'CurrentUser'};
    my $current_user_name = $current_user ? $current_user->Name : '';
    for my $stmt (@log) {
        my ( $time, $sql, $bind, $duration ) = @{$stmt};
        my @bind;
        if ( ref $bind ) {
            @bind = @{$bind};
        } else {

            # Older DBIx-SB
            $duration = $bind;
        }
        $RT::Logger->log(
            level   => $log_sql_statements,
            message => $current_user_name
                . " - "
                . "SQL("
                . sprintf( "%.6f", $duration )
                . "s): $sql;"
                . ( @bind ? "  [ bound values: @{[map{ defined $_ ? qq|'$_'| : 'undef'} @bind]} ]" : "" )
        );
    }

}

my $_has_validated_web_config = 0;
sub ValidateWebConfig {
    my $self = shift;

    # do this once per server instance, not once per request
    return if $_has_validated_web_config;
    $_has_validated_web_config = 1;

    my $port = RequestENV('SERVER_PORT');
    my $host = RequestENV('HTTP_X_FORWARDED_HOST') || RequestENV('HTTP_X_FORWARDED_SERVER')
            || RequestENV('HTTP_HOST')             || RequestENV('SERVER_NAME');
    ($host, $port) = ($1, $2) if $host =~ /^(.*?):(\d+)$/;

    if ( $port != RT->Config->Get('WebPort') and not RequestENV('rt.explicit_port')) {
        $RT::Logger->warn("The requested port ($port) does NOT match the configured WebPort ($RT::WebPort).  "
                         ."Perhaps you should Set(\$WebPort, $port); in RT_SiteConfig.pm, "
                         ."otherwise your internal hyperlinks may be broken.");
    }

    if ( $host ne RT->Config->Get('WebDomain') ) {
        $RT::Logger->warn("The requested host ($host) does NOT match the configured WebDomain ($RT::WebDomain).  "
                         ."Perhaps you should Set(\$WebDomain, '$host'); in RT_SiteConfig.pm, "
                         ."otherwise your internal hyperlinks may be broken.");
    }

    # Unfortunately, there is no reliable way to get the _path_ that was
    # requested at the proxy level; simply disable this warning if we're
    # proxied and there's a mismatch.
    my $proxied = RequestENV('HTTP_X_FORWARDED_HOST') || RequestENV('HTTP_X_FORWARDED_SERVER');
    if (RequestENV('SCRIPT_NAME') ne RT->Config->Get('WebPath') and not $proxied) {
        $RT::Logger->warn("The requested path ('" . RequestENV('SCRIPT_NAME') . "') does NOT match the configured WebPath ($RT::WebPath).  "
                         ."Perhaps you should Set(\$WebPath, '" .  RequestENV('SCRIPT_NAME') . "' in RT_SiteConfig.pm, "
                         ."otherwise your internal hyperlinks may be broken.");
    }
}

sub ComponentRoots {
    my $self = shift;
    my %args = ( Names => 0, @_ );
    my @roots;
    if (defined $HTML::Mason::Commands::m) {
        @roots = $HTML::Mason::Commands::m->interp->comp_root_array;
    } else {
        @roots = (
            [ local    => $RT::MasonLocalComponentRoot ],
            (map {[ "plugin-".$_->Name =>  $_->ComponentRoot ]} @{RT->Plugins}),
            [ standard => $RT::MasonComponentRoot ]
        );
    }
    @roots = map { $_->[1] } @roots unless $args{Names};
    return @roots;
}

sub StaticRoots {
    my $self   = shift;
    my @static = (
        $RT::LocalStaticPath,
        (map { $_->StaticDir } @{RT->Plugins}),
        $RT::StaticPath,
    );
    return grep { $_ and -d $_ } @static;
}

our %IS_WHITELISTED_COMPONENT = (
    # The RSS feed embeds an auth token in the path, but query
    # information for the search.  Because it's a straight-up read, in
    # addition to embedding its own auth, it's fine.
    '/NoAuth/rss/dhandler' => 1,

    # While these can be used for denial-of-service against RT
    # (construct a very inefficient query and trick lots of users into
    # running them against RT) it's incredibly useful to be able to link
    # to a search result (or chart) or bookmark a result page.
    '/Search/Results.html' => 1,
    '/Search/Simple.html'  => 1,
    '/m/tickets/search'    => 1,
    '/Search/Chart.html'   => 1,
    '/User/Search.html'    => 1,

    # This page takes Attachment and Transaction argument to figure
    # out what to show, but it's read only and will deny information if you
    # don't have ShowOutgoingEmail.
    '/Ticket/ShowEmailRecord.html' => 1,
);

our @WHITELISTED_RESULT_PAGES = (
    '/Search/Results.html',
);

# Whitelist arguments that do not indicate an effectful request.
our @GLOBAL_WHITELISTED_ARGS = (
    # For example, "id" is acceptable because that is how RT retrieves a
    # record.
    'id',

    # If they have a results= from MaybeRedirectForResults, that's also fine.
    'results',

    # The homepage refresh, which uses the Refresh header, doesn't send
    # a referer in most browsers; whitelist the one parameter it reloads
    # with, HomeRefreshInterval, which is safe
    'HomeRefreshInterval',

    # The NotMobile flag is fine for any page; it's only used to toggle a flag
    # in the session related to which interface you get.
    'NotMobile',

    # The Shortener code
    'sc',
);

our %WHITELISTED_COMPONENT_ARGS = (
    # SavedSearchLoad - This happens when you middle-(or ⌘ )-click "Edit" for a saved search on
    # the homepage. It's not going to do any damage
    # NewQuery - This is simply to clear the search query
    '/Search/Build.html' => ['SavedSearchLoad','NewQuery'],
    # Happens if you try and reply to a message in the ticket history or click a number
    # of options on a tickets Action menu
    '/Ticket/Update.html' => ['QuoteTransaction', 'Action', 'DefaultStatus'],
    # Action->Extract Article on a ticket's menu
    '/Articles/Article/ExtractIntoClass.html' => ['Ticket'],
    # Only affects display
    '/Ticket/Display.html' => ['HideUnsetFields'],

    '/Admin/Tools/RightsInspector.html' => ['Principal', 'Object', 'Right'],
    '/Helpers/RightsInspector/Search' => ['principal', 'object', 'right', 'continueAfter'],
);

# Components which are blacklisted from automatic, argument-based whitelisting.
# These pages are not idempotent when called with just an id.
our %IS_BLACKLISTED_COMPONENT = (
    # Takes only id and toggles bookmark state
    '/Helpers/Toggle/TicketBookmark' => 1,
);

sub IsCompCSRFWhitelisted {
    my $comp = shift;
    my $ARGS = shift;

    return 1 if $IS_WHITELISTED_COMPONENT{$comp};

    my %args = %{ $ARGS };

    # If the user specifies a *correct* user and pass then they are
    # golden.  This acts on the presumption that external forms may
    # hardcode a username and password -- if a malicious attacker knew
    # both already, CSRF is the least of your problems.
    my $AllowLoginCSRF = not RT->Config->Get('RestrictLoginReferrer');
    if ($AllowLoginCSRF and defined($args{user}) and defined($args{pass})) {
        my $user_obj = RT::CurrentUser->new();
        $user_obj->Load($args{user});
        return 1 if $user_obj->id && $user_obj->IsPassword($args{pass});

        delete $args{user};
        delete $args{pass};
    }

    # Some pages aren't idempotent even with safe args like id; blacklist
    # them from the automatic whitelisting below.
    return 0 if $IS_BLACKLISTED_COMPONENT{$comp};

    if ( my %csrf_config = RT->Config->Get('ReferrerComponents') ) {
        if (exists $csrf_config{$comp}) {
            my $value = $csrf_config{$comp};
            if ( ref $value eq 'ARRAY' ) {
                delete $args{$_} for @$value;
                return %args ? 0 : 1;
            }
            else {
                return $value ? 1 : 0;
            }
        }
    }

    return AreCompCSRFParametersWhitelisted($comp, \%args);
}

sub AreCompCSRFParametersWhitelisted {
    my $sub = shift;
    my $ARGS = shift;

    my %leftover_args = %{ $ARGS };

    # Join global whitelist and component-specific whitelist
    my @whitelisted_args = (@GLOBAL_WHITELISTED_ARGS, @{ $WHITELISTED_COMPONENT_ARGS{$sub} || [] });

    for my $arg (@whitelisted_args) {
        delete $leftover_args{$arg};
    }

    # If there are no arguments, then it's likely to be an idempotent
    # request, which are not susceptible to CSRF
    return !%leftover_args;
}

sub IsRefererCSRFWhitelisted {
    my $referer = _NormalizeHost(shift);
    my $base_url = _NormalizeHost(RT->Config->Get('WebBaseURL'));
    $base_url = $base_url->host_port;

    my $configs;
    for my $config ( $base_url, RT->Config->Get('ReferrerWhitelist') ) {
        push @$configs,$config;

        my $host_port = $referer->host_port;
        if ($config =~ /\*/) {
            # Turn a literal * into a domain component or partial component match.
            # Refer to http://tools.ietf.org/html/rfc2818#page-5
            my $regex = join "[a-zA-Z0-9\-]*",
                         map { quotemeta($_) }
                       split /\*/, $config;

            return 1 if $host_port =~ /^$regex$/i;
        } else {
            return 1 if $host_port eq $config;
        }
    }

    return (0,$referer,$configs);
}

=head3 _NormalizeHost

Takes a URI and creates a URI object that's been normalized
to handle common problems such as localhost vs 127.0.0.1

=cut

sub _NormalizeHost {

    my $uri= URI->new(shift);
    $uri->host('127.0.0.1') if $uri->host eq 'localhost';

    return $uri;

}

sub IsPossibleCSRF {
    my $ARGS = shift;

    # If first request on this session is to a REST endpoint, then
    # whitelist the REST endpoints -- and explicitly deny non-REST
    # endpoints.  We do this because using a REST cookie in a browser
    # would open the user to CSRF attacks to the REST endpoints.
    my $path = $HTML::Mason::Commands::r->path_info;

    unless ( defined $HTML::Mason::Commands::session{'REST'} ) {
        RT::Interface::Web::Session::Set(
            Key   => 'REST',
            Value => scalar( $path =~ m{^/+REST/\d+\.\d+(/|$)} ),
        );
    }

    if ($HTML::Mason::Commands::session{'REST'}) {
        return 0 if $path =~ m{^/+REST/\d+\.\d+(/|$)};
        my $why = <<EOT;
This login session belongs to a REST client, and cannot be used to
access non-REST interfaces of RT for security reasons.
EOT
        my $details = <<EOT;
Please log out and back in to obtain a session for normal browsing.  If
you understand the security implications, disabling RT's CSRF protection
will remove this restriction.
EOT
        chomp $details;
        HTML::Mason::Commands::Abort( $why, Details => $details );
    }

    return 0 if IsCompCSRFWhitelisted(
        $HTML::Mason::Commands::m->request_comp->path,
        $ARGS
    );

    # if there is no Referer header then assume the worst
    return (1,
            "your browser did not supply a Referrer header", # loc
        ) if !RequestENV('HTTP_REFERER');

    my ($whitelisted, $browser, $configs) = IsRefererCSRFWhitelisted(RequestENV('HTTP_REFERER'));
    return 0 if $whitelisted;

    if ( @$configs > 1 ) {
        return (1,
                "the Referrer header supplied by your browser ([_1]) is not allowed by RT's configured hostname ([_2]) or whitelisted hosts ([_3])", # loc
                $browser->host_port,
                shift @$configs,
                join(', ', @$configs) );
    }

    return (1,
            "the Referrer header supplied by your browser ([_1]) is not allowed by RT's configured hostname ([_2])", # loc
            $browser->host_port,
            $configs->[0]);
}

sub ExpandCSRFToken {
    my $ARGS = shift;

    my $token = delete $ARGS->{CSRF_Token};
    return unless $token;

    my $data = $HTML::Mason::Commands::session{'CSRF'}{$token};
    return unless $data;
    return unless $data->{path} eq $HTML::Mason::Commands::r->path_info;

    my $user = $HTML::Mason::Commands::session{'CurrentUser'}->UserObj;
    return unless $user->ValidateAuthString( $data->{auth}, $token );

    %{$ARGS} = %{$data->{args}};
    $HTML::Mason::Commands::DECODED_ARGS = $ARGS;

    # We explicitly stored file attachments with the request, but not in
    # the session yet, as that would itself be an attack.  Put them into
    # the session now, so they'll be visible.
    if ($data->{attach}) {
        my $filename = $data->{attach}{filename};
        my $mime     = $data->{attach}{mime};

        RT::Interface::Web::Session::Set(
            Key       => 'Attachments',
            SubKey    => $ARGS->{'Token'}||'',
            SubSubKey => $filename,
            Value     => $mime,
        );
    }

    return 1;
}

sub StoreRequestToken {
    my $ARGS = shift;

    my $token = Digest::MD5::md5_hex(time . {} . $$ . rand(1024));
    my $user = $HTML::Mason::Commands::session{'CurrentUser'}->UserObj;
    my $data = {
        auth => $user->GenerateAuthString( $token ),
        path => $HTML::Mason::Commands::r->path_info,
        args => $ARGS,
    };
    if ($ARGS->{Attach}) {
        my $attachment = HTML::Mason::Commands::MakeMIMEEntity( AttachmentFieldName => 'Attach' );
        my $file_path = delete $ARGS->{'Attach'};

        # This needs to be decoded because the value is a reference;
        # hence it was not decoded along with all of the standard
        # arguments in DecodeARGS
        $data->{attach} = {
            filename => Encode::decode("UTF-8", "$file_path"),
            mime     => $attachment,
        };
    }

    RT::Interface::Web::Session::Set(
        Key    => 'CSRF',
        SubKey => $token,
        Value  => $data,
    );

    return $token;
}

sub MaybeShowInterstitialCSRFPage {
    my $ARGS = shift;

    return unless RT->Config->Get('RestrictReferrer');

    # Deal with the form token provided by the interstitial, which lets
    # browsers which never set referer headers still use RT, if
    # painfully.  This blows values into ARGS
    return if ExpandCSRFToken($ARGS);

    my ($is_csrf, $msg, @loc) = IsPossibleCSRF($ARGS);
    return if !$is_csrf;

    $RT::Logger->notice("Possible CSRF: ".RT::CurrentUser->new->loc($msg, @loc));

    my $token = StoreRequestToken($ARGS);
    $HTML::Mason::Commands::m->comp(
        '/Elements/CSRF',
        OriginalURL => RT->Config->Get('WebBaseURL') . RT->Config->Get('WebPath') . $HTML::Mason::Commands::r->path_info,
        Reason => HTML::Mason::Commands::loc( $msg, @loc ),
        Token => $token,
    );
    # Calls abort, never gets here
}

our @POTENTIAL_PAGE_ACTIONS = (
    qr'/Ticket/Create.html' => "create a ticket",              # loc
    qr'/Ticket/'            => "update a ticket",              # loc
    qr'/Admin/'             => "modify RT's configuration",    # loc
    qr'/Approval/'          => "update an approval",           # loc
    qr'/Articles/'          => "update an article",            # loc
    qr'/Dashboards/'        => "modify a dashboard",           # loc
    qr'/m/ticket/'          => "update a ticket",              # loc
    qr'Prefs'               => "modify your preferences",      # loc
    qr'/Search/'            => "modify or access a search",    # loc
    qr'/SelfService/Create' => "create a ticket",              # loc
    qr'/SelfService/'       => "update a ticket",              # loc
);

sub PotentialPageAction {
    my $page = shift;
    my @potentials = @POTENTIAL_PAGE_ACTIONS;
    while (my ($pattern, $result) = splice @potentials, 0, 2) {
        return HTML::Mason::Commands::loc($result)
            if $page =~ $pattern;
    }
    return "";
}

=head2 RewriteInlineImages PARAMHASH

Turns C<< <img src="cid:..."> >> elements in HTML into working images pointing
back to RT's stored copy.

Takes the following parameters:

=over 4

=item Content

Scalar ref of the HTML content to rewrite.  Modified in place to support the
most common use-case.

=item Attachment

The L<RT::Attachment> object from which the Content originates.

=item Related (optional)

Array ref of related L<RT::Attachment> objects to use for C<Content-ID> matching.

Defaults to the result of the C<Siblings> method on the passed Attachment.

=item AttachmentPath (optional)

The base path to use when rewriting C<src> attributes.

Defaults to C< $WebPath/Ticket/Attachment >

=back

In scalar context, returns the number of elements rewritten.

In list content, returns the attachments IDs referred to by the rewritten <img>
elements, in the order found.  There may be duplicates.

=cut

sub RewriteInlineImages {
    my %args = (
        Content         => undef,
        Attachment      => undef,
        Related         => undef,
        AttachmentPath  => RT->Config->Get('WebPath')."/Ticket/Attachment",
        @_
    );

    return unless defined $args{Content}
              and ref $args{Content} eq 'SCALAR'
              and defined $args{Attachment};

    my $related_part = $args{Attachment}->Closest("multipart/related")
        or return;

    $args{Related} ||= $related_part->Children->ItemsArrayRef;
    return unless @{$args{Related}};

    my $content = $args{'Content'};
    my @rewritten;

    require HTML::RewriteAttributes::Resources;
    $$content = HTML::RewriteAttributes::Resources->rewrite($$content, sub {
        my $cid  = shift;
        my %meta = @_;
        return $cid unless    lc $meta{tag}  eq 'img'
                          and lc $meta{attr} eq 'src'
                          and $cid =~ s/^cid://i;

        for my $attach (@{$args{Related}}) {
            if (($attach->GetHeader('Content-ID') || '') =~ /^(<)?\Q$cid\E(?(1)>)$/) {
                push @rewritten, $attach->Id;
                return "$args{AttachmentPath}/" . $attach->TransactionId . '/' . $attach->Id;
            }
        }

        # No attachments means this is a bogus CID. Just pass it through.
        RT->Logger->debug(qq[Found bogus inline image src="cid:$cid"]);
        return "cid:$cid";
    });
    return @rewritten;
}

=head2 GetCustomFieldInputName(CustomField => $cf_object, Object => $object, Grouping => $grouping_name)

Returns the standard custom field input name; this is complementary to
L</_ParseObjectCustomFieldArgs>.  Takes the following arguments:

=over

=item CustomField => I<L<RT::CustomField> object>

Required.

=item Object => I<object>

The object that the custom field is applied to; optional.  If omitted,
defaults to a new object of the appropriate class for the custom field.

=item Grouping => I<CF grouping>

The grouping that the custom field is being rendered in.  Groupings
allow a custom field to appear in more than one location per form.

=back

=cut

sub GetCustomFieldInputName {
    my %args = (
        CustomField => undef,
        Object      => undef,
        Grouping    => undef,
        @_,
    );

    my $name = GetCustomFieldInputNamePrefix(%args);

    if ( $args{CustomField}->Type eq 'Select' ) {
        if ( $args{CustomField}->RenderType eq 'List' and $args{CustomField}->SingleValue ) {
            $name .= 'Value';
        }
        else {
            $name .= 'Values';
        }
    }
    elsif ( $args{CustomField}->Type =~ /^(?:Binary|Image)$/ ) {
        $name .= 'Upload';
    }
    elsif ( $args{CustomField}->Type =~ /^(?:Date|DateTime|Text|HTML|Wikitext)$/ ) {
        $name .= 'Values';
    }
    else {
        if ( $args{CustomField}->SingleValue ) {
            $name .= 'Value';
        }
        else {
            $name .= 'Values';
        }
    }

    return $name;
}

=head2 GetCustomFieldInputNamePrefix(CustomField => $cf_object, Object => $object, Grouping => $grouping_name)

Returns the standard custom field input name prefix(without "Value" or alike suffix)

=cut

sub GetCustomFieldInputNamePrefix {
    my %args = (
        CustomField => undef,
        Object      => undef,
        Grouping    => undef,
        @_,
    );

    my $prefix = join '-', 'Object', ref( $args{Object} ) || $args{CustomField}->ObjectTypeFromLookupType,
        ( $args{Object} && $args{Object}->id ? $args{Object}->id : '' ),
        'CustomField' . ( $args{Grouping} ? ":$args{Grouping}" : '' ),
        $args{CustomField}->id, '';

    return $prefix;
}

sub RequestENV {
    my $name = shift;

    my $value;
    # For fake requests like dashboard mailer, the cgi_object call might die.
    eval {
        my $env = $HTML::Mason::Commands::m->cgi_object->env;
        $value = $name ? $env->{$name} : $env;
    };

    return $value;
}

sub ClientIsIE {
    # IE 11.0 dropped "MSIE", so we can't use that alone
    return RequestENV('HTTP_USER_AGENT') =~ m{MSIE|Trident/} ? 1 : 0;
}

=head2 ExpandShortenerCode $ARGS

Expand shortener code and put expanded ones into C<$ARGS>.

=cut

sub ExpandShortenerCode {
    my $ARGS = shift;
    if ( my $sc = $ARGS->{sc} ) {
        my $shortener = RT::Shortener->new( $HTML::Mason::Commands::session{CurrentUser} );
        $shortener->LoadByCode($sc);
        if ( $shortener->Id ) {
            my $content = $shortener->DecodedContent;
            $shortener->_SetLastAccessed;

            if ( my $search_id = delete $content->{SavedSearchId} ) {
                my $search = RT::SavedSearch->new( $HTML::Mason::Commands::session{CurrentUser} );
                my ( $ret, $msg ) = $search->LoadById($search_id);
                if ($ret) {
                    my %search_content = %{ $search->{Attribute}->Content || {} };
                    my $type           = delete $search_content{SearchType} || 'Ticket';
                    my $id             = join '-',
                        $search->_build_privacy( $search->{Attribute}->ObjectType, $search->{Attribute}->ObjectId ),
                        'SavedSearch', $search_id;
                    if ( $type eq 'Chart' ) {
                        $content->{SavedChartSearchId} = $id;
                    }
                    elsif ( $type eq 'Graph' ) {
                        $content->{SavedSearchId} = $id;
                        $content->{SearchType} = 'Graph';
                    }
                    else {
                        $content->{SavedSearchId} = $id;
                        $content->{Class}         = "RT::${type}s";
                    }

                    $content->{SearchFields}    = [ keys %search_content ];
                    $content->{SavedSearchLoad} = $content->{SavedSearchId} || $content->{SavedChartSearchId};
                }
                else {
                    RT->Logger->warning("Could not load saved search $sc: $msg");
                    push @{ $HTML::Mason::Commands::session{Actions}{''} },
                        HTML::Mason::Commands::loc( "Could not load saved search [_1]: [_2]", $sc, $msg );
                }
            }

            # Shredder uses different parameters from search pages
            if ( $HTML::Mason::Commands::r->path_info =~ m{^/+Admin/Tools/Shredder} ) {
                if ( $content->{Class} eq 'RT::Tickets' ) {
                    $ARGS->{'Tickets:query'} = $content->{Query}
                        unless exists $ARGS->{'Tickets:query'};
                    $ARGS->{'Tickets:limit'} = $content->{RowsPerPage}
                        unless exists $ARGS->{'Tickets:limit'};
                }
            }
            else {
                for my $key ( keys %$content ) {

                    # Direct passed in arguments have higher priority, so
                    # people can easily create a new search based on an
                    # existing shortener.
                    if ( !exists $ARGS->{$key} ) {
                        $ARGS->{$key} = $content->{$key};
                    }
                }
            }
        }
        else {
            RT->Logger->warning("Could not find short URL code $sc");
            push @{ $HTML::Mason::Commands::session{Actions}{''} },
                HTML::Mason::Commands::loc( "Could not find short URL code [_1]", $sc );
            $HTML::Mason::Commands::session{'i'}++;
        }
    }
}

=head2 ExtractImages Content => $Content, CurrentUser => $CurrentUser

Extract images from $HTML and convert them to src="cid:..."

Currently it supports images embedded in base64 and ones linking to existing
ticket attachments.

Returns the modified HTML and extracted images, each image is a hashref
containing:

    cid: content id
    content_type: image type
    content: image data

=cut

sub ExtractImages {
    my %args = (
        Content     => undef,
        CurrentUser => $HTML::Mason::Commands::session{CurrentUser},
        @_,
    );

    my $content = $args{Content};
    my ( @images, %added );
    require HTML::RewriteAttributes::Resources;
    $content = HTML::RewriteAttributes::Resources->rewrite(
        $content,
        sub {
            my $uri  = shift;
            my %meta = @_;
            return $uri unless lc $meta{tag} eq 'img' && lc $meta{attr} eq 'src';

            my ( $content_type, $content );
            if ( $uri =~ m{^data:(.+);base64,(.+)}s ) {
                $content_type = $1;
                $content      = decode_base64($2);
            }
            elsif ( $uri =~ m{^/(?:SelfService|Ticket)/Attachment/\d+/(\d+)} ) {
                my $attachment = RT::Attachment->new( $args{CurrentUser} );
                $attachment->Load($1);
                if ( $attachment->CurrentUserCanSee ) {
                    $content_type = $attachment->ContentType;
                    $content      = $attachment->Content;
                }
                else {
                    RT->Logger->warning( "Attachment #$1 is not visible to current user #" . $args{CurrentUser}->Id );
                }
            }

            if ($content) {
                my $cid = sha1_hex($content) . '@' . RT->Config->Get('rtname');
                push @images, { cid => $cid, content => $content, content_type => $content_type } unless $added{$cid}++;
                return "cid:$cid";
            }

            return $uri;
        }
    );
    return ( $content, @images );
}

package HTML::Mason::Commands;

use vars qw/$r $m %session/;

use Scalar::Util qw(blessed);

sub Menu {
    return $HTML::Mason::Commands::m->notes('menu');
}

sub SearchResultsPageMenu {
    return $HTML::Mason::Commands::m->notes('search-results-page-menu');
}

sub PageMenu {
    return $HTML::Mason::Commands::m->notes('page-menu');
}

sub PageWidgets {
    return $HTML::Mason::Commands::m->notes('page-widgets');
}

sub RenderMenu {
    my %args = (toplevel => 1, parent_id => '', depth => 0, @_);
    return unless $args{'menu'};

    my ($menu, $depth, $toplevel, $id, $parent_id)
        = @args{qw(menu depth toplevel id parent_id)};

    my $interp = $m->interp;
    my $web_path = RT->Config->Get('WebPath');

    my $res = '';
    $res .= ' ' x $depth;
    $res .= '<ul';
    $res .= ' id="'. $interp->apply_escapes($id, 'h') .'"'
        if $id;
    my $class = $args{class} // '';
    $class .= $toplevel ? ' navbar-nav toplevel' : ' dropdown-menu';
    $res .= " class='$class'";
    $res .= ">\n";

    for my $child ($menu->children) {
        $res .= ' 'x ($depth+1);

        my $item_id = lc(($parent_id? "$parent_id-" : "") .$child->key);
        $item_id =~ s/\s/-/g;
        my $eitem_id = $interp->apply_escapes($item_id, 'h');
        $res .= qq{<li id="li-$eitem_id"};

        my @classes;
        push @classes, 'nav-item dropdown' if $toplevel;
        push @classes, 'has-children' if $child->has_children;
        push @classes, 'dropend' if !$toplevel && $child->has_children;
        $res .= ' class="'. join( ' ', @classes ) .'"'
            if @classes;

        $res .= '>';

        if ( my $tmp = $child->raw_html ) {
            $res .= $tmp;
        } else {
            $res .= qq{<a id="$eitem_id" class="menu-item rounded };
            $res .= 'active ' if $child->active;
            if ( $toplevel ) {
                $res .= $child->has_children ? 'nav-link dropdown-toggle' : 'nav-link';
            }
            else {
                $res .= $child->has_children ? 'dropdown-item dropdown-toggle' : 'dropdown-item';
            }
            if ( $tmp = $child->class ) {
                $res .= ' '. $interp->apply_escapes($tmp, 'h');
            }
            $res .= ' btn' if ( defined $id && ( $id eq 'page-menu' || $id eq 'search-results-page-menu' ) );
            $res .= '"';

            my $path = $child->path;
            my $url = (not $path or $path =~ m{^\w+:/}) ? $path : $web_path . $path;
            $url ||= "#";
            $res .= ' href="'. $interp->apply_escapes($url, 'h') .'"';

            if ( $tmp = $child->target ) {
                $res .= ' target="'. $interp->apply_escapes($tmp, 'h') .'"'
            }

            if ($child->attributes) {
                for my $key (keys %{$child->attributes}) {
                    my ($name, $value) = map { $interp->apply_escapes($_, 'h') }
                                             $key, $child->attributes->{$key};
                    $res .= " $name=\"$value\"";
                }
            }
            $res .= '>';

            if ( $child->escape_title ) {
                $res .= $interp->apply_escapes($child->title, 'h');
            } else {
                $res .= $child->title;
            }
            $res .= '</a>';
        }

        if ( $child->has_children ) {
            $res .= "\n";
            $res .= RenderMenu(
                menu => $child,
                toplevel => 0,
                parent_id => $item_id,
                depth => $depth+1,
                return => 1,
            );
            $res .= "\n";
            $res .= ' ' x ($depth+1);
        }
        $res .= "</li>\n";
    }
    $res .= ' ' x $depth;
    $res .= '</ul>';
    return $res if $args{'return'};

    $m->print($res);
    return '';
}

=head2 loc ARRAY

loc is a nice clean global routine which calls $session{'CurrentUser'}->loc()
with whatever it's called with. If there is no $session{'CurrentUser'}, 
it creates a temporary user, so we have something to get a localisation handle
through

=cut

sub loc {

    if ( $session{'CurrentUser'}
        && UNIVERSAL::can( $session{'CurrentUser'}, 'loc' ) )
    {
        return ( $session{'CurrentUser'}->loc(@_) );
    } elsif (
        my $u = eval {
            RT::CurrentUser->new();
        }
        )
    {
        return ( $u->loc(@_) );
    } else {

        # pathetic case -- SystemUser is gone.
        return $_[0];
    }
}



=head2 loc_fuzzy STRING

loc_fuzzy is for handling localizations of messages that may already
contain interpolated variables, typically returned from libraries
outside RT's control.  It takes the message string and extracts the
variable array automatically by matching against the candidate entries
inside the lexicon file.

=cut

sub loc_fuzzy {
    my $msg = shift;

    if ( $session{'CurrentUser'}
        && UNIVERSAL::can( $session{'CurrentUser'}, 'loc' ) )
    {
        return ( $session{'CurrentUser'}->loc_fuzzy($msg) );
    } else {
        my $u = RT::CurrentUser->new( RT->SystemUser->Id );
        return ( $u->loc_fuzzy($msg) );
    }
}


# Error - calls Error and aborts
sub Abort {
    my $why  = shift;
    my %args = @_;

    $args{Code} //= HTTP::Status::HTTP_OK;

    $r->headers_out->{'Status'} = $args{Code} . ' ' . HTTP::Status::status_message($args{Code});

    if (   $session{'ErrorDocument'}
        && $session{'ErrorDocumentType'} )
    {
        $r->content_type( $session{'ErrorDocumentType'} );
        $m->comp( $session{'ErrorDocument'}, Why => $why, %args );
        $m->abort;
    } else {
        $m->comp( "/Elements/Error", Why => $why, %args );
        $m->abort;
    }
}

sub MaybeRedirectForResults {
    my %args = (
        Path      => $HTML::Mason::Commands::m->request_comp->path,
        Arguments => {},
        Anchor    => undef,
        Actions   => undef,
        Force     => 0,
        @_
    );
    my $has_actions = $args{'Actions'} && grep( defined, @{ $args{'Actions'} } );
    return unless $has_actions || $args{'Force'};

    my %arguments = %{ $args{'Arguments'} };

    if ( $has_actions ) {
        my $key = Digest::MD5::md5_hex( rand(1024) );
        my $actions_ref = [];
        if ( $session{"Actions"}{ $key } ) {
            $actions_ref = $session{"Actions"}{ $key };
        }
        push @{$actions_ref}, @{ $args{'Actions'} };

        RT::Interface::Web::Session::Set(
            Key    => 'Actions',
            SubKey => $key,
            Value  => $actions_ref,
        );

        $arguments{'results'} = $key;
    }

    $args{'Path'} =~ s!^/+!!;
    my $url = RT->Config->Get('WebURL') . $args{Path};

    if ( keys %arguments ) {
        $url .= '?'. $m->comp( '/Elements/QueryString', %arguments );
    }
    if ( $args{'Anchor'} ) {
        $url .= "#". $args{'Anchor'};
    }
    return RT::Interface::Web::Redirect($url);
}

=head2 MaybeRedirectToApproval Path => 'path', Whitelist => REGEX, ARGSRef => HASHREF

If the ticket specified by C<< $ARGSRef->{id} >> is an approval ticket,
redirect to the approvals display page, preserving any arguments.

C<Path>s matching C<Whitelist> are let through.

This is a no-op if the C<ForceApprovalsView> option isn't enabled.

=cut

sub MaybeRedirectToApproval {
    my %args = (
        Path        => $HTML::Mason::Commands::m->request_comp->path,
        ARGSRef     => {},
        Whitelist   => undef,
        @_
    );

    return unless RT::Interface::Web::RequestENV('REQUEST_METHOD') eq 'GET';

    my $id = $args{ARGSRef}->{id};

    if (    $id
        and RT->Config->Get('ForceApprovalsView')
        and not $args{Path} =~ /$args{Whitelist}/)
    {
        my $ticket = RT::Ticket->new( $session{'CurrentUser'} );
        $ticket->Load($id);

        if ($ticket and $ticket->id and lc($ticket->Type) eq 'approval') {
            MaybeRedirectForResults(
                Path      => "/Approvals/Display.html",
                Force     => 1,
                Anchor    => $args{ARGSRef}->{Anchor},
                Arguments => $args{ARGSRef},
            );
        }
    }
}

=head2 CreateTicket ARGS

Create a new ticket, using Mason's %ARGS.  returns @results.

=cut

sub CreateTicket {
    my %ARGS = (@_);

    my (@Actions);

    my $current_user = $session{'CurrentUser'};
    my $Ticket = delete $ARGS{TicketObj} || RT::Ticket->new( $current_user );

    my $Queue = RT::Queue->new( $current_user );
    unless ( $Queue->Load( $ARGS{'Queue'} ) ) {
        Abort('Queue not found', Code => HTTP::Status::HTTP_NOT_FOUND);
    }

    unless ( $Queue->CurrentUserHasRight('CreateTicket') ) {
        Abort('You have no permission to create tickets in that queue.', Code => HTTP::Status::HTTP_FORBIDDEN);
    }

    my $due;
    if ( defined $ARGS{'Due'} and $ARGS{'Due'} =~ /\S/ ) {
        $due = RT::Date->new( $current_user );
        $due->Set( Format => 'unknown', Value => $ARGS{'Due'} );
    }
    my $starts;
    if ( defined $ARGS{'Starts'} and $ARGS{'Starts'} =~ /\S/ ) {
        $starts = RT::Date->new( $current_user );
        $starts->Set( Format => 'unknown', Value => $ARGS{'Starts'} );
    }

    my $sigless = RT::Interface::Web::StripContent(
        Content        => $ARGS{Content},
        ContentType    => $ARGS{ContentType},
        StripSignature => 1,
        CurrentUser    => $current_user,
    );

    my $date_now = RT::Date->new( $current_user );
    $date_now->SetToNow;
    my $MIMEObj = MakeMIMEEntity(
        Subject => $ARGS{'Subject'},
        From    => $ARGS{'From'} || $current_user->EmailAddress,
        To      => $ARGS{'To'} || $Queue->CorrespondAddress
                               || RT->Config->Get('CorrespondAddress'),
        Cc      => $ARGS{'Cc'},
        Date    => $date_now->RFC2822(Timezone => 'user'),
        Body    => $sigless,
        Type    => $ARGS{'ContentType'},
        # Stick to "Mobile" for back compatibility, unless current interface is customized to something else
        RT->CurrentInterface eq 'Web' && RT::Interface::Web::MobileClient() ? ( Interface => 'Mobile' ) : (),
    );

    my @attachments;
    if ( my $tmp = $session{'Attachments'}{ $ARGS{'Token'} || '' } ) {
        push @attachments, grep $_, map $tmp->{$_}, sort keys %$tmp;

        unless ( $ARGS{'KeepAttachments'} or $Ticket->{DryRun} ) {
            RT::Interface::Web::Session::Delete(
                Key    => 'Attachments',
                SubKey => $ARGS{'Token'} || '',
            );
        }
    }
    if ( $ARGS{'Attachments'} ) {
        push @attachments, grep $_, map $ARGS{Attachments}->{$_}, sort keys %{ $ARGS{'Attachments'} };
    }
    if ( @attachments ) {
        $MIMEObj->make_multipart( 'mixed', Force => 1 );
        $MIMEObj->add_part( $_ ) foreach @attachments;
    }

    for my $argument (qw(Encrypt Sign)) {
        if ( defined $ARGS{ $argument } ) {
            $MIMEObj->head->replace( "X-RT-$argument" => $ARGS{$argument} ? 1 : 0 );
        }
    }

    my %create_args = (
        Type => $ARGS{'Type'} || 'ticket',
        Queue => $ARGS{'Queue'},
        SLA => $ARGS{'SLA'},
        InitialPriority => $ARGS{'InitialPriority'},
        FinalPriority   => $ARGS{'FinalPriority'},
        TimeLeft        => $ARGS{'TimeLeft'},
        TimeEstimated   => $ARGS{'TimeEstimated'},
        TimeWorked      => $ARGS{'TimeWorked'},
        Subject         => $ARGS{'Subject'},
        Status          => $ARGS{'Status'},
        Due             => $due ? $due->ISO : undef,
        Starts          => $starts ? $starts->ISO : undef,
        MIMEObj         => $MIMEObj,
        SquelchMailTo   => $ARGS{'SquelchMailTo'},
        TransSquelchMailTo => $ARGS{'TransSquelchMailTo'},

        (map { $_ => $ARGS{$_} } $Queue->Roles),
        # note: name change
        Requestor       => $ARGS{'Requestors'},
    );

    my @txn_squelch;
    foreach my $type (qw(Requestor Cc AdminCc)) {
        push @txn_squelch, map $_->address, Email::Address->parse( $create_args{$type} )
            if grep $_ eq $type || $_ eq ( $type . 's' ), @{ $ARGS{'SkipNotification'} || [] };
    }
    foreach my $role (grep { /^RT::CustomRole-\d+$/ } @{ $ARGS{'SkipNotification'} || [] }) {
        push @txn_squelch, map $_->address, Email::Address->parse( $create_args{$role} );
    }
    push @{$create_args{TransSquelchMailTo}}, @txn_squelch;

    if ( $ARGS{'AttachTickets'} ) {
        require RT::Action::SendEmail;
        RT::Action::SendEmail->AttachTickets( RT::Action::SendEmail->AttachTickets,
            ref $ARGS{'AttachTickets'}
            ? @{ $ARGS{'AttachTickets'} }
            : ( $ARGS{'AttachTickets'} ) );
    }

    my %cfs = ProcessObjectCustomFieldUpdatesForCreate(
        ARGSRef         => \%ARGS,
        ContextObject   => $Queue,
    );

    my %links = ProcessLinksForCreate( ARGSRef => \%ARGS );

    my ( $id, $Trans, $ErrMsg ) = $Ticket->Create(%create_args, %links, %cfs);

    unless ($id) {
        Abort($ErrMsg);
    }

    push( @Actions, split( "\n", $ErrMsg ) );
    unless ( $Ticket->CurrentUserHasRight('ShowTicket') ) {
        Abort( "No permission to view newly created ticket #" . $Ticket->id . ".", Code => HTTP::Status::HTTP_FORBIDDEN );
    }
    return ( $Ticket, @Actions );

}



=head2  LoadTicket id

Takes a ticket id as its only variable. if it's handed an array, it takes
the first value.

Returns an RT::Ticket object as the current user.

=cut

sub LoadTicket {
    my $id = shift;

    if ( ref($id) eq "ARRAY" ) {
        $id = $id->[0];
    }

    unless ($id) {
        Abort("No ticket specified", Code => HTTP::Status::HTTP_BAD_REQUEST);
    }

    my $Ticket = RT::Ticket->new( $session{'CurrentUser'} );
    $Ticket->Load($id);
    unless ( $Ticket->id ) {
        Abort("Could not load ticket $id", Code => HTTP::Status::HTTP_NOT_FOUND);
    }
    return $Ticket;
}



=head2 ProcessUpdateMessage

Takes paramhash with fields ARGSRef, TicketObj and SkipSignatureOnly.

Don't write message if it only contains current user's signature and
SkipSignatureOnly argument is true. Function anyway adds attachments
and updates time worked field even if skips message. The default value
is true.

=cut

sub ProcessUpdateMessage {

    my %args = (
        ARGSRef           => undef,
        TicketObj         => undef,
        SkipSignatureOnly => 1,
        @_
    );

    my @attachments;
    if ( my $tmp = $session{'Attachments'}{ $args{'ARGSRef'}{'Token'} || '' } ) {
        push @attachments, grep $_, map $tmp->{$_}, sort keys %$tmp;

        unless ( $args{'KeepAttachments'} or ( $args{TicketObj} and $args{TicketObj}{DryRun} ) ) {
            RT::Interface::Web::Session::Delete(
                Key    => 'Attachments',
                SubKey => $args{'ARGSRef'}{'Token'} || '',
            );
        }
    }
    if ( $args{ARGSRef}{'UpdateAttachments'} ) {
        push @attachments, grep $_, map $args{ARGSRef}->{UpdateAttachments}{$_},
                                   sort keys %{ $args{ARGSRef}->{'UpdateAttachments'} };
    }

    # Strip the signature
    $args{ARGSRef}->{UpdateContent} = RT::Interface::Web::StripContent(
        Content        => $args{ARGSRef}->{UpdateContent},
        ContentType    => $args{ARGSRef}->{UpdateContentType},
        StripSignature => $args{SkipSignatureOnly},
        CurrentUser    => $args{'TicketObj'}->CurrentUser,
    );

    # If, after stripping the signature, we have no message, move the
    # UpdateTimeWorked into adjusted TimeWorked, so that a later
    # ProcessBasics can deal -- then bail out.
    if (    not @attachments
        and not $args{ARGSRef}->{'AttachTickets'}
        and not length $args{ARGSRef}->{'UpdateContent'} )
    {
        if ( $args{ARGSRef}->{'UpdateTimeWorked'} ) {
            $args{ARGSRef}->{TimeWorked} = $args{TicketObj}->TimeWorked + delete $args{ARGSRef}->{'UpdateTimeWorked'};
        }
        return;
    }

    if ( ($args{ARGSRef}->{'UpdateSubject'}||'') eq ($args{'TicketObj'}->Subject || '') ) {
        $args{ARGSRef}->{'UpdateSubject'} = undef;
    }

    my $Message = MakeMIMEEntity(
        Subject => $args{ARGSRef}->{'UpdateSubject'},
        Body    => $args{ARGSRef}->{'UpdateContent'},
        Type    => $args{ARGSRef}->{'UpdateContentType'},
        # Stick to "Mobile" for back compatibility, unless current interface is customized to something else
        RT->CurrentInterface eq 'Web' && RT::Interface::Web::MobileClient() ? ( Interface => 'Mobile' ) : (),
    );

    $Message->head->replace( 'Message-ID' => Encode::encode( "UTF-8",
        RT::Interface::Email::GenMessageId( Ticket => $args{'TicketObj'} )
    ) );
    my $old_txn = RT::Transaction->new( $session{'CurrentUser'} );
    if ( $args{ARGSRef}->{'QuoteTransaction'} ) {
        $old_txn->Load( $args{ARGSRef}->{'QuoteTransaction'} );
    } else {
        $old_txn = $args{TicketObj}->Transactions->First();
    }

    if ( my $msg = $old_txn->Message->First ) {
        RT::Interface::Email::SetInReplyTo(
            Message   => $Message,
            InReplyTo => $msg,
            Ticket    => $args{'TicketObj'},
        );
    }

    if ( @attachments ) {
        $Message->make_multipart( 'mixed', Force => 1 );
        $Message->add_part( $_ ) foreach @attachments;
    }

    if ( $args{ARGSRef}->{'AttachTickets'} ) {
        require RT::Action::SendEmail;
        RT::Action::SendEmail->AttachTickets( RT::Action::SendEmail->AttachTickets,
            ref $args{ARGSRef}->{'AttachTickets'}
            ? @{ $args{ARGSRef}->{'AttachTickets'} }
            : ( $args{ARGSRef}->{'AttachTickets'} ) );
    }

    my %message_args = (
        Sign         => $args{ARGSRef}->{'Sign'},
        Encrypt      => $args{ARGSRef}->{'Encrypt'},
        MIMEObj      => $Message,
        TimeTaken    => $args{ARGSRef}->{'UpdateTimeWorked'},
        AttachExisting => $args{ARGSRef}->{'AttachExisting'},
    );

    _ProcessUpdateMessageRecipients(
        MessageArgs => \%message_args,
        %args,
    );

    my @results;
    if ( $args{ARGSRef}->{'UpdateType'} =~ /^(private|public)$/ ) {
        my ( $Transaction, $Description, $Object ) = $args{TicketObj}->Comment(%message_args);
        push( @results, $Description );
        $Object->UpdateCustomFields( %{ $args{ARGSRef} } ) if $Object;
    } elsif ( $args{ARGSRef}->{'UpdateType'} eq 'response' ) {
        my ( $Transaction, $Description, $Object ) = $args{TicketObj}->Correspond(%message_args);
        push( @results, $Description );
        $Object->UpdateCustomFields( %{ $args{ARGSRef} } ) if $Object;
    } else {
        push( @results,
            loc("Update type was neither correspondence nor comment.") . " " . loc("Update not recorded.") );
    }
    return @results;
}

sub _ProcessUpdateMessageRecipients {
    my %args = (
        ARGSRef           => undef,
        TicketObj         => undef,
        MessageArgs       => undef,
        @_,
    );

    my $bcc = $args{ARGSRef}->{'UpdateBcc'};
    my $cc  = $args{ARGSRef}->{'UpdateCc'};

    my $message_args = $args{MessageArgs};

    $message_args->{CcMessageTo} = $cc;
    $message_args->{BccMessageTo} = $bcc;

    my @txn_squelch;
    foreach my $type (qw(Cc AdminCc)) {
        if (grep $_ eq $type || $_ eq ( $type . 's' ), @{ $args{ARGSRef}->{'SkipNotification'} || [] }) {
            push @txn_squelch, map $_->address, Email::Address->parse( $message_args->{$type} );
            push @txn_squelch, $args{TicketObj}->$type->MemberEmailAddresses;
            push @txn_squelch, $args{TicketObj}->QueueObj->$type->MemberEmailAddresses;
        }
    }
    for my $role (grep { /^RT::CustomRole-\d+$/ } @{ $args{ARGSRef}->{'SkipNotification'} || [] }) {
        push @txn_squelch, map $_->address, Email::Address->parse( $message_args->{$role} );
        push @txn_squelch, $args{TicketObj}->RoleGroup($role)->MemberEmailAddresses;
        push @txn_squelch, $args{TicketObj}->QueueObj->RoleGroup($role)->MemberEmailAddresses;
    }
    if (grep $_ eq 'Requestor' || $_ eq 'Requestors', @{ $args{ARGSRef}->{'SkipNotification'} || [] }) {
        push @txn_squelch, map $_->address, Email::Address->parse( $message_args->{Requestor} );
        push @txn_squelch, $args{TicketObj}->Requestors->MemberEmailAddresses;
    }

    push @txn_squelch, @{$args{ARGSRef}{SquelchMailTo}} if $args{ARGSRef}{SquelchMailTo};
    $message_args->{SquelchMailTo} = \@txn_squelch
        if @txn_squelch;

    $args{TicketObj}->{TransSquelchMailTo} ||= $message_args->{'SquelchMailTo'};

    unless ( $args{'ARGSRef'}->{'UpdateIgnoreAddressCheckboxes'} ) {
        foreach my $key ( keys %{ $args{ARGSRef} } ) {
            next unless $key =~ /^Update(Cc|Bcc)-(.*)$/;

            my $var   = ucfirst($1) . 'MessageTo';
            my $value = $2;
            if ( $message_args->{$var} ) {
                $message_args->{$var} .= ", $value";
            } else {
                $message_args->{$var} = $value;
            }
        }
    }
}

sub ProcessAttachments {
    my %args = (
        ARGSRef => {},
        Token   => '',
        # For back-compatibility, CheckSize is not enabled by default. But for
        # callers that mean to check returned values, it's safe to enable.
        CheckSize => wantarray ? 1 : 0,
        @_
    );

    my $token = $args{'ARGSRef'}{'Token'}
        ||= $args{'Token'} ||= Digest::MD5::md5_hex( rand(1024) );

    # deal with deleting uploaded attachments
    if ( my $del = $args{'ARGSRef'}{'DeleteAttach'} ) {
        foreach my $delete ( ref $del ? @$del : ($del) ) {
            RT::Interface::Web::Session::Delete(
                Key       => 'Attachments',
                SubKey    => $token,
                SubSubKey => $delete,
            );
        }
    }

    # store the uploaded attachment in session
    my $new = $args{'ARGSRef'}{'Attach'};
    if ( defined $new && length $new ) {
        my $attachment = MakeMIMEEntity(
            AttachmentFieldName => 'Attach'
        );

        # This needs to be decoded because the value is a reference;
        # hence it was not decoded along with all of the standard
        # arguments in DecodeARGS
        my $file_path = Encode::decode( "UTF-8", "$new");

        if ( $args{CheckSize} and my $max_size = RT->Config->Get( 'MaxAttachmentSize' ) ) {
            my $content = $attachment->bodyhandle->as_string;

            # The same encoding overhead as in Record.pm
            $max_size *= 3 / 4 if !$RT::Handle->BinarySafeBLOBs && $content =~ /\x00/;
            if ( length $content > $max_size ) {
                my $file_name = ( File::Spec->splitpath( $file_path ) )[ 2 ];
                return (
                    0,
                    loc(
                        "File '[_1]' size([_2] bytes) exceeds limit([_3] bytes)",
                        $file_name, length $content, $max_size
                    )
                );
            }
        }

        RT::Interface::Web::Session::Set(
            Key       => 'Attachments',
            SubKey    => $token,
            SubSubKey => $file_path,
            Value     => $attachment,
        );
    }

    return 1;
}


=head2 MakeMIMEEntity PARAMHASH

Takes a paramhash Subject, Body and AttachmentFieldName.

Also takes Form, Cc, Type, and ExtractImages as optional paramhash keys.

If ExtractImages is true(default value), it will extract images from the HTML
body and generate a corresponding "multiplart/related" entity that contains
the modified body and also extracted images.

  Returns a MIME::Entity.

=cut

sub MakeMIMEEntity {

    #TODO document what else this takes.
    my %args = (
        Subject             => undef,
        From                => undef,
        Cc                  => undef,
        Body                => undef,
        AttachmentFieldName => undef,
        Type                => undef,
        Interface           => undef,
        ExtractImages       => 1,
        @_,
    );

    my @images;
    if ( $args{ExtractImages} && ( $args{Type} // '' ) eq 'text/html' ) {
        ( $args{Body}, @images ) = RT::Interface::Web::ExtractImages( Content => $args{Body} );
    }

    my $Message = MIME::Entity->build(
        Type    => 'multipart/mixed',
        "Message-Id" => Encode::encode( "UTF-8", RT::Interface::Email::GenMessageId ),
        "X-RT-Interface" => $args{Interface} || RT->CurrentInterface,
        map { $_ => Encode::encode( "UTF-8", $args{ $_} ) }
            grep defined $args{$_}, qw(Subject From Cc To Date)
    );

    if ( defined $args{'Body'} && length $args{'Body'} ) {

        # Make the update content have no 'weird' newlines in it
        $args{'Body'} =~ s/\r\n/\n/gs;

        $Message->attach(
            Type    => $args{'Type'} || 'text/plain',
            Charset => 'UTF-8',
            Data    => Encode::encode( "UTF-8", $args{'Body'} ),
        );
    }

    if ( $args{'AttachmentFieldName'} ) {

        my $cgi_object = $m->cgi_object;
        my $filehandle = $cgi_object->upload( $args{'AttachmentFieldName'} );
        if ( defined $filehandle && length $filehandle ) {

            my ( @content, $buffer );
            while ( my $bytesread = read( $filehandle, $buffer, 4096 ) ) {
                push @content, $buffer;
            }

            my $uploadinfo = $cgi_object->uploadInfo($filehandle);

            my $filename = Encode::decode("UTF-8","$filehandle");
            $filename =~ s{^.*[\\/]}{};

            $Message->attach(
                Type     => $uploadinfo->{'Content-Type'},
                Filename => Encode::encode("UTF-8",$filename),
                Data     => \@content, # Bytes, as read directly from the file, above
            );
            if ( !$args{'Subject'} && !( defined $args{'Body'} && length $args{'Body'} ) ) {
                $Message->head->replace( 'Subject' => Encode::encode( "UTF-8", $filename ) );
            }

            # Attachment parts really shouldn't get a Message-ID or "interface"
            $Message->head->delete('Message-ID');
            $Message->head->delete('X-RT-Interface');
        }
    }

    $Message->make_singlepart;

    RT::I18N::SetMIMEEntityToUTF8($Message);    # convert text parts into utf-8

    if (@images) {
        $Message->make_multipart('related');
        # RFC2387 3.1 says that "type" must be specified
        $Message->head->mime_attr('Content-type.type' => 'text/html');
        for my $image (@images) {
            $Message->attach(
                Type         => $image->{content_type},
                Data         => $image->{content},
                Disposition  => 'inline',
                Id           => $image->{cid},
            );
        }
    }

    return ($Message);

}



=head2 ParseDateToISO

Takes a date in an arbitrary format.
Returns an ISO date and time in GMT

=cut

sub ParseDateToISO {
    my $date = shift;

    my $date_obj = RT::Date->new( $session{'CurrentUser'} );
    $date_obj->Set(
        Format => 'unknown',
        Value  => $date
    );
    return ( $date_obj->ISO );
}



sub ProcessACLChanges {
    my $ARGSref = shift;

    #XXX: why don't we get ARGSref like in other Process* subs?

    my @results;

    foreach my $arg ( keys %$ARGSref ) {
        next unless ( $arg =~ /^(GrantRight|RevokeRight)-(\d+)-(.+?)-(\d+)$/ );

        my ( $method, $principal_id, $object_type, $object_id ) = ( $1, $2, $3, $4 );

        my @rights;
        if ( UNIVERSAL::isa( $ARGSref->{$arg}, 'ARRAY' ) ) {
            @rights = @{ $ARGSref->{$arg} };
        } else {
            @rights = $ARGSref->{$arg};
        }
        @rights = grep $_, @rights;
        next unless @rights;

        my $principal = RT::Principal->new( $session{'CurrentUser'} );
        $principal->Load($principal_id);

        my $obj;
        if ( $object_type eq 'RT::System' ) {
            $obj = $RT::System;
        } elsif ( $object_type->DOES('RT::Record::Role::Rights') ) {
            $obj = $object_type->new( $session{'CurrentUser'} );
            $obj->Load($object_id);
            unless ( $obj->id ) {
                $RT::Logger->error("couldn't load $object_type #$object_id");
                next;
            }
        } else {
            $RT::Logger->error("object type '$object_type' is incorrect");
            push( @results, loc("System Error") . ': ' . loc( "Rights could not be granted for [_1]", $object_type ) );
            next;
        }

        foreach my $right (@rights) {
            my ( $val, $msg ) = $principal->$method( Object => $obj, Right => $right );
            push( @results, $msg );
        }
    }

    return (@results);
}


=head2 ProcessACLs

ProcessACLs expects values from a series of checkboxes that describe the full
set of rights a principal should have on an object.

It expects form inputs with names like SetRights-PrincipalId-ObjType-ObjId
instead of with the prefixes Grant/RevokeRight.  Each input should be an array
listing the rights the principal should have, and ProcessACLs will modify the
current rights to match.  Additionally, the previously unused CheckACL input
listing PrincipalId-ObjType-ObjId is now used to catch cases when all the
rights are removed from a principal and as such no SetRights input is
submitted.

=cut

sub ProcessACLs {
    my $ARGSref = shift;
    my (%state, @results);

    my $CheckACL = $ARGSref->{'CheckACL'};
    my @check = grep { defined } (ref $CheckACL eq 'ARRAY' ? @$CheckACL : $CheckACL);

    # Check if we want to grant rights to a previously rights-less user
    for my $type (qw(user group)) {
        my $principal = _ParseACLNewPrincipal($ARGSref, $type)
            or next;

        unless ($principal->PrincipalId) {
            push @results, loc("Couldn't load the specified principal");
            next;
        }

        my $principal_id = $principal->PrincipalId;

        # Turn our addprincipal rights spec into a real one
        for my $arg (keys %$ARGSref) {
            next unless $arg =~ /^SetRights-addprincipal-(.+?-\d+)$/;

            my $tuple = "$principal_id-$1";
            my $key   = "SetRights-$tuple";

            # If we have it already, that's odd, but merge them
            if (grep { $_ eq $tuple } @check) {
                $ARGSref->{$key} = [
                    (ref $ARGSref->{$key} eq 'ARRAY' ? @{$ARGSref->{$key}} : $ARGSref->{$key}),
                    (ref $ARGSref->{$arg} eq 'ARRAY' ? @{$ARGSref->{$arg}} : $ARGSref->{$arg}),
                ];
            } else {
                $ARGSref->{$key} = $ARGSref->{$arg};
                push @check, $tuple;
            }
        }
    }

    # Build our rights state for each Principal-Object tuple
    foreach my $arg ( keys %$ARGSref ) {
        next unless $arg =~ /^SetRights-(\d+-.+?-\d+)$/;

        my $tuple  = $1;
        my $value  = $ARGSref->{$arg};
        my @rights = grep { $_ } (ref $value eq 'ARRAY' ? @$value : $value);
        next unless @rights;

        $state{$tuple} = { map { $_ => 1 } @rights };
    }

    foreach my $tuple (List::MoreUtils::uniq @check) {
        next unless $tuple =~ /^(\d+)-(.+?)-(\d+)$/;

        my ( $principal_id, $object_type, $object_id ) = ( $1, $2, $3 );

        my $principal = RT::Principal->new( $session{'CurrentUser'} );
        $principal->Load($principal_id);

        my $obj;
        if ( $object_type eq 'RT::System' ) {
            $obj = $RT::System;
        } elsif ( $object_type->DOES('RT::Record::Role::Rights') ) {
            $obj = $object_type->new( $session{'CurrentUser'} );
            $obj->Load($object_id);
            unless ( $obj->id ) {
                $RT::Logger->error("couldn't load $object_type #$object_id");
                next;
            }
        } else {
            $RT::Logger->error("object type '$object_type' is incorrect");
            push( @results, loc("System Error") . ': ' . loc( "Rights could not be granted for [_1]", $object_type ) );
            next;
        }

        my $acls = RT::ACL->new($session{'CurrentUser'});
        $acls->LimitToObject( $obj );
        $acls->LimitToPrincipal( Id => $principal_id );

        while ( my $ace = $acls->Next ) {
            my $right = $ace->RightName;

            # Has right and should have right
            next if delete $state{$tuple}->{$right};

            # Has right and shouldn't have right
            my ($val, $msg) = $principal->RevokeRight( Object => $obj, Right => $right );
            push @results, $msg;
        }

        # For everything left, they don't have the right but they should
        for my $right (keys %{ $state{$tuple} || {} }) {
            delete $state{$tuple}->{$right};
            my ($val, $msg) = $principal->GrantRight( Object => $obj, Right => $right );
            push @results, $msg;
        }

        # Check our state for leftovers
        if ( keys %{ $state{$tuple} || {} } ) {
            my $missed = join '|', %{$state{$tuple} || {}};
            $RT::Logger->warn(
               "Uh-oh, it looks like we somehow missed a right in "
              ."ProcessACLs.  Here's what was leftover: $missed"
            );
        }
    }

    return (@results);
}

=head2 _ParseACLNewPrincipal

Takes a hashref of C<%ARGS> and a principal type (C<user> or C<group>).  Looks
for the presence of rights being added on a principal of the specified type,
and returns undef if no new principal is being granted rights.  Otherwise loads
up an L<RT::User> or L<RT::Group> object and returns it.  Note that the object
may not be successfully loaded, and you should check C<->id> yourself.

=cut

sub _ParseACLNewPrincipal {
    my $ARGSref = shift;
    my $type    = lc shift;
    my $key     = "AddPrincipalForRights-$type";

    return unless $ARGSref->{$key};

    my $principal;
    if ( $type eq 'user' ) {
        $principal = RT::User->new( $session{'CurrentUser'} );
        $principal->LoadByCol( Name => $ARGSref->{$key} );
    }
    elsif ( $type eq 'group' ) {
        $principal = RT::Group->new( $session{'CurrentUser'} );
        $principal->LoadUserDefinedGroup( $ARGSref->{$key} );
    }
    return $principal;
}


=head2 UpdateRecordObj ( ARGSRef => \%ARGS, Object => RT::Record, AttributesRef => \@attribs)

@attribs is a list of ticket fields to check and update if they differ from the  B<Object>'s current values. ARGSRef is a ref to HTML::Mason's %ARGS.

Returns an array of success/failure messages

=cut

sub UpdateRecordObject {
    my %args = (
        ARGSRef         => undef,
        AttributesRef   => undef,
        Object          => undef,
        AttributePrefix => undef,
        @_
    );

    my $Object  = $args{'Object'};
    my @results = $Object->Update(
        AttributesRef   => $args{'AttributesRef'},
        ARGSRef         => $args{'ARGSRef'},
        AttributePrefix => $args{'AttributePrefix'},
    );

    return (@results);
}



sub ProcessCustomFieldUpdates {
    my %args = (
        CustomFieldObj => undef,
        ARGSRef        => undef,
        @_
    );

    my $Object  = $args{'CustomFieldObj'};
    my $ARGSRef = $args{'ARGSRef'};

    my @attribs = qw(Name Type Description Queue SortOrder);
    my @results = UpdateRecordObject(
        AttributesRef => \@attribs,
        Object        => $Object,
        ARGSRef       => $ARGSRef
    );

    my $prefix = "CustomField-" . $Object->Id;
    if ( $ARGSRef->{"$prefix-AddValue-Name"} ) {
        my ( $addval, $addmsg ) = $Object->AddValue(
            Name        => $ARGSRef->{"$prefix-AddValue-Name"},
            Description => $ARGSRef->{"$prefix-AddValue-Description"},
            SortOrder   => $ARGSRef->{"$prefix-AddValue-SortOrder"},
        );
        push( @results, $addmsg );
    }

    my @delete_values
        = ( ref $ARGSRef->{"$prefix-DeleteValue"} eq 'ARRAY' )
        ? @{ $ARGSRef->{"$prefix-DeleteValue"} }
        : ( $ARGSRef->{"$prefix-DeleteValue"} );

    foreach my $id (@delete_values) {
        next unless defined $id;
        my ( $err, $msg ) = $Object->DeleteValue($id);
        push( @results, $msg );
    }

    my $vals = $Object->Values();
    while ( my $cfv = $vals->Next() ) {
        if ( my $so = $ARGSRef->{ "$prefix-SortOrder" . $cfv->Id } ) {
            if ( $cfv->SortOrder != $so ) {
                my ( $err, $msg ) = $cfv->SetSortOrder($so);
                push( @results, $msg );
            }
        }
    }

    return (@results);
}

=head2 ProcessTicketOwnerUpdate ( TicketObj => $Ticket, ARGSRef => \%ARGS );

Processes just Owner updates on the provided ticket, based
on the provided ARGS.

Returns an array of results messages.

=cut

sub ProcessTicketOwnerUpdate {

    my %args = (
        TicketObj => undef,
        ARGSRef   => undef,
        @_
    );

    my $TicketObj = $args{'TicketObj'};
    my $ARGSRef   = $args{'ARGSRef'};
    my @results;

    my $OrigOwner = $TicketObj->Owner;

    # Canonicalize Owner to ID if it's not numeric
    if ( $ARGSRef->{'Owner'} and ( $ARGSRef->{'Owner'} !~ /^(\d+)$/ ) ) {
        my $temp = RT::User->new(RT->SystemUser);
        $temp->Load( $ARGSRef->{'Owner'} );
        if ( $temp->id ) {
            $ARGSRef->{'Owner'} = $temp->Id;
        }
    }

    # We special case owner changing, so we can use ForceOwnerChange
    if ( $ARGSRef->{'Owner'}
      && $ARGSRef->{'Owner'} !~ /\D/
      && ( $OrigOwner != $ARGSRef->{'Owner'} ) ) {
        my ($ChownType);
        if ( $ARGSRef->{'ForceOwnerChange'} ) {
            $ChownType = "Force";
        }
        else {
            $ChownType = "Set";
        }

        my ( $val, $msg ) = $TicketObj->SetOwner( $ARGSRef->{'Owner'}, $ChownType );
        push( @results, $msg );
    }

    return (@results);
}

=head2 ProcessTicketBasics ( TicketObj => $Ticket, ARGSRef => \%ARGS );

Returns an array of results messages.

=cut

# ProcessTicketOwnerUpdate updates Owner only and was created to run
# earlier in the ticket update process. Keep Owner update code here
# also for any existing code that might call ProcessTicketBasics.
#
# If ProcessTicketOwnerUpdate handles the update first, it should be
# a noop here.

sub ProcessTicketBasics {

    my %args = (
        TicketObj => undef,
        ARGSRef   => undef,
        @_
    );

    my $TicketObj = $args{'TicketObj'};
    my $ARGSRef   = $args{'ARGSRef'};

    my $OrigOwner = $TicketObj->Owner;

    # Set basic fields
    my @attribs = qw(
        Subject
        FinalPriority
        Priority
        TimeEstimated
        TimeLeft
        Type
        Status
        Queue
        SLA
    );

    # Canonicalize Queue and Owner to their IDs if they aren't numeric
    for my $field (qw(Queue Owner)) {
        if ( $ARGSRef->{$field} and ( $ARGSRef->{$field} !~ /^(\d+)$/ ) ) {
            my $class = $field eq 'Owner' ? "RT::User" : "RT::$field";
            my $temp = $class->new(RT->SystemUser);
            $temp->Load( $ARGSRef->{$field} );
            if ( $temp->id ) {
                $ARGSRef->{$field} = $temp->id;
            }
        }
    }

    # Status isn't a field that can be set to a null value.
    # RT core complains if you try
    delete $ARGSRef->{'Status'} unless $ARGSRef->{'Status'};

    my @results = UpdateRecordObject(
        AttributesRef => \@attribs,
        Object        => $TicketObj,
        ARGSRef       => $ARGSRef,
    );

    if ( defined($ARGSRef->{'TimeWorked'}) && ($ARGSRef->{'TimeWorked'} || 0) != $TicketObj->TimeWorked ) {
        my ( $val, $msg, $txn ) = $TicketObj->SetTimeWorked( $ARGSRef->{'TimeWorked'} );
        push( @results, $msg );
        $txn->UpdateCustomFields( %$ARGSRef) if $txn;
    }

    # We special case owner changing, so we can use ForceOwnerChange
    if ( $ARGSRef->{'Owner'}
      && $ARGSRef->{'Owner'} !~ /\D/
      && ( $OrigOwner != $ARGSRef->{'Owner'} ) ) {
        my ($ChownType);
        if ( $ARGSRef->{'ForceOwnerChange'} ) {
            $ChownType = "Force";
        }
        else {
            $ChownType = "Set";
        }

        my ( $val, $msg ) = $TicketObj->SetOwner( $ARGSRef->{'Owner'}, $ChownType );
        push( @results, $msg );
    }

    # }}}

    return (@results);
}

=head2 ProcessTicketDescription ( TicketObj => $Ticket, ARGSRef => \%ARGS );

Returns an array of results messages.

=cut

sub ProcessTicketDescription {

    my %args = (
        TicketObj => undef,
        ARGSRef   => undef,
        @_
    );

    my $TicketObj = $args{'TicketObj'};
    my $ARGSRef   = $args{'ARGSRef'};

    # Set basic fields
    my @attribs = qw( Description );

    my @results = UpdateRecordObject(
        AttributesRef => \@attribs,
        Object        => $TicketObj,
        ARGSRef       => $ARGSRef,
    );

    return (@results);
}

sub ProcessTicketReminders {
    my %args = (
        TicketObj => undef,
        ARGSRef   => undef,
        @_
    );

    my $Ticket = $args{'TicketObj'};
    my $args   = $args{'ARGSRef'};
    my @results;

    my $reminder_collection = $Ticket->Reminders->Collection;

    if ( $args->{'update-reminders'} ) {
        while ( my $reminder = $reminder_collection->Next ) {
            my $resolve_status = $reminder->LifecycleObj->ReminderStatusOnResolve;
            my ( $status, $msg, $old_subject, @subresults );
            if (   $reminder->Status ne $resolve_status
                && $args->{ 'Complete-Reminder-' . $reminder->id } )
            {
                ( $status, $msg ) = $Ticket->Reminders->Resolve($reminder);
                push @subresults, $msg;
            }
            elsif ( $reminder->Status eq $resolve_status
                && !$args->{ 'Complete-Reminder-' . $reminder->id } )
            {
                ( $status, $msg ) = $Ticket->Reminders->Open($reminder);
                push @subresults, $msg;
            }

            if (
                exists( $args->{ 'Reminder-Subject-' . $reminder->id } )
                && ( $reminder->Subject ne
                    $args->{ 'Reminder-Subject-' . $reminder->id } )
              )
            {
                $old_subject = $reminder->Subject;
                ( $status, $msg ) =
                  $reminder->SetSubject(
                    $args->{ 'Reminder-Subject-' . $reminder->id } );
                push @subresults, $msg;
            }

            if (
                exists( $args->{ 'Reminder-Owner-' . $reminder->id } )
                && ( $reminder->Owner !=
                    $args->{ 'Reminder-Owner-' . $reminder->id } )
              )
            {
                ( $status, $msg ) =
                  $reminder->SetOwner(
                    $args->{ 'Reminder-Owner-' . $reminder->id }, "Force" );
                push @subresults, $msg;
            }

            if ( exists( $args->{ 'Reminder-Due-' . $reminder->id } )
                && $args->{ 'Reminder-Due-' . $reminder->id } ne '' )
            {
                my $DateObj = RT::Date->new( $session{'CurrentUser'} );
                my $due     = $args->{ 'Reminder-Due-' . $reminder->id };

                $DateObj->Set(
                    Format => 'unknown',
                    Value  => $due,
                );
                if ( $DateObj->Unix != $reminder->DueObj->Unix ) {
                    ( $status, $msg ) = $reminder->SetDue( $DateObj->ISO );
                    push @subresults, $msg;
                }
            }

            push @results, map {
                loc( "Reminder '[_1]': [_2]", $old_subject || $reminder->Subject, $_ )
            } @subresults;
        }
    }

    if ( $args->{'NewReminder-Subject'} ) {
        my $due_obj = RT::Date->new( $session{'CurrentUser'} );
        $due_obj->Set(
          Format => 'unknown',
          Value => $args->{'NewReminder-Due'}
        );
        my ( $status, $msg ) = $Ticket->Reminders->Add(
            Subject => $args->{'NewReminder-Subject'},
            Owner   => $args->{'NewReminder-Owner'},
            Due     => $due_obj->ISO
        );
        if ( $status ) {
            push @results,
              loc( "Reminder '[_1]': [_2]", $args->{'NewReminder-Subject'}, loc("Created") )
        }
        else {
            push @results, $msg;
        }
    }
    return @results;
}

sub _ValidateConsistentCustomFieldValues {
    my $cf = shift;
    my $args = shift;
    my $ok = 1;

    my @groupings = sort keys %$args;
    return ($ok, undef) unless @groupings;
    my $default_grouping = $groupings[0]; # Default to use if multiple are submitted

    if (@groupings > 1) {
        # Check for consistency, in case of JS fail
        for my $key (qw/AddValue Value Values DeleteValues DeleteValueIds/) {
            my $base = $args->{$groupings[0]}{$key};
            $base = [ $base ] unless ref $base;
            for my $grouping (@groupings[1..$#groupings]) {
                my $other = $args->{$grouping}{$key};
                $other = [ $other ] unless ref $other;
                next unless grep {$_} List::MoreUtils::pairwise {
                    no warnings qw(uninitialized);
                    $a ne $b
                } @{$base}, @{$other};

                RT::Logger->warn("CF $cf submitted with multiple differing values");
                $ok = 0;
            }
        }
    }

    return ($ok, $default_grouping);
}

sub ProcessObjectCustomFieldUpdates {
    my %args    = @_;
    my $ARGSRef = $args{'ARGSRef'};
    my @results;

    # Build up a list of objects that we want to work with
    my %custom_fields_to_mod = _ParseObjectCustomFieldArgs($ARGSRef);

    # For each of those objects
    foreach my $class ( keys %custom_fields_to_mod ) {
        foreach my $id ( keys %{ $custom_fields_to_mod{$class} } ) {
            my $Object = $args{'Object'};
            $Object = $class->new( $session{'CurrentUser'} )
                unless $Object && ref $Object eq $class;

            # skip if we have no object to update
            next unless $id || $Object->id;

            $Object->Load($id) unless ( $Object->id || 0 ) == $id;
            unless ( $Object->id ) {
                $RT::Logger->warning("Couldn't load object $class #$id");
                next;
            }

            foreach my $cf ( keys %{ $custom_fields_to_mod{$class}{$id} } ) {
                my $CustomFieldObj = RT::CustomField->new( $session{'CurrentUser'} );
                $CustomFieldObj->SetContextObject($Object);
                $CustomFieldObj->LoadById($cf);
                unless ( $CustomFieldObj->id ) {
                    $RT::Logger->warning("Couldn't load custom field #$cf");
                    next;
                }

                # In the case of inconsistent CFV submission,
                # we'll get the 1st grouping in the hash, alphabetically
                my ($ret, $grouping) = _ValidateConsistentCustomFieldValues($cf, $custom_fields_to_mod{$class}{$id}{$cf});

                push @results,
                    _ProcessObjectCustomFieldUpdates(
                        Prefix => GetCustomFieldInputNamePrefix(
                            Object      => $Object,
                            CustomField => $CustomFieldObj,
                            Grouping    => $grouping,
                        ),
                        Object      => $Object,
                        CustomField => $CustomFieldObj,
                        ARGS        => $custom_fields_to_mod{$class}{$id}{$cf}{ $grouping },
                    );
            }
        }
    }
    return @results;
}

sub _ParseObjectCustomFieldArgs {
    my $ARGSRef = shift || {};
    my %args = (
        IncludeBulkUpdate => 0,
        @_,
    );
    my %custom_fields_to_mod;

    foreach my $arg ( keys %$ARGSRef ) {

        # format: Object-<object class>-<object id>-CustomField[:<grouping>]-<CF id>-<commands>
        # you can use GetCustomFieldInputName to generate the complement input name
        # or if IncludeBulkUpdate: Bulk-<Add or Delete>-CustomField[:<grouping>]-<CF id>-<commands>
        next unless $arg =~ /^Object-([\w:]+)-(\d*)-CustomField(?::(\w+))?-(\d+)-(.*)$/
                 || ($args{IncludeBulkUpdate} && $arg =~ /^Bulk-(?:Add|Delete)-()()CustomField(?::(\w+))?-(\d+)-(.*)$/);
        # need two empty groups because we must consume $1 and $2 with empty
        # class and ID

        # For each of those objects, find out what custom fields we want to work with.
        #                   Class     ID     CF  grouping command
        $custom_fields_to_mod{$1}{ $2 || 0 }{$4}{$3 || ''}{$5} = $ARGSRef->{$arg};
    }

    return wantarray ? %custom_fields_to_mod : \%custom_fields_to_mod;
}

sub _ProcessObjectCustomFieldUpdates {
    my %args    = @_;
    my $cf      = $args{'CustomField'};
    my $cf_type = $cf->Type || '';

    # Remove blank Values since the magic field will take care of this. Sometimes
    # the browser gives you a blank value which causes CFs to be processed twice
    if (   defined $args{'ARGS'}->{'Values'}
        && !length $args{'ARGS'}->{'Values'}
        && ($args{'ARGS'}->{'Values-Magic'}) )
    {
        delete $args{'ARGS'}->{'Values'};
    }

    if ($cf_type eq 'HTML') {
        # this field is needed only to create the ckeditor
        delete $args{'ARGS'}->{'ValuesType'};
    }

    my @results;
    foreach my $arg ( keys %{ $args{'ARGS'} } ) {

        # skip category argument
        next if $arg =~ /-Category$/;

        # since http won't pass in a form element with a null value, we need
        # to fake it
        if ( $arg =~ /-Magic$/ ) {

            # We don't care about the magic, if there's really a values element;
            next if defined $args{'ARGS'}->{'Value'}  && length $args{'ARGS'}->{'Value'};
            next if defined $args{'ARGS'}->{'Values'} && length $args{'ARGS'}->{'Values'};

            # "Empty" values does not mean anything for Image and Binary fields
            next if $cf_type =~ /^(?:Image|Binary)$/;

            $arg = 'Values';
            $args{'ARGS'}->{'Values'} = undef;
        }

        my @values = _NormalizeObjectCustomFieldValue(
            CustomField => $cf,
            Param       => $args{'Prefix'} . $arg,
            Value       => $args{'ARGS'}->{$arg}
        );

        # "Empty" values still don't mean anything for Image and Binary fields
        next if $cf_type =~ /^(?:Image|Binary)$/ and not @values;

        if ( $arg eq 'AddValue' || $arg eq 'Value' ) {
            foreach my $value (@values) {
                next if $args{'Object'}->CustomFieldValueIsEmpty(
                    Field => $cf,
                    Value => $value,
                );
                my ( $val, $msg ) = $args{'Object'}->AddCustomFieldValue(
                    Field => $cf->id,
                    Value => $value
                );
                push( @results, $msg ) if $msg;
            }
        } elsif ( $arg eq 'Upload' ) {
            my ( $val, $msg ) = $args{'Object'}->AddCustomFieldValue( %{$values[0]}, Field => $cf, );
            push( @results, $msg ) if $msg;
        } elsif ( $arg eq 'DeleteValues' ) {
            foreach my $value (@values) {
                my ( $val, $msg ) = $args{'Object'}->DeleteCustomFieldValue(
                    Field => $cf,
                    Value => $value,
                );
                push( @results, $msg );
            }
        } elsif ( $arg eq 'DeleteValueIds' ) {
            foreach my $value (@values) {
                my ( $val, $msg ) = $args{'Object'}->DeleteCustomFieldValue(
                    Field   => $cf,
                    ValueId => $value,
                );
                push( @results, $msg );
            }
        } elsif ( $arg eq 'Values' ) {
            my $cf_values = $args{'Object'}->CustomFieldValues( $cf->id );

            my %values_hash;
            foreach my $value (@values) {
                if ( my $entry = $cf_values->HasEntry($value) ) {
                    $values_hash{ $entry->id } = 1;
                    next;
                }

                next if $args{'Object'}->CustomFieldValueIsEmpty(
                    Field => $cf,
                    Value => $value,
                );

                my ( $val, $msg ) = $args{'Object'}->AddCustomFieldValue(
                    Field => $cf,
                    Value => $value
                );
                push( @results, $msg ) if $msg;
                $values_hash{$val} = 1 if $val;
            }

            $cf_values->RedoSearch;
            while ( my $cf_value = $cf_values->Next ) {
                next if $values_hash{ $cf_value->id };

                my ( $val, $msg ) = $args{'Object'}->DeleteCustomFieldValue(
                    Field   => $cf,
                    ValueId => $cf_value->id
                );
                push( @results, $msg );
            }
        } else {
            push(
                @results,
                loc("User asked for an unknown update type for custom field [_1] for [_2] object #[_3]",
                    $cf->Name, ref $args{'Object'},
                    $args{'Object'}->id
                )
            );
        }
    }
    return @results;
}

sub ProcessObjectCustomFieldUpdatesForCreate {
    my %args = (
        ARGSRef         => {},
        ContextObject   => undef,
        @_
    );
    my $context = $args{'ContextObject'};
    my %parsed;
    my %custom_fields = _ParseObjectCustomFieldArgs( $args{'ARGSRef'} );

    for my $class (keys %custom_fields) {
        # we're only interested in new objects, so only look at $id == 0
        for my $cfid (keys %{ $custom_fields{$class}{0} || {} }) {
            my $cf = RT::CustomField->new( $session{'CurrentUser'} );
            $cf->{include_set_initial} = 1;
            if ($context) {
                my $system_cf = RT::CustomField->new( RT->SystemUser );
                $system_cf->LoadById($cfid);
                if ($system_cf->ValidateContextObject($context)) {
                    $cf->SetContextObject($context);
                } else {
                    RT->Logger->error(
                        sprintf "Invalid context object %s (%d) for CF %d; skipping CF",
                                ref $context, $context->id, $system_cf->id
                    );
                    next;
                }
            }
            $cf->LoadById($cfid);

            unless ($cf->id) {
                RT->Logger->warning("Couldn't load custom field #$cfid");
                next;
            }

            my @groupings = sort keys %{ $custom_fields{$class}{0}{$cfid} };
            if (@groupings > 1) {
                # Check for consistency, in case of JS fail
                for my $key (qw/AddValue Value Values DeleteValues DeleteValueIds/) {
                    warn "CF $cfid submitted with multiple differing $key"
                        if grep {($custom_fields{$class}{0}{$cfid}{$_}{$key} || '')
                             ne  ($custom_fields{$class}{0}{$cfid}{$groupings[0]}{$key} || '')}
                            @groupings;
                }
                # We'll just be picking the 1st grouping in the hash, alphabetically
            }

            my @values;
            my $name_prefix = GetCustomFieldInputNamePrefix(
                CustomField => $cf,
                Grouping    => $groupings[0],
            );
            while (my ($arg, $value) = each %{ $custom_fields{$class}{0}{$cfid}{$groupings[0]} }) {
                # Values-Magic doesn't matter on create; no previous values are being removed
                # Category is irrelevant for the actual value
                # ValuesType is only used for display
                next if $arg =~ /-Magic$/ or $arg =~ /-Category$/ or $arg eq 'ValuesType';

                push @values,
                    _NormalizeObjectCustomFieldValue(
                    CustomField => $cf,
                    Param       => $name_prefix . $arg,
                    Value       => $value,
                    );
            }

            if (@values) {
                if ( $class eq 'RT::Transaction' ) {
                    $parsed{"Object-RT::Transaction--CustomField-$cfid"} = \@values;
                }
                else {
                    $parsed{"CustomField-$cfid"} = \@values if @values;
                }
            }
        }
    }

    return wantarray ? %parsed : \%parsed;
}

sub _NormalizeObjectCustomFieldValue {
    my %args    = (
        Param   => "",
        @_
    );
    my $cf_type = $args{CustomField}->Type;
    my @values  = ();

    if ( ref $args{'Value'} eq 'ARRAY' ) {
        @values = @{ $args{'Value'} };
    } elsif ( $cf_type =~ /text|html/i ) {    # Text, HTML, and Wikitext
        @values = ( $args{'Value'} );
    } else {
        @values = split /\r*\n/, $args{'Value'}
            if defined $args{'Value'};
    }
    @values = grep length, map {
        s/\r+\n/\n/g;
        s/^\s+//;
        s/\s+$//;
        $_;
        }
        grep defined, @values;

    if ($args{'Param'} =~ /-Upload$/ and $cf_type =~ /^(Image|Binary)$/) {
        @values = _UploadedFile( $args{'Param'} ) || ();
    }

    # checking $values[0] is enough as Text/WikiText/HTML only support one value
    if ( $values[0] && $args{CustomField}->Type =~ /^(?:Text|WikiText|HTML)$/ ) {
        my $scrub_config = RT->Config->Get('ScrubCustomFieldOnSave') || {};
        my $msg          = loc( '[_1] scrubbed', $args{CustomField}->Name );

        # Scrubbed message could already exist as _NormalizeObjectCustomFieldValue can run multiple
        # times for a cf, e.g. in both /Elements/ValidateCustomFields and _ProcessObjectCustomFieldUpdates.
        if (
            (
                $scrub_config->{
                    $args{CustomField}->ObjectTypeFromLookupType( $args{CustomField}->__Value('LookupType') )
                } // $scrub_config->{Default}
            )
            && !grep { $_ eq $msg } @{ $session{"Actions"}->{''} ||= [] }
            )
        {
            my $new_value
                = ScrubHTML( Content => $values[0], Permissive => $args{CustomField}->_ContentIsPermissive );
            if ( $values[0] ne $new_value ) {
                my $actions_ref = $session{"Actions"}->{''} ||= [];
                push @{$actions_ref}, $msg;

                RT::Interface::Web::Session::Set(
                    Key    => 'Actions',
                    SubKey => '',
                    Value  => $actions_ref,
                );
                $values[0] = $new_value;
            }
        }
    }

    return @values;
}

=head2 _FilterUserCFValuesOnCreate

On create, user objects can have CFs set from LDAP or other sources.
Clear submitted user custom field form values on create if the custom field
already has a value set on create.

=cut

sub _FilterUserCFValuesOnCreate {
    my %args    = @_;
    my $ARGSRef = $args{'ARGSRef'};
    my $UserObj = $args{'UserObj'};

    my %custom_fields_to_mod = _ParseObjectCustomFieldArgs($ARGSRef);

    foreach my $cf ( keys %{ $custom_fields_to_mod{'RT::User'}{0} } ) {
        my $CustomFieldObj = RT::CustomField->new( $session{'CurrentUser'} );
        $CustomFieldObj->SetContextObject($UserObj);
        $CustomFieldObj->LoadById($cf);
        unless ( $CustomFieldObj->id ) {
            $RT::Logger->warning("Couldn't load custom field #$cf");
            next;
        }

        if ( $UserObj->FirstCustomFieldValue($CustomFieldObj->Id) ) {

            my ($ret, $grouping) = _ValidateConsistentCustomFieldValues($cf,
                    $custom_fields_to_mod{'RT::User'}{0}{$cf});
            my $user_cf_name = GetCustomFieldInputName( CustomField => $CustomFieldObj, Grouping => $grouping );

            delete $ARGSRef->{$user_cf_name} if exists $ARGSRef->{$user_cf_name};
            delete $ARGSRef->{$user_cf_name . "-Magic"} if exists $ARGSRef->{$user_cf_name . "-Magic"};
        }
    }

    return;
}

=head2 ProcessTicketWatchers ( TicketObj => $Ticket, ARGSRef => \%ARGS );

Returns an array of results messages.

=cut

sub ProcessTicketWatchers {
    my %args = (
        TicketObj => undef,
        ARGSRef   => undef,
        @_
    );
    my (@results);

    my $Ticket  = $args{'TicketObj'};
    my $ARGSRef = $args{'ARGSRef'};

    # Munge watchers

    foreach my $key ( keys %$ARGSRef ) {

        # Delete deletable watchers
        if ( $key =~ /^Ticket-DeleteWatcher-Type-(.*)-Principal-(\d+)$/ ) {
            my ( $code, $msg ) = $Ticket->DeleteWatcher(
                PrincipalId => $2,
                Type        => $1
            );
            push @results, $msg;
        }

        # Delete watchers in the simple style demanded by the bulk manipulator
        elsif ( $key =~ /^Delete(Requestor|Cc|AdminCc|RT::CustomRole-\d+)$/ ) {
            my ( $code, $msg ) = $Ticket->DeleteWatcher(
                Email => $ARGSRef->{$key},
                Type  => $1
            );
            push @results, $msg;
        }

        # Clear all watchers in the simple style demanded by the bulk manipulator
        elsif ( $key =~ /^Clear(Requestor|Cc|AdminCc|RT::CustomRole-\d+)$/ ) {
            my ( $role_group, $msg ) = $Ticket->RoleGroup($1);
            if ( $role_group ) {
                my $members = $role_group->MembersObj;
                while (my $group_member = $members->Next) {
                    # In case the member is deleted automatically by scrips,
                    # call HasMember to make sure the member still exists.
                    if ( $role_group->HasMember( $group_member->MemberId ) ) {
                        my ( $code, $msg ) = $Ticket->DeleteWatcher(
                            PrincipalId => $group_member->MemberId,
                            Type        => $1
                        );
                        push @results, $msg;
                    }
                }
            } else {
                RT::Logger->error("Could not load RoleGroup for $1");
                push @results, $msg;
            }
        }

        # Add new watchers by email address
        elsif ( ( $ARGSRef->{$key} || '' ) =~ /^(?:AdminCc|Cc|Requestor|RT::CustomRole-\d+)$/
            and $key =~ /^WatcherTypeEmail(\d*)$/ )
        {

            #They're in this order because otherwise $1 gets clobbered :/
            my ( $code, $msg ) = $Ticket->AddWatcher(
                Type  => $ARGSRef->{$key},
                Email => $ARGSRef->{ "WatcherAddressEmail" . $1 }
            );
            push @results, $msg;
        }

        #Add requestors in the simple style demanded by the bulk manipulator
        elsif ( $key =~ /^Add(Requestor|Cc|AdminCc|RT::CustomRole-\d+)$/ ) {
            my ( $code, $msg ) = $Ticket->AddWatcher(
                Type  => $1,
                Email => $ARGSRef->{$key}
            );
            push @results, $msg;
        }

        # Add new  watchers by owner
        elsif ( $key =~ /^Ticket-AddWatcher-Principal-(\d*)$/ ) {
            my $principal_id = $1;
            my $form         = $ARGSRef->{$key};
            foreach my $value ( ref($form) ? @{$form} : ($form) ) {
                next unless $value =~ /^(?:AdminCc|Cc|Requestor|RT::CustomRole-\d+)$/i;

                my ( $code, $msg ) = $Ticket->AddWatcher(
                    Type        => $value,
                    PrincipalId => $principal_id
                );
                push @results, $msg;
            }
        }
        # Single-user custom roles
        elsif ( $key =~ /^RT::CustomRole-(\d*)$/ ) {
            # clearing the field sets value to nobody
            my $user = $ARGSRef->{$key} || RT->Nobody;

            my ( $code, $msg ) = $Ticket->AddWatcher(
                Type => $key,
                User => $user,
            );
            push @results, $msg;
        }

    }
    return (@results);
}



=head2 ProcessTicketDates ( TicketObj => $Ticket, ARGSRef => \%ARGS );

Returns an array of results messages.

=cut

sub ProcessTicketDates {
    my %args = (
        TicketObj => undef,
        ARGSRef   => undef,
        @_
    );

    my $Ticket  = $args{'TicketObj'};
    my $ARGSRef = $args{'ARGSRef'};

    my (@results);

    # Set date fields
    my @date_fields = qw(
        Told
        Starts
        Started
        Due
    );

    #Run through each field in this list. update the value if apropriate
    foreach my $field (@date_fields) {
        next unless exists $ARGSRef->{ $field . '_Date' };
        my $obj = $field . "Obj";
        my $method = "Set$field";

        if ( $ARGSRef->{ $field . '_Date' } eq '' ) {
            if ( $Ticket->$obj->IsSet ) {
                my ( $code, $msg ) = $Ticket->$method( '1970-01-01 00:00:00' );
                push @results, $msg;
            }
        }
        else {

            my $DateObj = RT::Date->new( $session{'CurrentUser'} );
            $DateObj->Set(
                Format => 'unknown',
                Value  => $ARGSRef->{ $field . '_Date' }
            );

            if ( $DateObj->Unix != $Ticket->$obj()->Unix() )
            {
                my ( $code, $msg ) = $Ticket->$method( $DateObj->ISO );
                push @results, $msg;
            }
        }
    }

    # }}}
    return (@results);
}



=head2 ProcessTicketLinks ( TicketObj => $Ticket, ARGSRef => \%ARGS );

Returns an array of results messages.

=cut

sub ProcessTicketLinks {
    my %args = (
        TicketObj => undef,
        TicketId  => undef,
        ARGSRef   => undef,
        @_
    );

    my $Ticket  = $args{'TicketObj'};
    my $TicketId = $args{'TicketId'} || $Ticket->Id;
    my $ARGSRef = $args{'ARGSRef'};

    my (@results) = ProcessRecordLinks(
        %args, RecordObj => $Ticket, RecordId => $TicketId, ARGSRef => $ARGSRef,
    );

    #Merge if we need to
    my $input = $TicketId .'-MergeInto';
    if ( $ARGSRef->{ $input } ) {
        $ARGSRef->{ $input } =~ s/\s+//g;
        my ( $val, $msg ) = $Ticket->MergeInto( $ARGSRef->{ $input } );
        push @results, $msg;
    }

    return (@results);
}


sub ProcessRecordLinks {
    my %args = (
        RecordObj => undef,
        RecordId  => undef,
        ARGSRef   => undef,
        @_
    );

    my $Record  = $args{'RecordObj'};
    my $RecordId = $args{'RecordId'} || $Record->Id;
    my $ARGSRef = $args{'ARGSRef'};

    my (@results);

    # Delete links that are gone gone gone.
    foreach my $arg ( keys %$ARGSRef ) {
        if ( $arg =~ /DeleteLink-(.*?)-(DependsOn|MemberOf|RefersTo)-(.*)$/ ) {
            my $base   = $1;
            my $type   = $2;
            my $target = $3;

            my ( $val, $msg ) = $Record->DeleteLink(
                Base   => $base,
                Type   => $type,
                Target => $target
            );

            push @results, $msg;

        }

    }

    my @linktypes = qw( DependsOn MemberOf RefersTo );

    foreach my $linktype (@linktypes) {
        my $input = $RecordId .'-'. $linktype;
        if ( $ARGSRef->{ $input } ) {
            $ARGSRef->{ $input } = join( ' ', @{ $ARGSRef->{ $input } } )
                if ref $ARGSRef->{ $input };

            for my $luri ( split( / /, $ARGSRef->{ $input } ) ) {
                next unless $luri;
                $luri =~ s/\s+$//;    # Strip trailing whitespace
                my ( $val, $msg ) = $Record->AddLink(
                    Target => $luri,
                    Type   => $linktype
                );
                push @results, $msg;
            }
        }
        $input = $linktype .'-'. $RecordId;
        if ( $ARGSRef->{ $input } ) {
            $ARGSRef->{ $input } = join( ' ', @{ $ARGSRef->{ $input } } )
                if ref $ARGSRef->{ $input };

            for my $luri ( split( / /, $ARGSRef->{ $input } ) ) {
                next unless $luri;
                my ( $val, $msg ) = $Record->AddLink(
                    Base => $luri,
                    Type => $linktype
                );

                push @results, $msg;
            }
        }
    }

    return (@results);
}

=head2 ProcessLinksForCreate

Takes a hash with a single key, C<ARGSRef>, the value of which is a hashref to
C<%ARGS>.

Converts and returns submitted args in the form of C<new-LINKTYPE> and
C<LINKTYPE-new> into their appropriate directional link types.  For example,
C<new-DependsOn> becomes C<DependsOn> and C<DependsOn-new> becomes
C<DependedOnBy>.  The incoming arg values are split on whitespace and
normalized into arrayrefs before being returned.

Primarily used by object creation pages for transforming incoming form inputs
from F</Elements/EditLinks> into arguments appropriate for individual record
Create methods.

Returns a hashref in scalar context and a hash in list context.

=cut

sub ProcessLinksForCreate {
    my %args = @_;
    my %links;

    foreach my $type ( keys %RT::Link::DIRMAP ) {
        for ([Base => "new-$type"], [Target => "$type-new"]) {
            my ($direction, $key) = @$_;
            next unless $args{ARGSRef}->{$key};
            $links{ $RT::Link::DIRMAP{$type}->{$direction} } = [
                grep $_, split ' ', $args{ARGSRef}->{$key}
            ];
        }
    }
    return wantarray ? %links : \%links;
}

=head2 ProcessTransactionSquelching

Takes a hashref of the submitted form arguments, C<%ARGS>.

Returns a hash of squelched addresses.

=cut

sub ProcessTransactionSquelching {
    my $args    = shift;
    my %checked = map { $_ => 1 } grep { defined }
        (    ref $args->{'TxnSendMailTo'} eq "ARRAY"  ? @{$args->{'TxnSendMailTo'}} :
         defined $args->{'TxnSendMailTo'}             ?  ($args->{'TxnSendMailTo'}) :
                                                                             () );
    my %squelched = map { $_ => 1 } grep { not $checked{$_} } split /,/, ($args->{'TxnRecipients'}||'');
    return %squelched;
}

sub ProcessRecordBulkCustomFields {
    my %args = (RecordObj => undef, ARGSRef => {}, @_);

    my $ARGSRef = $args{'ARGSRef'};

    my %data;

    my @results;
    foreach my $key ( keys %$ARGSRef ) {
        next unless $key =~ /^Bulk-(Add|Delete)-CustomField-(\d+)-(.*)$/;
        my ($op, $cfid, $rest) = ($1, $2, $3);
        # ValuesType is for HTML cfs
        next if $rest =~ /(?:-Category|ValuesType)$/;

        my $res = $data{$cfid} ||= {};
        unless (keys %$res) {
            my $cf = RT::CustomField->new( $session{'CurrentUser'} );
            $cf->Load( $cfid );
            next unless $cf->Id;

            $res->{'cf'} = $cf;
        }

        if ( $op eq 'Delete' && $rest eq 'AllValues' ) {
            $res->{'DeleteAll'} = $ARGSRef->{$key};
            next;
        }

        my @values = _NormalizeObjectCustomFieldValue(
            CustomField => $res->{'cf'},
            Value => $ARGSRef->{$key},
            Param => $key,
        );
        next unless @values;
        $res->{$op} = \@values;
    }

    while ( my ($cfid, $data) = each %data ) {
        my $current_values = $args{'RecordObj'}->CustomFieldValues( $cfid );

        # just add one value for fields with single value
        if ( $data->{'Add'} && $data->{'cf'}->MaxValues == 1 ) {
            next if $current_values->HasEntry($data->{Add}[-1]);

            my ( $id, $msg ) = $args{'RecordObj'}->AddCustomFieldValue(
                Field => $cfid,
                Value => $data->{'Add'}[-1],
            );
            push @results, $msg;
            next;
        }

        if ( $data->{'DeleteAll'} ) {
            while ( my $value = $current_values->Next ) {
                my ( $id, $msg ) = $args{'RecordObj'}->DeleteCustomFieldValue(
                    Field   => $cfid,
                    ValueId => $value->id,
                );
                push @results, $msg;
            }
        }
        foreach my $value ( @{ $data->{'Delete'} || [] } ) {
            my $entry = $current_values->HasEntry($value);
            next unless $entry;

            my ( $id, $msg ) = $args{'RecordObj'}->DeleteCustomFieldValue(
                Field   => $cfid,
                ValueId => $entry->id,
            );
            push @results, $msg;
        }
        foreach my $value ( @{ $data->{'Add'} || [] } ) {
            next if $current_values->HasEntry($value);

            next if $args{'RecordObj'}->CustomFieldValueIsEmpty(
                Field => $cfid,
                Value => $value,
            );

            my ( $id, $msg ) = $args{'RecordObj'}->AddCustomFieldValue(
                Field => $cfid,
                Value => $value
            );
            push @results, $msg;
        }
    }
    return @results;
}

=head2 _UploadedFile ( $arg );

Takes a CGI parameter name; if a file is uploaded under that name,
return a hash reference suitable for AddCustomFieldValue's use:
C<( Value => $filename, LargeContent => $content, ContentType => $type )>.

Returns C<undef> if no files were uploaded in the C<$arg> field.

=cut

sub _UploadedFile {
    my $arg         = shift;
    my $cgi_object  = $m->cgi_object;
    my $fh          = $cgi_object->upload($arg) or return undef;
    my $upload_info = $cgi_object->uploadInfo($fh);

    my $filename = "$fh";
    $filename =~ s#^.*[\\/]##;
    binmode($fh);
    my $content = do { local $/; scalar <$fh>; };
    seek($fh, 0, 0);

    return {
        Value        => $filename,
        LargeContent => $content,
        ContentType  => $upload_info->{'Content-Type'},
    };
}

sub GetColumnMapEntry {
    my %args = ( Map => {}, Name => '', Attribute => undef, @_ );

    # deal with the simplest thing first
    if ( $args{'Map'}{ $args{'Name'} } ) {
        return $args{'Map'}{ $args{'Name'} }{ $args{'Attribute'} };
    }

    # complex things
    elsif ( my ( $mainkey, $subkey ) = $args{'Name'} =~ /^(.*?)\.(.+)$/ ) {
        $subkey =~ s/^\{(.*)\}/$1/ unless $mainkey eq 'CustomRole';
        return undef unless $args{'Map'}->{$mainkey};
        return $args{'Map'}{$mainkey}{ $args{'Attribute'} }
            unless ref $args{'Map'}{$mainkey}{ $args{'Attribute'} } eq 'CODE';

        return sub { $args{'Map'}{$mainkey}{ $args{'Attribute'} }->( @_, $subkey ) };
    }
    return undef;
}

sub ProcessColumnMapValue {
    my $value = shift;
    my %args = ( Arguments => [], Escape => 1, @_ );

    if ( ref $value ) {
        if ( UNIVERSAL::isa( $value, 'CODE' ) ) {
            my @tmp;
            eval { @tmp = $value->( @{ $args{'Arguments'} } ); };
            if ( $@ ) {
                # Looks like the object $value doesn't have the requested method
                return ProcessColumnMapValue( loc("Invalid column") );
            }
            return ProcessColumnMapValue( ( @tmp > 1 ? \@tmp : $tmp[0] ), %args );
        } elsif ( UNIVERSAL::isa( $value, 'ARRAY' ) ) {
            return join '', map ProcessColumnMapValue( $_, %args ), @$value;
        } elsif ( UNIVERSAL::isa( $value, 'SCALAR' ) ) {
            return $$value;
        }
    } else {
        if ($args{'Escape'}) {
            $value = $m->interp->apply_escapes( $value, 'h' );
            $value =~ s/\n/<br>/g if defined $value;
        }
        return $value;
    }
}

sub ProcessQuickCreate {
    my %params = @_;
    my %ARGS = %{ $params{ARGSRef} };
    my $path = $params{Path};
    my @results;

    if ( $ARGS{'QuickCreate'} && $path ) {
        # $path is no longer needed starting in RT 6 because we use htmx to process
        # without a page load. If $path is passed, it is from one of the legacy
        # locations.
        # In 6.2, remove the ProcessQuickCreate call from index.html and Render.html.
        RT->Deprecated( Message => 'Calling ProcessQuickCreate from index.html or Render.html is deprecated', Instead => '/Helpers/QuickCreate', Remove => '6.2' );
    }

    if ( $ARGS{'QuickCreate'} ) {
        my $QueueObj = RT::Queue->new($session{'CurrentUser'});
        $QueueObj->Load($ARGS{Queue}) or Abort(loc("Queue could not be loaded."));

        my $CFs = $QueueObj->TicketCustomFields;

        my ($ValidCFs, @msg) = $m->comp(
            '/Elements/ValidateCustomFields',
            CustomFields        => $CFs,
            ARGSRef             => \%ARGS,
            ValidateUnsubmitted => 1,
        );

        my $created;
        if ( $ValidCFs ) {
            my ($t, $msg) = CreateTicket( %ARGS );
            push @results, $msg;

            if ( $t && $t->Id ) {
                $created = 1;
                if ( RT->Config->Get('DisplayTicketAfterQuickCreate', $session{'CurrentUser'}) ) {
                    MaybeRedirectForResults(
                        Actions   => \@results,
                        Path      => '/Ticket/Display.html',
                        Arguments => { id => $t->Id },
                    );
                }
            }
        }
        else {
            push @results, loc("Can't quickly create ticket in queue [_1] because custom fields are required.  Please finish by using the normal ticket creation page.", $QueueObj->Name);
            push @results, @msg;

            MaybeRedirectForResults(
                Actions     => \@results,
                Path        => "/Ticket/Create.html",
                Arguments   => {
                    (map { $_ => $ARGS{$_} } qw(Queue Owner Status Content Subject)),
                    Requestors => $ARGS{Requestors},
                },
            );
        }

        # Stash submitted args so they can be re-displayed on the form and the user
        # can update to resolve the error.
        unless ( $created ) {
            RT::Interface::Web::Session::Set(
                Key   => 'QuickCreate',
                Value => \%ARGS,
            );
        }
    }

    return @results;
}

=head2 GetPrincipalsMap OBJECT, CATEGORIES

Returns an array suitable for passing to /Admin/Elements/EditRights with the
principal collections mapped from the categories given.

The return value is an array of arrays, where the inner arrays are like:

    [ 'Category name' => $CollectionObj => 'DisplayColumn' => 1 ]

The last value is a boolean determining if the value of DisplayColumn
should be loc()-ed before display.

=cut

sub GetPrincipalsMap {
    my $object = shift;
    my @map;
    for (@_) {
        if (/System/) {
            my $system = RT::Groups->new($session{'CurrentUser'});
            $system->LimitToSystemInternalGroups();
            $system->OrderBy( FIELD => 'Name', ORDER => 'ASC' );
            push @map, [
                'System' => $system,    # loc_left_pair
                'Name'   => 1,
            ];
        }
        elsif (/Groups/) {
            my $groups = RT::Groups->new($session{'CurrentUser'});
            $groups->LimitToUserDefinedGroups();
            $groups->OrderBy( FIELD => 'Name', ORDER => 'ASC' );

            # Only show groups who have rights granted on this object
            $groups->WithGroupRight(
                Right   => '',
                Object  => $object,
                IncludeSystemRights => 0,
                IncludeSubgroupMembers => 0,
            );

            push @map, [
                'User Groups' => $groups,   # loc_left_pair
                'Label'       => 0
            ];
        }
        elsif (/Roles/) {
            my $roles = RT::Groups->new($session{'CurrentUser'});

            if ($object->isa("RT::CustomField")) {
                # If we're a custom field, show the global roles for our LookupType.
                my $class = $object->RecordClassFromLookupType;
                if ($class and $class->DOES("RT::Record::Role::Roles")) {
                    $roles->LimitToRolesForObject(RT->System);
                    $roles->Limit(
                        FIELD         => "Name",
                        FUNCTION      => 'LOWER(?)',
                        OPERATOR      => "IN",
                        VALUE         => [ map {lc $_} $class->Roles ],
                        CASESENSITIVE => 1,
                    );
                } else {
                    # No roles to show; so show nothing
                    undef $roles;
                }
            } else {
                $roles->LimitToRolesForObject($object);
            }

            if ($roles) {
                $roles->OrderBy( FIELD => 'Name', ORDER => 'ASC' );
                push @map, [
                    'Roles' => $roles,  # loc_left_pair
                    'Label' => 0
                ];
            }
        }
        elsif (/Users/) {
            my $Users = RT->PrivilegedUsers->UserMembersObj();
            $Users->OrderBy( FIELD => 'Name', ORDER => 'ASC' );

            # Only show users who have rights granted on this object
            my $group_members = $Users->WhoHaveGroupRight(
                Right   => '',
                Object  => $object,
                IncludeSystemRights => 0,
                IncludeSubgroupMembers => 0,
            );

            # Limit to UserEquiv groups
            my $groups = $Users->Join(
                ALIAS1 => $group_members,
                FIELD1 => 'GroupId',
                TABLE2 => 'Groups',
                FIELD2 => 'id',
            );
            $Users->Limit( ALIAS => $groups, FIELD => 'Domain', VALUE => 'ACLEquivalence', CASESENSITIVE => 0 );
            $Users->Limit( ALIAS => $groups, FIELD => 'Name', VALUE => 'UserEquiv', CASESENSITIVE => 0 );

            push @map, [
                'Users' => $Users,  # loc_left_pair
                'Format' => 0
            ];
        }
    }
    return @map;
}

sub LoadCatalog {
    my $id = shift
        or Abort(loc("No catalog specified."));

    my $catalog = RT::Catalog->new( $session{CurrentUser} );
    $catalog->Load($id);

    Abort(loc("Unable to find catalog [_1]", $id))
        unless $catalog->id;

    Abort(loc("You don't have permission to view this catalog."))
        unless $catalog->CurrentUserCanSee;

    return $catalog;
}

sub LoadAsset {
    my $id = shift
        or Abort(loc("No asset ID specified."));

    my $asset = RT::Asset->new( $session{CurrentUser} );
    $asset->Load($id);

    Abort(loc("Unable to find asset #[_1]", $id))
        unless $asset->id;

    Abort(loc("You don't have permission to view this asset."))
        unless $asset->CurrentUserCanSee;

    return $asset;
}

sub ProcessAssetRoleMembers {
    my $object = shift;
    my %ARGS   = (@_);
    my @results;

    for my $arg (keys %ARGS) {
        if ($arg =~ /^Add(User|Group)RoleMember$/) {
            next unless $ARGS{$arg} and $ARGS{"$arg-Role"};

            my ($ok, $msg) = $object->AddRoleMember(
                Type => $ARGS{"$arg-Role"},
                $1   => $ARGS{$arg},
            );
            push @results, $msg;
        }
        elsif ($arg =~ /^SetRoleMember-(.+)$/) {
            my $role = $1;
            my $group = $object->RoleGroup($role);
            if ( !$group->id ) {
                $group = $object->_CreateRoleGroup($role);
            }
            next unless $group->id and $group->SingleMemberRoleGroup;
            my $original_user = $group->UserMembersObj->First || RT->Nobody;
            $ARGS{$arg} ||= 'Nobody';
            next if $ARGS{$arg} eq $original_user->Name;
            my ($ok, $msg) = $object->AddRoleMember(
                Type => $role,
                User => $ARGS{$arg},
            );
            push @results, $msg;
        }
        elsif ($arg =~ /^(Add|Remove)RoleMember-(.+)$/) {
            my $role = $2;
            my $method = $1 eq 'Add'? 'AddRoleMember' : 'DeleteRoleMember';

            my $is = 'User';
            if ( ($ARGS{"$arg-Type"}||'') =~ /^(User|Group)$/ ) {
                $is = $1;
            }

            my @members = ( ref( $ARGS{$arg} ) eq 'ARRAY' ) ? ( @{ $ARGS{$arg} } ) : ( $ARGS{$arg} );
            foreach my $member (@members) {
                my ( $ok, $msg ) = $object->$method(
                    Type => $role,
                    (   $member =~ /\D/
                        ? ( $is => $member )
                        : ( PrincipalId => $member )
                    ),
                );
                push @results, $msg;
            }
        }
        elsif ($arg =~ /^RemoveAllRoleMembers-(.+)$/) {
            my $role = $1;
            my $group = $object->RoleGroup($role);
            next unless $group->id;

            my $gms = $group->MembersObj;
            while ( my $gm = $gms->Next ) {
                my ($ok, $msg) = $object->DeleteRoleMember(
                    Type        => $role,
                    PrincipalId => $gm->MemberId,
                );
                push @results, $msg;
            }
        }
    }
    return @results;
}


# If provided a catalog, load it and return the object.
# If no catalog is passed, load the first active catalog.

sub LoadDefaultCatalog {
    my $catalog = shift;
    my $catalog_obj = RT::Catalog->new($session{CurrentUser});

    if ( $catalog ){
        $catalog_obj->Load($catalog);
        RT::Logger->error("Unable to load catalog: " . $catalog)
            unless $catalog_obj->Id;
    }
    elsif ( $session{'DefaultCatalog'} ){
        $catalog_obj->Load($session{'DefaultCatalog'});
        RT::Logger->error("Unable to load remembered catalog: " .
                          $session{'DefaultCatalog'})
            unless $catalog_obj->Id;
    }
    elsif ( RT->Config->Get("DefaultCatalog") ){
        $catalog_obj->Load( RT->Config->Get("DefaultCatalog") );
        RT::Logger->error("Unable to load default catalog: "
                          . RT->Config->Get("DefaultCatalog"))
            unless $catalog_obj->Id;
    }
    else {
        # If no catalog, default to the first active catalog
        my $catalogs = RT::Catalogs->new($session{CurrentUser});
        $catalogs->UnLimit;
        my $candidate = $catalogs->First;
        $catalog_obj = $candidate if $candidate;
        RT::Logger->error("No active catalogs.")
            unless $catalog_obj and $catalog_obj->Id;
    }

    return $catalog_obj;
}

sub ProcessAssetsSearchArguments {
    my %args = (
        Catalog => undef,
        Assets => undef,
        ARGSRef => undef,
        @_
    );
    my $ARGSRef = $args{'ARGSRef'};

    my @PassArguments;

    if ($ARGSRef->{q}) {
        if ($ARGSRef->{q} =~ /^\d+$/) {
            my $asset = RT::Asset->new( $session{CurrentUser} );
            $asset->Load( $ARGSRef->{q} );
            RT::Interface::Web::Redirect(
                RT->Config->Get('WebURL')."Asset/Display.html?id=".$ARGSRef->{q}
            ) if $asset->id;
        }
        $args{'Assets'}->SimpleSearch( Term => $ARGSRef->{q}, Catalog => $args{Catalog} );
        push @PassArguments, "q";
    } elsif ( $ARGSRef->{'SearchAssets'} ){
        for my $key (keys %$ARGSRef) {
            my $value = ref $ARGSRef->{$key} ? $ARGSRef->{$key}[0] : $ARGSRef->{$key};
            next unless defined $value and length $value;

            my $orig_key = $key;
            my $negative = ($key =~ s/^!// ? 1 : 0);
            if ($key =~ /^(Name|Description)$/) {
                $args{'Assets'}->Limit(
                    FIELD => $key,
                    OPERATOR => ($negative ? 'NOT LIKE' : 'LIKE'),
                    VALUE => $value,
                    ENTRYAGGREGATOR => "AND",
                );
            } elsif ($key eq 'Catalog') {
                $args{'Assets'}->LimitCatalog(
                    OPERATOR => ($negative ? '!=' : '='),
                    VALUE => $value,
                    ENTRYAGGREGATOR => "AND",
                );
            } elsif ($key eq 'Status') {
                $args{'Assets'}->Limit(
                    FIELD => $key,
                    OPERATOR => ($negative ? '!=' : '='),
                    VALUE => $value,
                    ENTRYAGGREGATOR => "AND",
                );
            } elsif ($key =~ /^Role\.(.+)/) {
                my $role = $1;
                $args{'Assets'}->RoleLimit(
                    TYPE      => $role,
                    FIELD     => $_,
                    OPERATOR  => ($negative ? '!=' : '='),
                    VALUE     => $value,
                    SUBCLAUSE => $role,
                    ENTRYAGGREGATOR => ($negative ? "AND" : "OR"),
                    CASESENSITIVE   => 0,
                ) for qw/EmailAddress Name/;
            } elsif ($key =~ /^CF\.\{(.+?)\}$/ or $key =~ /^CF\.(.*)/) {
                my $cf = RT::Asset->new( $session{CurrentUser} )
                  ->LoadCustomFieldByIdentifier( $1 );
                next unless $cf->id;
                if ( $value eq 'NULL' ) {
                    $args{'Assets'}->LimitCustomField(
                        CUSTOMFIELD => $cf->Id,
                        OPERATOR    => ($negative ? "IS NOT" : "IS"),
                        VALUE       => 'NULL',
                        QUOTEVALUE  => 0,
                        ENTRYAGGREGATOR => "AND",
                    );
                } else {
                    $args{'Assets'}->LimitCustomField(
                        CUSTOMFIELD => $cf->Id,
                        OPERATOR    => ($negative ? "NOT LIKE" : "LIKE"),
                        VALUE       => $value,
                        ENTRYAGGREGATOR => "AND",
                    );
                }
            }
            else {
                next;
            }
            push @PassArguments, $orig_key;
        }
        push @PassArguments, 'SearchAssets';
    }

    if ( !$ARGSRef->{Format} ) {
        my $Format = RT->Config->Get('AssetSimpleSearchFormat');
        $Format = $Format->{$args{'Catalog'}->id}
            || $Format->{$args{'Catalog'}->Name}
            || $Format->{''} if ref $Format;
        $ARGSRef->{Format} = $Format || q[
            '<b><a href="__WebPath__/Asset/Display.html?id=__id__">__id__</a></b>/TITLE:#',
            '<b><a href="__WebPath__/Asset/Display.html?id=__id__">__Name__</a></b>/TITLE:Name',
            Description,
            Status,
        ];
    }

    $ARGSRef->{OrderBy} ||= 'id';

    push @PassArguments, qw/OrderBy Order Page Format/;

    return (
        OrderBy         => 'id',
        Order           => 'ASC',
        Rows            => 50,
        (map { $_ => $ARGSRef->{$_} } grep { defined $ARGSRef->{$_} } @PassArguments),
        PassArguments   => \@PassArguments,
    );
}

=head3 SetObjectSessionCache

Convenience method to stash per-user query results in the user session. This is used
for rights-intensive queries that change infrequently, such as generating the list of
queues a user has access to.

The method handles populating the session cache and clearing it based on CacheNeedsUpdate.
It returns the cache key so callers can use $session directly after it has been created
or updated.

Parameters:

=over

=item * ObjectType, required, the object for which to fetch values

=item * CheckRight, the right to check for the current user in the query

=item * ShowAll, boolean, ignores the rights check

=item * Default, for dropdowns, a default selected value

=item * CacheNeedsUpdate, date indicating when an update happened requiring a cache clear

=item * Exclude, hashref ({ Name => 1 }) of object Names to exclude from the cache

=back

=cut

sub SetObjectSessionCache {
    my %args = (
        CheckRight => undef,
        ShowAll => 1,
        Default => 0,
        CacheNeedsUpdate => undef,
        Exclude => undef,
        @_ );

    my $ObjectType = $args{'ObjectType'};
    $ObjectType = "RT::$ObjectType" unless $ObjectType =~ /::/;
    my $CheckRight = $args{'CheckRight'};
    my $ShowAll = $args{'ShowAll'};
    my $CacheNeedsUpdate = $args{'CacheNeedsUpdate'};

    my $cache_key = GetObjectSessionCacheKey( ObjectType => $ObjectType,
        CheckRight => $CheckRight, ShowAll => $ShowAll );

    if ( defined $session{$cache_key} && !$session{$cache_key}{id} ) {
        RT::Interface::Web::Session::Delete(
            Key => $cache_key,
        );
    }

    if ( defined $session{$cache_key}
         && ref $session{$cache_key} eq 'ARRAY') {
         RT::Interface::Web::Session::Delete(
             Key => $cache_key,
         );
    }
    if ( defined $session{$cache_key} && defined $CacheNeedsUpdate &&
        $session{$cache_key}{lastupdated} <= $CacheNeedsUpdate ) {
        RT::Interface::Web::Session::Delete(
            Key => $cache_key,
        );
    }

    if ( not defined $session{$cache_key} ) {
        my $collection = "${ObjectType}s"->new($session{'CurrentUser'});
        $collection->UnLimit;

        $HTML::Mason::Commands::m->callback( CallbackName => 'ModifyCollection',
            CallbackPage => '/Elements/Quicksearch',
            ARGSRef => \%args, Collection => $collection, ObjectType => $ObjectType );

        RT::Interface::Web::Session::Delete(
            Key => $cache_key,
        );

        my %ids;
        while (my $object = $collection->Next) {
            if ($ShowAll
                or not $CheckRight
                or $session{CurrentUser}->HasRight( Object => $object, Right => $CheckRight ))
            {
                next if $args{'Exclude'} and exists $args{'Exclude'}->{$object->Name};
                push @{$ids{objects}}, {
                    Id          => $object->Id,
                    Name        => $object->Name,
                    Description => $object->_Accessible("Description" => "read") ? $object->Description : undef,
                    Lifecycle   => $object->_Accessible("Lifecycle" => "read") ? $object->Lifecycle : undef,
                };
                $ids{id}{ $object->id } = 1;
            }
        }

        $ids{'lastupdated'} = time();

        RT::Interface::Web::Session::Set(
            Key   => $cache_key,
            Value => \%ids,
        );

    }

    return $cache_key;
}

sub GetObjectSessionCacheKey {
    my %args = (
        CurrentUser => undef,
        ObjectType => '',
        CheckRight => '',
        ShowAll => 1,
        @_ );

    my $cache_key = join "---", "SelectObject",
        $args{'ObjectType'},
        $session{'CurrentUser'}->Id,
        $args{'CheckRight'},
        $args{'ShowAll'};

    return $cache_key;
}

=head2 _load_container_object ( $type, $id );

Instantiate container object for saving searches.

=cut

sub _load_container_object {
    my ( $obj_type, $obj_id ) = @_;
    return RT::SavedSearch->new( $session{'CurrentUser'} )->_load_privacy_object( $obj_type, $obj_id );
}

=head2 _parse_saved_search ( $arg );

Given a serialization string for saved search, and returns the
container object and the search id.

=cut

sub _parse_saved_search {
    my $spec = shift;
    return unless $spec;
    if ( $spec !~ /^(.*?)-(\d+)-SavedSearch-(\d+)$/ ) {
        return;
    }
    my $obj_type  = $1;
    my $obj_id    = $2;
    my $search_id = $3;

    return ( _load_container_object( $obj_type, $obj_id ), $search_id );
}

=head2 ScrubHTML Content => CONTENT, Permissive => 1|0, SkipStructureCheck => 1|0

Removes unsafe and undesired HTML from the passed content

=cut

# The scrubber loads its rules in the constructor and some RT
# config options can change the rules. If config is changed,
# this flag tells us to reload the state-ful scrubber.

our $ReloadScrubber;

sub ScrubHTML {
    my %args = @_ % 2 ? ( Content => @_ ) : @_;

    state $scrubber = RT::Interface::Web::Scrubber->new;
    state $permissive_scrubber = RT::Interface::Web::Scrubber::Permissive->new;

    if ( $HTML::Mason::Commands::ReloadScrubber ) {
        $scrubber = RT::Interface::Web::Scrubber->new;
        $permissive_scrubber = RT::Interface::Web::Scrubber::Permissive->new;
        $HTML::Mason::Commands::ReloadScrubber = 0;
    }

    return ( $args{Permissive} ? $permissive_scrubber : $scrubber )->scrub( $args{Content}, $args{SkipStructureCheck} );
}

=head2 JSON

Redispatches to L<RT::Interface::Web/EncodeJSON>

=cut

sub JSON {
    RT::Interface::Web::EncodeJSON(@_);
}

sub CSSClass {
    my $value = shift;
    return '' unless defined $value;
    $value =~ s/[^A-Za-z0-9_-]/_/g;
    return $value;
}

sub GetCustomFieldInputName {
    RT::Interface::Web::GetCustomFieldInputName(@_);
}

sub GetCustomFieldInputNamePrefix {
    RT::Interface::Web::GetCustomFieldInputNamePrefix(@_);
}

=head2  LoadTransaction id

Takes a transaction id as its only variable. if it's handed an array, it takes
the first value.

Returns an RT::Transaction object as the current user.

=cut

sub LoadTransaction {
    my $id = shift;

    if ( ref($id) eq "ARRAY" ) {
        $id = $id->[0];
    }

    unless ($id) {
        Abort( loc('No transaction specified'), Code => HTTP::Status::HTTP_BAD_REQUEST );
    }

    my $Transaction = RT::Transaction->new( $session{'CurrentUser'} );
    $Transaction->Load($id);
    unless ( $Transaction->id ) {
        Abort( loc( 'Could not load transaction #[_1]', $id ), Code => HTTP::Status::HTTP_NOT_FOUND );
    }
    return $Transaction;
}

=head2 GetDefaultQueue( IncludeFirst => 1 )

Processes global and user-level configuration options to find the default
queue for the current user.

Optionally pass IncludeFirst to pass the first available queue if
no default is found based on configuration.

Returns the ID of the default queue, if found, or undef.

=cut

sub GetDefaultQueue {
    my $queue;
    my %args = (
        IncludeFirst => 0,
        @_ );

    # RememberDefaultQueue tracks the last queue used by this user, if set.
    if ( $session{'DefaultQueue'} && RT->Config->Get( "RememberDefaultQueue", $session{'CurrentUser'} ) ) {
        $queue = $session{'DefaultQueue'};
    }
    else {
        $queue = RT->Config->Get( "DefaultQueue", $session{'CurrentUser'} );
    }

    # Confirm the user can see and load the default queue
    my $queue_obj = RT::Queue->new( $session{'CurrentUser'} );
    $queue_obj->Load($queue);

    # Need to check Name here rather than Id to confirm SeeQueue rights.
    # This aligns with the evaluation in the final return line.
    unless ( $queue_obj && $queue_obj->Name ) {
        if ( $args{'IncludeFirst'} ) {
            # pick first in list in normal order unless queue provided from form/url/defaults
            my $cache_key = SetObjectSessionCache(
                ObjectType       => 'Queue',
                CheckRight       => 'CreateTicket',
                CacheNeedsUpdate => RT->System->QueueCacheNeedsUpdate,
                ShowAll          => 0,
            );

            my $first_queue = $session{$cache_key}{objects}[0]->{Id} if $session{$cache_key}{objects}[0];
            $queue_obj->Load($first_queue);
        }
    }

    return defined $queue_obj->Name ? $queue_obj->Id : undef;
}

=head2 UpdateDashboard

Update global and user-level dashboard preferences.

For arguments, takes submitted args from the page and a hashref of available
items.

Gets additional information for submitted items from the hashref of
available items, since the args can't contain all information about the
item.

=cut

sub UpdateDashboard {
    my $args            = shift;
    my $available_items = shift;

    my $id = $args->{dashboard_id};

    my $data = {
        "dashboard_id" => $id,
        "panes"        => {
            "body"    => [],
            "sidebar" => []
        },
        "width" => {
            body    => $args->{body_width},
            sidebar => $args->{sidebar_width},
        },
    };

    foreach my $arg (qw{ body sidebar }) {
        my $pane   = $arg;
        my $values = $args->{$pane};

        next unless $values;

        # force value to an arrayref so we can handle both single and multiple members of each pane.
        $values = [$values] unless ref $values;

        foreach my $value ( @{$values} ) {
            $value =~ m/^(\w+)-(.+)$/i;
            my $type = $1;
            my $name = $2;
            push @{ $data->{panes}->{$pane} }, { type => $type, name => $name };
        }
    }

    my ( $ok, $msg );
    my $class = $args->{self_service_dashboard} ? 'RT::Dashboard::SelfService' : 'RT::Dashboard';
    my $Dashboard = $class->new( $session{'CurrentUser'} );
    ( $ok, $msg ) = $Dashboard->LoadById($id);

    # report error at the bottom
    return ( $ok, $msg ) unless $ok && $Dashboard->Id;

    my $content;
    for my $pane_name ( keys %{ $data->{panes} } ) {
        my @pane;

        for my $item ( @{ $data->{panes}{$pane_name} } ) {
            my %saved;
            $saved{pane}         = $pane_name;
            $saved{portlet_type} = $item->{type};

            $saved{description} = $available_items->{ $item->{type} }{ $item->{name} }{label};

            if ( $item->{type} eq 'component' ) {
                $saved{component} = $item->{name};

                # Absolute paths stay absolute, relative paths go into
                # /Elements. This way, extensions that add portlets work.
                my $path = $item->{name};
                $path = "/Elements/$path" if substr( $path, 0, 1 ) ne '/';

                $saved{path} = $path;
            } elsif ( $item->{type} eq 'saved' ) {
                $saved{portlet_type} = 'search';

                $item->{searchType} = $available_items->{ $item->{type} }{ $item->{name} }{search_type}
                                      if exists $available_items->{ $item->{type} }{ $item->{name} }{search_type};

                my $type = $item->{searchType};
                $type = 'Saved Search' if !$type || $type eq 'Ticket';
                $saved{description} = loc($type) . ': ' . $saved{description};

                $item->{searchId} = $available_items->{ $item->{type} }{ $item->{name} }{search_id}
                                    if exists $available_items->{ $item->{type} }{ $item->{name} }{search_id};

                my ( $obj_type, $obj_id, undef, $search_id ) = split '-', $item->{name};
                $saved{privacy} = "$obj_type-$obj_id";
                $saved{id}      = $search_id;
            } elsif ( $item->{type} eq 'dashboard' ) {
                my ( undef, $dashboard_id, $obj_type, $obj_id ) = split '-', $item->{name};
                $saved{privacy}     = "$obj_type-$obj_id";
                $saved{id}          = $dashboard_id;
                $saved{description} = loc('Dashboard') . ': ' . $saved{description};
            }

            push @pane, \%saved;
        }

        $content->{$pane_name} = \@pane;
    }

    return ( $ok, $msg ) = $Dashboard->Update( Panes => $content, Width => $data->{ width } );
}

=head2 ListOfReports

Returns the list of reports registered with RT. Alias for
L<RT::Interface::Web::ReportsRegistry|Reports>.

=cut

sub ListOfReports {
    return RT::Interface::Web::ReportsRegistry->Reports();
}

=head2 ProcessCustomDateRanges ARGSRef => ARGSREF, UserPreference => 0|1

For system database configuration, it adds corresponding arguments to the
passed ARGSRef, and the following code on EditConfig.html page will do the
real update job.

For user preference, it updates attributes accordingly.

Returns an array of results messages.

=cut

sub ProcessCustomDateRanges {
    my %args = (
        ARGSRef        => undef,
        UserPreference => 0,
        @_
    );
    my $args_ref = $args{ARGSRef};

    my ( $config, $content );
    if ( $args{UserPreference} ) {
        $config = { 'RT::Ticket' => { RT::Ticket->CustomDateRanges( ExcludeUser => $session{CurrentUser}->Id ) } };
        $content = $session{CurrentUser}->Preferences('CustomDateRanges');

        # SetPreferences also checks rights, we short-circuit to avoid
        # returning misleading messages.

        return ( 0, loc("No permission to set preferences") )
            unless $session{CurrentUser}->CurrentUserCanModify('Preferences');
    }
    else {
        $config = RT->Config->Get('CustomDateRanges');
        my $db_config = RT::Configuration->new( $session{CurrentUser} );
        $db_config->LoadByCols( Name => 'CustomDateRangesUI', Disabled => 0 );
        $content = $db_config->_DeserializeContent( $db_config->Content ) if $db_config->id;
    }

    my @results;
    my %label = (
        from          => 'From',                   # loc
        to            => 'To',                     # loc
        from_fallback => 'From Value if Unset',    # loc
        to_fallback   => 'To Value if Unset',      # loc
    );

    my $need_save;
    if ($content) {
        my @current_names = sort keys %{ $content->{'RT::Ticket'} };
        for my $id ( 0 .. $#current_names ) {
            my $current_name = $current_names[$id];
            my $spec         = $content->{'RT::Ticket'}{$current_name};
            my $name         = $args_ref->{"$id-name"};

            if ( $args_ref->{"$id-Delete"} ) {
                delete $content->{'RT::Ticket'}{$current_name};
                push @results, loc( 'Deleted [_1]', $current_name );
                $need_save ||= 1;
                next;
            }

            if ( $config && $config->{'RT::Ticket'}{$name} ) {
                push @results, loc( "[_1] already exists", $name );
                next;
            }

            my $updated;
            for my $field (qw/from from_fallback to to_fallback/) {
                next if ( $spec->{$field} // '' ) eq $args_ref->{"$id-$field"};
                if ((   $args_ref->{"$id-$field"}
                        && RT::Ticket->_ParseCustomDateRangeSpec( $name, join ' - ', 'now', $args_ref->{"$id-$field"} )
                    )
                    || ( !$args_ref->{"$id-$field"} && $field =~ /fallback/ )
                   )
                {
                    $spec->{$field} = $args_ref->{"$id-$field"};
                    $updated ||= 1;
                }
                else {
                    push @results, loc( 'Invalid [_1] for [_2]', loc( $label{$field} ), $name );
                    next;
                }
            }

            if ( $spec->{business_time} ne $args_ref->{"$id-business_time"} ) {
                $spec->{business_time} = $args_ref->{"$id-business_time"};
                $updated ||= 1;
            }

            $content->{'RT::Ticket'}{$name} = $spec;
            if ( $name ne $current_name ) {
                delete $content->{'RT::Ticket'}{$current_name};
                $updated ||= 1;
            }

            if ($updated) {
                push @results, loc( 'Updated [_1]', $name );
                $need_save ||= 1;
            }
        }
    }

    if ( $args_ref->{name} ) {
        for my $field (qw/from from_fallback to to_fallback business_time/) {
            $args_ref->{$field} = [ $args_ref->{$field} ] unless ref $args_ref->{$field};
        }

        my $i = 0;
        for my $name ( @{ $args_ref->{name} } ) {
            if ($name) {
                if ( $config && $config->{'RT::Ticket'}{$name} || $content && $content->{'RT::Ticket'}{$name} ) {
                    push @results, loc( "[_1] already exists", $name );
                    $i++;
                    next;
                }
            }
            else {
                $i++;
                next;
            }

            my $spec = { business_time => $args_ref->{business_time}[$i] };
            for my $field (qw/from from_fallback to to_fallback/) {
                if ((   $args_ref->{$field}[$i]
                        && RT::Ticket->_ParseCustomDateRangeSpec( $name, join ' - ', 'now', $args_ref->{$field}[$i] )
                    )
                    || ( !$args_ref->{$field}[$i] && $field =~ /fallback/ )
                   )
                {
                    $spec->{$field} = $args_ref->{$field}[$i];
                }
                else {
                    push @results, loc( 'Invalid [_1] for [_2]', loc($field), $name );
                    $i++;
                    next;
                }
            }

            $content->{'RT::Ticket'}{$name} = $spec;
            push @results, loc( 'Created [_1]', $name );
            $need_save ||= 1;
            $i++;
        }
    }

    if ($need_save) {
        if ( $args{UserPreference} ) {
            my ( $ret, $msg );
            if ( keys %{$content->{'RT::Ticket'}} ) {
                ( $ret, $msg ) = $session{CurrentUser}->SetPreferences( 'CustomDateRanges', $content );
            }
            else {
                ( $ret, $msg ) = $session{CurrentUser}->DeletePreferences( 'CustomDateRanges' );
            }

            unless ($ret) {
                RT->Logger->error($msg);
                push @results, $msg;
            }
        }
        else {
            $args_ref->{'CustomDateRangesUI-Current'} = ''; # EditConfig.html needs this to update CustomDateRangesUI
            $args_ref->{CustomDateRangesUI} = $content;
        }
    }
    return @results;
}

=head2 ProcessAuthToken ARGSRef => ARGSREF

Returns an array of results messages.

=cut

sub ProcessAuthToken {
    my %args = (
        ARGSRef => undef,
        @_
    );
    my $args_ref = $args{ARGSRef};

    my @results;
    my $token = RT::AuthToken->new( $session{CurrentUser} );

    if ( $args_ref->{Create} ) {

        # Don't require password for systems with some form of federated auth
        # or if configured to not require a password
        my %res = $session{'CurrentUser'}->CurrentUserRequireToSetPassword();
        my $require_password = 1;
        if ( RT->Config->Get('DisablePasswordForAuthToken') or not $res{'CanSet'}) {
            $require_password = 0;
        }

        if ( !length( $args_ref->{Description} ) ) {
            push @results, loc("Description cannot be blank.");
        }
        elsif ( $require_password && !length( $args_ref->{Password} ) ) {
            push @results, loc("Please enter your current password.");
        }
        elsif ( $require_password && !$session{CurrentUser}->IsPassword( $args_ref->{Password} ) ) {
            push @results, loc("Please enter your current password correctly.");
        }
        else {
            my $expires;
            if ( defined $args_ref->{'Expires'} and $args_ref->{'Expires'} =~ /\S/ ) {
                $expires = RT::Date->new( $session{CurrentUser} );
                $expires->Set( Format => 'unknown', Value => $args_ref->{'Expires'} );
            }
            my ( $ok, $msg, $auth_string ) = $token->Create(
                Owner       => $args_ref->{Owner},
                Description => $args_ref->{Description},
                $expires ? ( Expires => $expires->ISO ) : (),
            );
            if ($ok) {
                push @results, $msg;
                push @results,
                    loc(
                        '"[_1]" is your new authentication token. Treat it carefully like a password. Please save it now because you cannot access it again.',
                        $auth_string
                    );
            }
            else {
                push @results, loc('Unable to create a new authentication token. Contact your RT administrator.');
                RT->Logger->error('Unable to create authentication token: ' . $msg);
            }
        }
    }
    elsif ( $args_ref->{Update} || $args_ref->{Revoke} ) {

        $token->Load( $args_ref->{Token} );
        if ( $token->Id ) {
            if ( $args_ref->{Update} ) {
                if ( length( $args_ref->{Description} ) ) {
                    if ( $args_ref->{Description} ne $token->Description ) {
                        my ( $ok, $msg ) = $token->SetDescription( $args_ref->{Description} );
                        push @results, $msg;
                    }
                }
                else {
                    push @results, loc("Description cannot be blank.");
                }
            }
            elsif ( $args_ref->{Revoke} ) {
                my ( $ok, $msg ) = $token->Delete;
                push @results, $msg;
            }
        }
        else {
            push @results, loc("Could not find token: [_1]", $args_ref->{Token});
        }
    }
    return @results;
}

=head3 CachedCustomFieldValues FIELD

Similar to FIELD->Values, but caches the return value of FIELD->Values
in $m->notes in anticipation of it being used again.

=cut

sub CachedCustomFieldValues {
    my $cf = shift;

    my $key = 'CF-' . $cf->Id . '-Values';

    if ($m->notes($key)) {
        # Reset the iterator so we always start from the beginning
        $m->notes($key)->GotoFirstItem;
        return $m->notes($key);
    }

    # Wasn't in the cache; grab it and cache it.
    $m->notes($key, $cf->Values);
    return $m->notes($key);
}

sub PreprocessTimeUpdates {
    RT::Interface::Web::PreprocessTimeUpdates(@_);
}


=head2 GetDashboards Objects => ARRAY, CurrentUser => CURRENT_USER

Return available dashboards that are saved in the name of objects for
specified user.

=cut

sub GetDashboards {
    my %args = (
        Objects     => undef,
        CurrentUser => $session{CurrentUser},
        DefaultAttribute => 'DefaultDashboard',
        @_,
    );

    return unless $args{CurrentUser};

    $args{Objects} ||= [ RT::Dashboard->new( $args{CurrentUser} )->ObjectsForLoading( IncludeSuperuserGroups => 1 ) ];

    my ($system_default) = RT::System->new( $args{'CurrentUser'} )->Attributes->Named( $args{DefaultAttribute} );
    my $default_dashboard_id = $system_default ? $system_default->Content : 0;

    my $found_system_default;

    require RT::Dashboards;
    my %dashboards;
    my %system_default;
    foreach my $object ( @{ $args{Objects} } ) {
        my $list = RT::Dashboards->new( $args{CurrentUser} );
        $list->LimitToPrivacy( join( '-', ref($object), $object->Id ) );
        my $section;
        if ( ref $object eq 'RT::User' && $object->Id == $session{CurrentUser}->Id ) {
            $section = loc("My dashboards");
        }
        else {
            $section = loc( "[_1]'s dashboards", $object->Name );
        }

        while ( my $dashboard = $list->Next ) {
            # Use current logged in user to determine if to return link or not
            $dashboard->CurrentUser( $session{CurrentUser} );
            push @{ $dashboards{$section} },
                {   id        => $dashboard->Id,
                    name      => $dashboard->Name,
                    view_link => $dashboard->CurrentUserCanSee()
                    ? join( '/', RT->Config->Get('WebPath'), 'Dashboards', $dashboard->Id, $dashboard->Name )
                    : '',
                    edit_link => $dashboard->CurrentUserCanModify()
                    ? join( '/', RT->Config->Get('WebPath'), 'Dashboards', 'Queries.html?id=' . $dashboard->Id )
                    : '',
                };

            if ( $dashboard->Id == $default_dashboard_id ) {
                %system_default = ( section => $section, %{ $dashboards{$section}[-1] } );
            }
        }
    }

    if (%system_default) {
        push @{ $dashboards{ $system_default{section} } },
            {   id        => 0,
                name      => loc('System Default') . " ($system_default{name})",
                view_link => $system_default{view_link},
                edit_link => $system_default{edit_link},
            };
    }
    else {
        push @{$dashboards{"System's dashboards"}}, {
            id   => 0,
            name => loc('System Default'),
        };
    }

    for my $section ( keys %dashboards ) {
        @{ $dashboards{$section} } = sort { lc $a->{name} cmp lc $b->{name} } @{ $dashboards{$section} };
    }
    return \%dashboards;
}

=head2 BuildSearchResultPagination

Accepts a Data::Page object loaded with information about a set of
search results.

Returns an array with the pages from that set to include when displaying
pagination for those search results. This array can then be used to
generate the desired links and other UI.

=cut

sub BuildSearchResultPagination {
    my $pager = shift;
    my @pages;

    # For 10 or less, show all pages in a line, no breaks
    if ( $pager->last_page < 11 ) {
        push @pages, 1 .. $pager->last_page;
    }
    else {
        # For more pages, need to insert ellipsis for breaks
        # This creates 1 2 3...10 11 12...51 52 53
        @pages = ( 1, 2, 3 );

        if ( $pager->current_page() == 3 ) {
            # When on page 3, show 4 so you can keep going
            push @pages, ( 4 );
        }
        elsif ( $pager->current_page() == 4 ) {
            # Handle 4 and 5 without ellipsis
            push @pages, ( 4, 5 );
        }
        elsif ( $pager->current_page() == 5 ) {
            # Handle 4 and 5 without ellipsis
            push @pages, ( 4, 5, 6 );
        }
        elsif ( $pager->current_page() > 5 && $pager->current_page() < ($pager->last_page - 4) ) {
            push @pages, ( 'ellipsis',
            $pager->current_page() - 1, $pager->current_page(), $pager->current_page() + 1 );
        }

        push @pages, 'ellipsis';

        # Add padding at the end, the reverse of the above
        if ( $pager->current_page() == ($pager->last_page - 2) ) {
            push @pages, $pager->last_page - 3;
        }

        if ( $pager->current_page() == ($pager->last_page - 3) ) {
            push @pages, ( $pager->last_page - 4, $pager->last_page - 3 );
        }

        if ( $pager->current_page() == ($pager->last_page - 4) ) {
            push @pages, ( $pager->last_page - 5, $pager->last_page - 4, $pager->last_page - 3 );
        }

        # Add the end of the list
        push @pages, ( $pager->last_page - 2, $pager->last_page - 1, $pager->last_page );
    }

    return @pages;
}

=head2 GetStylesheet CurrentUser => CURRENT_USER

Return config L<RT_Config/$WebDefaultStylesheet> for specified user.

=cut

sub GetStylesheet {
    my %args = (
        CurrentUser => $session{CurrentUser},
        @_,
    );
    return $session{WebDefaultStylesheet} if $session{WebDefaultStylesheet};
    return $args{'CurrentUser'} ? $args{'CurrentUser'}->Stylesheet : RT->Config->Get('WebDefaultStylesheet');
}

sub QueryString {
    my %args = @_;
    my $u    = URI->new();
    $u->query_form(map { $_ => $args{$_} } sort keys %args);
    return $u->query;
}

sub ShortenSearchQuery {
    return @_ unless RT->Config->Get( 'EnableURLShortener', $session{CurrentUser} );
    my %query_args = @_;

    # Clean up
    delete $query_args{Page} unless ( $query_args{Page} || 1 ) > 1;
    for my $param (qw/SavedSearchId SavedChartSearchId/) {
        delete $query_args{$param} unless ( $query_args{$param} || 'new' ) ne 'new';
    }

    my $fallback;
    if ( my $sc = $HTML::Mason::Commands::DECODED_ARGS->{sc} ) {
        my $shortener = RT::Shortener->new( $session{CurrentUser} );
        $shortener->LoadByCode($sc);
        if ( $shortener->Id ) {
            $fallback = $shortener->DecodedContent;
        }
        else {
            RT->Logger->warning("Couldn't load shortener $sc");
        }
    }

    my %short_args;
    my %supported = map { $_ => 1 } @SHORTENER_SEARCH_FIELDS, @SHORTENER_CHART_FIELDS;

    # Sort to make sure BaseQuery is always processed before Query: we compare
    # them in the loop and unset BaseQuery if it's equal to Query.
    for my $field ( sort keys %supported ) {
        my $value;
        if ( exists $query_args{$field} ) {
            $value = delete $query_args{$field};
        }
        elsif ( $field eq 'RowsPerPage' && exists $query_args{Rows} ) {
            # Pages like search results support Rows too
            $value = delete $query_args{Rows};
        }
        else {
            $value = $fallback->{$field};
        }

        next unless defined $value;

        if ( $field eq 'ResultPage' && $value eq RT->Config->Get('WebPath') . '/Search/Results.html' ) {
            undef $value;
        }
        elsif ( $field eq 'BaseQuery' && $value eq ( $query_args{Query} // '' ) ) {
            undef $value;
        }
        elsif ( $field =~ /^(?:Order|OrderBy)$/ ) {
            if ( ref $value eq 'ARRAY' ) {
                $value = join '|', @$value;
            }

            # Clean up empty items
            $value = join '|', grep length, split /\|/, $value;
        }

        if ( defined $value && length $value ) {

            # Make sure data saved in db is clean
            if ( $field eq 'Format' ) {
                $value = ScrubHTML($value);
            }

            $short_args{$field} = $value;
            if ( $field eq 'ExtraQueryParams' ) {
                for my $param (
                    ref $short_args{$field} eq 'ARRAY'
                    ? @{ $short_args{$field} }
                    : $short_args{$field}
                    )
                {
                    my $value = delete $query_args{$param};
                    $short_args{$param} = $value if defined $value && length $value;
                }
            }
        }
    }
    return ( %query_args, ShortenQuery(%short_args) );
}

sub ShortenQuery {
    my $query     = QueryString(@_) or return;
    my $shortener = RT::Shortener->new( $session{CurrentUser} );
    my ( $ret, $msg ) = $shortener->LoadOrCreate( Content => $query );
    if ($ret) {
        return ( sc => $shortener->Code );
    }
    else {
        RT->Logger->error("Couldn't load or create Shortener for $query: $msg");
        return @_;
    }
}

sub _ExtractCalendarAttachmentData {

    # The VCALENDAR structure is defined recursively,
    # and this is a recursive function.

    # Notes on the VCALENDAR structure,
    # primary sources: RFCs 5545, 5546
    #   other RFCs may also apply
    #
    # Each Component may have Properties and may have Subcomponents.
    # Each of these is called an "Entry" in some documentation, and also in the Data::ICal module.
    #
    # RFC 5545 describes the structure, while RFC 5546 lists which named properties and subcomponents
    # are permitted, required, and so on.
    #
    # VCALENDAR is the top-level component, with VTIMEZONE and VEVENT as the main subcomponents
    # of interest under it.  VTIMEZINE and VEVENT may have their own subcomponents (e.g. DAYLIGHT
    # and STANDARD under VTIMEZONE).

    #VCALENDAR
    # METHOD
    #   PUBLISH (no interactivity, probably can be ignored)
    #   REQUEST (interactive, looking for responses)
    #   REPLY (a response, conveying status)
    #   ADD (add instances to a recurring series)
    #   CANCEL (cancel one or more instances)
    #   REFRESH (used by an attendee to request an update, probably can be ignored)
    #   COUNTER (used to propose alternate times, probably can be ignored)
    #   DECLINECOUNTER (probably can be ignored)
    # CALSCALE - should be absent or GREGORIAN

    #VTIMEZONE
    # use https://metacpan.org/pod/DateTime::TimeZone::ICal ?
    # TZID - how it will be referred to later
    # DAYLIGHT
    #  DTSTART - irrelevant (start of timezone applicability?)
    #  RDATE, RRULE, TZNAME, TZOFFSETFROM, TZOFFSETTO
    # STANDARD
    #  DTSTART - irrelevant (start of timezone applicability?)
    #  RDATE, RRULE, TZNAME, TZOFFSETFROM, TZOFFSETTO

    # N.B. I've never seen an invitation with multiple VTIMEZONE records, but it's not against the standard.
    #      Each non-UTC datetime MUST have a tzid, but because I've never seen more than one I'm
    #      not bothering to look at it.  This might be a problem for interpreting some attachments.

    #VEVENT
    # DTSTAMP - last-modified date/time
    # SEQUENCE - kind of like a DNS serial number
    # ORGANIZER
    #  CN - if present would be the name
    # SUMMARY
    # LOCATION
    # DESCRIPTION
    # RECURRENCE-ID - used when referring to a specific instance of a recurring event
    # DTSTART
    # DTEND / DURATION
    # EXDATE - exceptions to the recurrence rule
    # RDATE
    # RRULE

    # Since we're not interested in testing RFC5546 conformance, we're just going to use this recursive
    # function to walk the structure and cherry-pick what we want.

    # the hashref into which we put our cherry-picked data elements
    my $summary_data = shift;

    # the Data::ICal::Entry object, from somewhere in the tree
    my $entry = shift;

    # Except for the root entry, everything has a parent, and we need to know what it
    # is in order to be sure about what some of the elements mean.
    my $parent_type = shift || undef;

    my $entry_type;

    eval { $entry_type = $entry->ical_entry_type(); };

    if ($@) {
        RT::Logger->warn($@);
        RT::Logger->warn( ref $entry );
    }

    my $properties = $entry->properties();

    if ( $entry_type eq 'VCALENDAR' and exists $properties->{method} ) {
        my $method = $properties->{method}[0]->value();

        if ( $method =~ /^(REQUEST|CANCEL)$/ ) {
            $summary_data->{type} = $method;
        }
    }
    elsif ( $entry_type eq 'VTIMEZONE' and exists $properties->{tzid} ) {
        $summary_data->{timezone_name} = $properties->{tzid}[0]->value();
    }
    elsif ( $entry_type eq 'VEVENT' ) {
        for my $property_name (
            qw{organizer summary location description sequence dtstamp dtstart dtend recurrence-id attendee})
        {
            if ( exists $properties->{$property_name} ) {
                if ( $property_name eq 'attendee' ) {
                    $summary_data->{$property_name} = join ', ',
                        map { $_->value =~ /.*mailto:(.+)/i ? $1 : () } @{ $properties->{$property_name} };
                }
                else {
                    $summary_data->{$property_name} = $properties->{$property_name}[0]->value();
                }
            }
        }

        if ( exists $properties->{rrule} ) {
            $summary_data->{recurring} = 1;

            if ( exists $properties->{exdate} ) {
                $summary_data->{exceptions} = 1;
            }
        }
    }

    foreach my $subentry ( @{ $entry->entries } ) {
        _ExtractCalendarAttachmentData( $summary_data, $subentry, $entry_type );
    }
}


=head2 ParseCalendarData( RawData => $cal_data )

Takes the raw data of an ICal file and parses it for useful data.

Returns a hashref of the interesting bits, or undef if it couldn't parse the data.

=cut

sub ParseCalendarData {
    require Data::ICal;

    my %args = (
        RawData => undef,
        @_,
    );

    return unless $args{RawData};

    my $cal_item = Data::ICal->new( data => $args{RawData} );

    if ( ref $cal_item and $cal_item->isa('Data::ICal::Entry') ) {
        my %calendar_info = (
            location => loc('unspecified'),
            sequence => 0,
            type     => 'Unknown calendar attachment',    # loc
        );

        _ExtractCalendarAttachmentData( \%calendar_info, $cal_item );

        if ( exists $calendar_info{timezone_name} ) {
            $calendar_info{timezone_text} = $calendar_info{timezone_name};
        }

        foreach my $datetime (qw(dtstamp dtstart dtend)) {

            # dates with a trailing 'Z' actually are in UTC while the other dates are in some
            # other timezine and the best we can do is to use their values unmodified, which
            # is most easily accomplished by using UTC.

            next unless exists $calendar_info{$datetime};

            # it could be date without time
            if ( $calendar_info{$datetime} =~ /^\d{8}$/ ) {
                my $date = RT::Date->new( $session{'CurrentUser'} );
                $date->Set( Format => 'iso', Value => "$calendar_info{$datetime}00:00:00" );
                $calendar_info{$datetime} = $date->AsString( Time => 0, Timezone => 'UTC' );
            }
            else {
                my $date = RT::Date->new( $session{'CurrentUser'} );
                $date->Set( Format => 'iso', Value => $calendar_info{$datetime} );

                if ( $calendar_info{$datetime} =~ /Z$/ ) {

                    # explicitly in UTC, so we know when it is, so go ahead and present it in the user's timezone
                    $calendar_info{$datetime} = $date->AsString();
                }
                else {
                    $calendar_info{$datetime} = $date->AsString( Timezone => 'UTC' ) . ' '
                        . ( $calendar_info{timezone_text} || loc("unknown timezone") );
                }
            }
        }

        if ( $calendar_info{organizer} ) {
            $calendar_info{organizer} =~ s/^MAILTO://i;
        }

        return \%calendar_info;
    }

    return undef;
}

sub PreprocessTransactionSearchQuery {
    my %args = (
        Query      => undef,
        ObjectType => 'RT::Ticket',
        @_
    );

    my @limits;
    if ( $args{ObjectType} eq 'RT::Ticket' ) {
        if ( $args{Query} !~ /^TicketType = 'ticket' AND ObjectType = '$args{ObjectType}' AND (.+)/ ) {
            require RT::Interface::Web::QueryBuilder::Tree;
            my $tree = RT::Interface::Web::QueryBuilder::Tree->new;
            my @results = $tree->ParseSQL(
                Query       => $args{Query},
                CurrentUser => $session{CurrentUser},
                Class       => 'RT::Transactions',
            );

            # Errors will be handled in FromSQL later, so it's safe to simply return here
            return $args{Query} if @results;

            if ( lc( $tree->getNodeValue // '' ) eq 'or' ) {
                $args{Query} = "( $args{Query} )";
            }

            @limits = (
                q{TicketType = 'ticket'},
                qq{ObjectType = '$args{ObjectType}'},
                $args{Query},
            );
        }
        else {
            @limits = $args{Query};
        }
    }
    else {
        # Other ObjectTypes are not supported for now
        @limits = 'id = 0';
    }
    return join ' AND ', @limits;
}

# If you want to apply CSS, like colors, to SVG icons, they must be inlined
# with a svg tag. Currently this is the only way to allow regular CSS
# cascading to work, so this is a better option than using <img> tags
# and not being able to match colors for different themes, for
# example. This has some drawbacks, like making each page a bit
# heavier and not being able to cache the icons. We accept this to
# be able to use SVGs.

# Inline content also avoids seeing images jump onto the page last
# when added via CSS+JS as provided with some icon libraries.

# This is a single place to store and manage the SVG images and icons
# rather than pasting svg markup in many different places in templates.

sub GetSVGImage {
    my %args = (
        Name         => '',
        Title      => '',
        ExtraClasses => '',
        Size         => 16,
        @_
    );

    my $class = 'bi bi-' . $args{'Name'};
    $class .= ' ' . $args{'ExtraClasses'} if $args{'ExtraClasses'};

    my $svg = qq{<svg xmlns="http://www.w3.org/2000/svg" width="$args{Size}" height="$args{Size}" fill="currentColor" class="$class" viewBox="0 0 16 16" role="img"};

    if ( $args{'Title'} ) {
        $svg .= q{ data-bs-toggle="tooltip" title="} . $m->interp->apply_escapes( $args{Title}, 'h' ) . q{"};
    }
    $svg .= '>';
    my $config = RT->Config->Get('SVG') || {};
    if ( length $config->{$args{'Name'}} ) {
        $svg .= $config->{$args{'Name'}} . '</svg>';
    }
    else {
        $svg = qq{<span class="error">SVG $args{'Name'} not found</span>};
    }

    return $svg;
}

=head2 GetWebDisplay Object => $Object, Page => $Page

L<RT_Config/%WebDisplay> contains display configuration for various objects
and pages. This method extracts and returns corresponding part for the given
C<$Object> and C<$Page>.

=cut

sub GetWebDisplay {
    my %args = (
        Object => '',
        Page   => 'Display',
        @_,
    );

    return unless $args{Object};

    my $displays = RT->Config->Get('WebDisplay')->{ ref $args{Object} }{$args{Page}};
    for my $display (@$displays) {
        my $type = $display->{'Type'};
        if ( $type eq 'Queue' ) {
            my $rules = $display->{Rules} or next;
            my $name  = $args{Object}->QueueObj->__Value('Name');
            return $rules->{$name} if $rules->{$name};
        }
        elsif ( $type =~ /^CustomField\.\{(.+)\}$/ ) {
            my $rules = $display->{Rules} or next;
            if ( my $value = $args{Object}->FirstCustomFieldValue($1) ) {
                return $rules->{$value} if $rules->{$value};
            }
        }
        elsif ( $type eq 'Default' ) {
            return $display;
        }
        else {
            RT->Logger->warning("Display type $type is not supported");
        }
    }
}

package RT::Interface::Web;
RT::Base->_ImportOverlays();

1;
