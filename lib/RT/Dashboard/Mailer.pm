# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2026 Best Practical Solutions, LLC
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

package RT::Dashboard::Mailer;
use strict;
use warnings;

use HTML::Mason;
use HTML::RewriteAttributes::Links;
use HTML::RewriteAttributes::Resources;
use MIME::Types;
use POSIX 'tzset';
use RT::Dashboard;
use RT::Interface::Web::Handler;
use RT::Interface::Web;
use File::Temp 'tempdir';
use HTML::Scrubber;
use URI::QueryParam;
use List::MoreUtils qw( any none uniq );
use RT::Util 'InlineCSS';
use MIME::Base64 'decode_base64';
use JSON ();

sub MailDashboards {
    my $self = shift;
    my %args = (
        All    => 0,
        DryRun => 0,
        Time   => time,
        User   => undef,
        Dashboards => 0,
        Recipients => undef,
        Subscription => undef,
        Test => 0,
        @_,
    );

    $RT::Logger->debug("Using time $args{Time} for dashboard generation");

    my $from = $self->GetFrom();
    $RT::Logger->debug("Sending email from $from");

    my @dashboards;
    if( $args{ Dashboards } ) {
        @dashboards = split(/,/, $args{ Dashboards });
        $RT::Logger->warning( "Non-numeric dashboard IDs are not permitted" ) if any{ /\D/ } @dashboards;
        @dashboards = grep { /^\d+$/ } @dashboards;
        if( @dashboards == 0 ) {
            $RT::Logger->warning( "--dashboards option given but no valid dashboard IDs provided; exiting" );
            return;
        }
    }

    # look through each user for her subscriptions
    my $Users = RT::Users->new(RT->SystemUser);
    $Users->LimitToPrivileged;
    $Users->LimitToEnabled;
    if ( $args{User} ) {
        my $user = RT::User->new( RT->SystemUser );
        $user->Load( $args{User} );
        $Users->Limit( FIELD => 'id', VALUE => $user->Id || 0 );
    }

    my @recipients;
    my %recipient_language;

    if ( $args{Recipients} ) {
        for my $recipient ( ref $args{Recipients} eq 'ARRAY' ? @{ $args{Recipients} } : $args{Recipients} ) {
            my $user = RT::User->new( RT->SystemUser );
            $user->Load($recipient);
            if ( !$user->Id && $recipient =~ /@/ ) {
                $user->LoadOrCreateByEmail($recipient);
            }

            if ( $user->Id ) {
                if ( $user->Disabled ) {
                    RT->Logger->error("User $recipient is disabled, exiting");
                    return;
                }
                push @recipients, $user->EmailAddress;
                $recipient_language{ $user->EmailAddress } = $user->Lang;
            }
            else {
                RT->Logger->error("Could not load user $recipient, exiting");
                return;
            }
        }
    }

    if ( $args{Subscription} ) {
        $Users->Limit( FIELD => 'id', VALUE => $args{Subscription}->UserObj->Id || 0 );
    }

    while (defined(my $user = $Users->Next)) {
        my ($hour, $dow, $dom) = HourDowDomIn($args{Time}, $user->Timezone || RT->Config->Get('Timezone'));
        $hour .= ':00';
        $RT::Logger->debug("Checking ".$user->Name."'s subscriptions: hour $hour, dow $dow, dom $dom");

        my $currentuser = RT::CurrentUser->new;
        $currentuser->LoadByName($user->Name);

        my $subscriber_lang = $user->Lang;

        my @subscriptions;
        if ( $args{Subscription} ) {
            push @subscriptions, $args{Subscription};
        }
        else {
            my $collection = $user->DashboardSubscriptions;
            $collection->Limit( FIELD => 'DashboardId', VALUE => \@dashboards, OPERATOR => 'IN' ) if @dashboards;
            @subscriptions = @{ $collection->ItemsArrayRef };
        }

        for my $subscription (@subscriptions) {
            next unless $self->IsSubscriptionReady(
                %args,
                Subscription => $subscription,
                User         => $user,
                LocalTime    => [$hour, $dow, $dom],
                Dashboards   => \@dashboards,
            );

            my $content = $subscription->Content || {};

            my @emails;

            if ( @recipients ) {
                @emails = @recipients;
            }
            else {
                my $recipients = $content->{'Recipients'};
                my $recipients_users = $recipients->{Users};
                my $recipients_groups = $recipients->{Groups};

                # add users' emails to email list
                for my $user_id (@{ $recipients_users || [] }) {
                    my $user = RT::User->new(RT->SystemUser);
                    $user->Load($user_id);
                    next unless $user->id and !$user->Disabled;

                    push @emails, $user->EmailAddress;
                    $recipient_language{ $user->EmailAddress } = $user->Lang;
                }

                # add emails for every group's members
                for my $group_id (@{ $recipients_groups || [] }) {
                    my $group = RT::Group->new(RT->SystemUser);
                    $group->Load($group_id);
                    next unless $group->id;

                    my $users = $group->UserMembersObj;
                    while (my $user = $users->Next) {
                        push @emails, $user->EmailAddress;
                        $recipient_language{ $user->EmailAddress } = $user->Lang;
                    }
                }
            }

            my $email_success = 0;
            for my $email (uniq @emails) {
                eval {
                    my $lang;
                    for my $langkey (RT->Config->Get('EmailDashboardLanguageOrder')) {
                        if ($langkey eq '_subscription') {
                            if ($lang = $content->{'Language'}) {
                                $RT::Logger->debug("Using subscription's specified language '$lang'");
                                last;
                            }
                        }
                        elsif ($langkey eq '_recipient') {
                            if ($lang = $recipient_language{$email}) {
                                $RT::Logger->debug("Using recipient's preferred language '$lang'");
                                last;
                            }
                        }
                        elsif ($langkey eq '_subscriber') {
                            if ($lang = $subscriber_lang) {
                                $RT::Logger->debug("Using subscriber's preferred language '$lang'");
                                last;
                            }
                        }
                        else { # specific language name
                            $lang = $langkey;
                            $RT::Logger->debug("Using EmailDashboardLanguageOrder fallback language '$lang'");
                            last;
                        }
                    }

                    # use English as the absolute fallback. Though the config
                    # lets you specify a site-specific fallback, it also lets
                    # you not specify a fallback, and we don't want to
                    # accidentally reuse whatever language the previous
                    # recipient happened to have
                    if (!$lang) {
                        $RT::Logger->debug("Using RT's fallback language 'en'. You may specify a different fallback language in your config with EmailDashboardLanguageOrder.");
                        $lang = 'en';
                    }

                    my $context_user;
                    if ( ( $content->{'Context'} // '' ) eq 'recipient' ) {
                        $context_user = RT::CurrentUser->new( RT->SystemUser );
                        my ( $ret, $msg ) = $context_user->LoadByEmail( $email );
                        unless ( $ret ) {
                            RT->Logger->error( "Failed to load user with email $email: $msg" );
                            next;
                        }
                        $context_user->{'LangHandle'} = RT::I18N->get_handle($lang);
                    }
                    else {
                        $context_user = $currentuser;
                    }

                    $currentuser->{'LangHandle'} = RT::I18N->get_handle($lang);

                    $self->SendDashboard(
                        %args,
                        CurrentUser  => $currentuser,
                        ContextUser  => $context_user,
                        Email        => $email,
                        Subscription => $subscription,
                        From         => $from,
                    )
                };
                if ( $@ ) {
                    $RT::Logger->error("Caught exception: $@");
                }
                else {
                    $email_success = 1;
                }
            }

            if ( $email_success && !$args{Test} ) {
                my $counter = $content->{'Counter'} || 0;
                $subscription->SetContent( { %$content, Counter => $counter + 1 } )
                    unless $args{DryRun};
            }
        }
    }
}

sub IsSubscriptionReady {
    my $self = shift;
    my %args = (
        All          => 0,
        Subscription => undef,
        User         => undef,
        LocalTime    => [0, 0, 0],
        Dashboards   => undef,
        Test         => 0,
        @_,
    );

    my $subscription = $args{Subscription};
    my $DashboardId  = $subscription->DashboardId;
    my @dashboards   = @{ $args{ Dashboards } };
    if( @dashboards and none { $_ == $DashboardId } @dashboards) {
        $RT::Logger->info("Dashboard $DashboardId not in list of requested dashboards; skipping");
        return;
    }

    my $dashboard = RT::Dashboard->new(RT->SystemUser);
    $dashboard->Load($DashboardId);
    if ( $dashboard->Disabled ) {
        $RT::Logger->info("Dashboard $DashboardId is disabled; skipping");
        return;
    }

    # Check subscription frequency only once we're sure of the dashboard
    return 1 if $args{All} || $args{Test};

    my $content = $subscription->Content || {};
    my $counter       = $content->{'Counter'} || 0;
    my $sub_frequency = $content->{'Frequency'};
    my $sub_hour      = $content->{'Hour'};
    my $sub_dow       = $content->{'Dow'};
    my $sub_dom       = $content->{'Dom'};
    my $sub_fow       = $content->{'Fow'} || 1;

    my $log_frequency = $sub_frequency;
    if ($log_frequency eq 'daily') {
        my $days = join ' ', grep { $content->{$_} }
                             qw/Monday Tuesday Wednesday Thursday Friday
                                Saturday Sunday/;

        $log_frequency = "$log_frequency ($days)";
    }

    my ($hour, $dow, $dom) = @{ $args{LocalTime} };

    $RT::Logger->debug("Checking against subscription " . $subscription->Id . " for " . $args{User}->Name . " with frequency $log_frequency, hour $sub_hour, dow $sub_dow, dom $sub_dom, fow $sub_fow, counter $counter");

    return 0 if $sub_frequency eq 'never';

    # correct hour?
    return 0 if $sub_hour ne $hour;

    if ($sub_frequency eq 'daily') {
        return $content->{$dow} ? 1 : 0;
    }

    if ($sub_frequency eq 'weekly') {
        # correct day of week?
        return 0 if $sub_dow ne $dow;

        # does it match the "every N weeks" clause?
        return 1 if $counter % $sub_fow == 0;

        $subscription->SetContent( { %$content, Counter => $counter + 1 } )
            unless $args{DryRun};
        return 0;
    }

    # if monthly, correct day of month?
    if ($sub_frequency eq 'monthly') {
        return $sub_dom == $dom;
    }

    $RT::Logger->debug("Invalid subscription frequency $sub_frequency for " . $args{User}->Name);

    # unknown frequency type, bail out
    return 0;
}

sub GetFrom {
    RT->Config->Get('DashboardAddress') || RT->Config->Get('OwnerEmail')
}

sub SendDashboard {
    my $self = shift;
    my %args = (
        CurrentUser  => undef,
        ContextUser  => undef,
        Email        => undef,
        Subscription => undef,
        DryRun       => 0,
        @_,
    );

    my $currentuser  = $args{CurrentUser};
    my $context_user = $args{ContextUser} || $currentuser;
    my $subscription = $args{Subscription};

    my $dashboard_content = $subscription->Content || {};
    my $rows = $dashboard_content->{'Rows'};

    my $DashboardId = $subscription->DashboardId;

    my $dashboard = $subscription->DashboardObj;

    # failed to load dashboard. perhaps it was deleted or it changed privacy
    if (!$dashboard->Id) {
        $RT::Logger->warning( "Unable to load dashboard $DashboardId of subscription "
                . $subscription->Id
                . " for user "
                . $currentuser->Name );
        return $self->ObsoleteSubscription(
            %args,
            Subscription => $subscription,
        );
    }

    $RT::Logger->debug('Generating dashboard "'.$dashboard->Name.'" for user "'.$context_user->Name.'":');

    if ($args{DryRun}) {
        print << "SUMMARY";
    Dashboard: @{[ $dashboard->Name ]}
    Subscription Owner: @{[ $currentuser->Name ]}
    Recipient: <$args{Email}>
SUMMARY
        return;
    }

    local $HTML::Mason::Commands::session{CurrentUser} = $currentuser;
    local $HTML::Mason::Commands::session{ContextUser} = $context_user;
    local $HTML::Mason::Commands::session{WebDefaultStylesheet} = 'elevator';
    local $RT::Config::OVERRIDDEN_OPTIONS{WebDefaultThemeMode}  = 'light';
    local $HTML::Mason::Commands::session{_session_id}; # Make sure to not touch sessions table
    local $HTML::Mason::Commands::r = RT::Dashboard::FakeRequest->new;

    my $HasResults = undef;

    my $content = RunComponent(
        '/Dashboards/Render.html',
        id         => $dashboard->Id,
        Preview    => 0,
        HasResults => \$HasResults,
    );

    if ($dashboard_content->{'SuppressIfEmpty'}) {
        # undef means there were no searches, so we should still send it (it's just portlets)
        # 0 means there was at least one search and none had any result, so we should suppress it
        if (defined($HasResults) && !$HasResults) {
            $RT::Logger->debug("Not sending because there are no results and the subscription has SuppressIfEmpty");
            return;
        }
    }

    if ( RT->Config->Get('EmailDashboardRemove') ) {
        for ( RT->Config->Get('EmailDashboardRemove') ) {
            $content =~ s/$_//g;
        }
    }

    $RT::Logger->debug("Got ".length($content)." characters of output.");

    $content = HTML::RewriteAttributes::Links->rewrite(
        $content,
        RT->Config->Get('WebURL') . 'Dashboards/Render.html',
    );

    $self->EmailDashboard(
        %args,
        Dashboard => $dashboard,
        Content   => $content,
    );
}

sub ObsoleteSubscription {
    my $self = shift;
    my %args = (
        From         => undef,
        To           => undef,
        Subscription => undef,
        CurrentUser  => undef,
        @_,
    );

    my $subscription = $args{Subscription};

    my $ok = RT::Interface::Email::SendEmailUsingTemplate(
        From      => $args{From},
        To        => $args{Email},
        Template  => 'Error: Missing dashboard',
        Arguments => {
            SubscriptionObj => $subscription,
        },
        ExtraHeaders => {
            'X-RT-Dashboard-Subscription-Id' => $subscription->Id,
            'X-RT-Dashboard-Id' => ( $subscription->Content || {} )->{'DashboardId'},
        },
    );

    # only delete the subscription if the email looks like it went through
    if ($ok) {
        my ($deleted, $msg) = $subscription->Delete();
        if ($deleted) {
            $RT::Logger->debug("Deleted an obsolete subscription: $msg");
        }
        else {
            $RT::Logger->warning("Unable to delete an obsolete subscription: $msg");
        }
    }
    else {
        $RT::Logger->warning("Unable to notify ".$args{CurrentUser}->Name." of an obsolete subscription");
    }
}

sub DashboardSubject {
    my $self = shift;
    my %args = (
        CurrentUser  => undef,
        Dashboard    => undef,
        Subscription => undef,
        @_,
    );

    my $subscription = $args{Subscription};
    my $dashboard    = $args{Dashboard};
    my $currentuser  = $args{CurrentUser};
    my $frequency    = ( $subscription->Content || {} )->{'Frequency'};

    my %frequency_lookup = (
        'daily'   => 'Daily',   # loc
        'weekly'  => 'Weekly',  # loc
        'monthly' => 'Monthly', # loc
        'never'   => 'Never',   # loc
    );

    my $frequency_display = $frequency_lookup{$frequency}
                         || $frequency;

    my $subject = sprintf '[%s] ' .  RT->Config->Get('DashboardSubject'),
        RT->Config->Get('rtname'),
        $currentuser->loc($frequency_display),
        $dashboard->Name;

    return $subject;
}

sub EmailDashboard {
    my $self = shift;
    my %args = (
        CurrentUser  => undef,
        Email        => undef,
        Dashboard    => undef,
        Subscription => undef,
        Content      => undef,
        @_,
    );

    my $subscription = $args{Subscription};
    my $dashboard    = $args{Dashboard};
    my $currentuser  = $args{CurrentUser};
    my $email        = $args{Email};

    my $subject = $self->DashboardSubject(
        CurrentUser  => $currentuser,
        Dashboard    => $dashboard,
        Subscription => $subscription,
    );

    my $entity = $self->BuildEmail(
        %args,
        To      => $email,
        Subject => $subject,
    );

    $entity->head->replace('X-RT-Dashboard-Id', $dashboard->Id);
    $entity->head->replace('X-RT-Dashboard-Subscription-Id', $subscription->Id);

    $RT::Logger->debug('Mailing dashboard "'.$dashboard->Name.'" to user '.$currentuser->Name." <$email>");

    my $ok = RT::Interface::Email::SendEmail(
        %{ RT->Config->Get('Crypt')->{'Dashboards'} || {} },
        Entity => $entity,
    );

    if (!$ok) {
        $RT::Logger->error("Failed to email dashboard to user ".$currentuser->Name." <$email>");
        return;
    }

    $RT::Logger->debug("Done sending dashboard to ".$currentuser->Name." <$email>");
}

my $chrome_home;

sub BuildEmail {
    my $self = shift;
    my %args = (
        Content => undef,
        From    => undef,
        To      => undef,
        Subject => undef,
        @_,
    );

    my @parts;
    my %cid_of;

    my $content = HTML::RewriteAttributes::Resources->rewrite($args{Content}, sub {
            my $uri = shift;

            # already attached this object
            return "cid:$cid_of{$uri}" if $cid_of{$uri};

            my ($data, $filename, $mimetype, $encoding) = GetResource($uri);
            return $uri unless defined $data;

            $cid_of{$uri} = time() . $$ . int(rand(1e6));

            # Encode textual data in UTF-8, and downgrade (treat
            # codepoints as codepoints, and ensure the UTF-8 flag is
            # off) everything else.
            my @extra;
            if ( $mimetype =~ m{text/} ) {
                $data = Encode::encode( "UTF-8", $data );
                @extra = ( Charset => "UTF-8" );
            } else {
                utf8::downgrade( $data, 1 ) or $RT::Logger->warning("downgrade $data failed");
            }

            push @parts, MIME::Entity->build(
                Top          => 0,
                Data         => $data,
                Type         => $mimetype,
                Encoding     => $encoding,
                Disposition  => 'inline',
                Name         => RT::Interface::Email::EncodeToMIME( String => $filename ),
                'Content-Id' => $cid_of{$uri},
                @extra,
            );

            return "cid:$cid_of{$uri}";
        },
        inline_css => sub {
            my $uri = shift;
            my ($content) = GetResource($uri);
            return defined $content ? $content : "";
        },
        inline_imports => 1,
    );

    # This needs to be done after all of the CSS has been imported (by
    # inline_css above, which is distinct from the work done by CSS::Inliner
    # below) and before all of the scripts are scrubbed away.
    if ( RT->Config->Get('EmailDashboardIncludeCharts') && $content =~ /<div class="chart-wrapper">/ ) {

        # Already resolved and validated by the EmailDashboardIncludeCharts
        # PostLoadCheck, so use it directly.
        my $chrome = RT->Config->Get('ChromePath');
        if ($chrome) {

            # Window size for consistent layout; accept WxH or Chrome's W,H.
            my ( $width, $height );
            my @launch_arguments = RT->Config->Get('ChromeLaunchArguments');
            for my $arg (@launch_arguments) {
                if ( $arg =~ /^--window-size=(\d+)[x,](\d+)$/ ) {
                    ( $width, $height ) = ( $1, $2 );
                    last;
                }
            }
            $width  ||= 2560;
            $height ||= 1440;

            # Chromium refuses to run as root without --no-sandbox; add it
            # when we're root and it isn't already set.
            if ( $> == 0 && !grep { $_ eq '--no-sandbox' } @launch_arguments ) {
                push @launch_arguments, '--no-sandbox';
            }

            # Inline the linked JS (so no network is needed), then append the
            # harvest script that exports each chart canvas.
            my $content_with_script = $content;
            $content_with_script
                =~ s{<script type="text/javascript" src="([^"]+)"></script>}{<script type="text/javascript">@{ [(GetResource( $1 ))[0]] }</script>}g;
            $content_with_script = _InjectChartHarvestScript($content_with_script);

            # write the complete content to a temp file
            my $temp_fh = File::Temp->new(
                UNLINK   => 1,
                TEMPLATE => 'email-dashboard-XXXXXX',
                SUFFIX   => '.html',
                TMPDIR   => 1,
            );
            print $temp_fh Encode::encode( 'UTF-8', $content_with_script );
            close $temp_fh;

            # Render once: load the page, dump the resulting DOM (carrying our
            # exported data: URLs), and exit. No persistent browser.
            my @command = (
                $chrome, ( grep { !/^--window-size=/ } @launch_arguments ),
                '--headless',                   '--disable-gpu',
                "--window-size=$width,$height", '--virtual-time-budget=30000',
                '--dump-dom',                   'file://' . $temp_fh->filename,
            );

            # Chromium needs a writable HOME; if the current one is unset or
            # unwritable (common under a daemon), use a private temp dir. Leave
            # a usable HOME alone (e.g. macOS needs the real one).
            local $ENV{HOME}
                = ( $ENV{HOME} && -d $ENV{HOME} && -w _ )
                ? $ENV{HOME}
                : ( $chrome_home ||= tempdir( CLEANUP => 1 ) );

            # Returns undef (already logged) on any failure.
            my $dom = _RunHeadlessBrowser( \@command );
            if ( defined $dom ) {
                my %image_of = _ExtractChartImagesFromDOM($dom);
                RT->Logger->warning("No chart images were produced by $chrome")
                    unless grep {defined} values %image_of;

                my $cid_base = time() . $$;
                my $cid_seq  = 0;

                # Replace each chart <canvas> with its rendered image, matched
                # by id (not document order). Unmatched canvases are left alone;
                # a matched canvas with no image is dropped.
                $content =~ s{(<canvas\b([^>]*)>(?:\s*</canvas>)?)}{
                    my ( $whole, $attrs ) = ( $1, $2 );
                    my ($id) = $attrs =~ /\bid="([^"]*)"/;
                    if ( defined $id && exists $image_of{$id} ) {
                        my $png  = $image_of{$id};
                        my $repl = '';
                        if ( defined $png && length $png ) {
                            my $cid = $cid_base . ++$cid_seq;
                            push @parts, MIME::Entity->build(
                                Top          => 0,
                                Data         => $png,
                                Type         => 'image/png',
                                Encoding     => 'base64',
                                Disposition  => 'inline',
                                'Content-Id' => "<$cid>",
                            );
                            $repl = qq{<img src="cid:$cid"/>};
                        }
                        $repl;
                    }
                    else {
                        $whole;
                    }
                }ge;
            }
        }
    }

    $content =~ s{<link rel="shortcut icon"[^>]+/>}{};

    # Inline the CSS using CSS::Inliner
    if ( RT->Config->Get('EmailDashboardInlineCSS') ) {
        # Mailer usually works at backend, remove the size limit
        local $RT::Util::INLINE_CSS_MAX_SIZE unless defined $ENV{RT_INLINE_CSS_MAX_SIZE};
        $content = InlineCSS($content);
    }

    $content = ScrubContent($content);

    my $entity = MIME::Entity->build(
        From    => Encode::encode("UTF-8", $args{From}),
        To      => Encode::encode("UTF-8", $args{To}),
        Subject => RT::Interface::Email::EncodeToMIME( String => $args{Subject} ),
        Type    => "multipart/mixed",
    );

    $entity->attach(
        Type        => 'text/html',
        Charset     => 'UTF-8',
        Data        => Encode::encode("UTF-8", $content),
        Disposition => 'inline',
        Encoding    => "base64",
    );

    for my $part (@parts) {
        $entity->add_part($part);
    }

    $entity->make_singlepart;

    return $entity;
}

# Append a script that, after load, exports each chart canvas as a PNG data:
# URL. The {id, url} pairs are stored in a JSON <script> node that BuildEmail
# reads back from the dumped DOM, keying each image to its canvas by id.
sub _InjectChartHarvestScript {
    my $content = shift;

    my $harvest = <<'END_HARVEST';
<script type="text/javascript">
window.addEventListener('load', function () {
    const images = [];
    const canvases = document.querySelectorAll('div.chart canvas');
    for (const canvas of canvases) {
        // Record the id so BuildEmail can match images by id, not by order.
        const entry = { id: canvas.id, url: '' };
        try {
            // Force the chart to its final, un-animated state: the DOM is
            // dumped at load, before animation frames run, so it would
            // otherwise be captured mid-animation.
            if (window.Chart && Chart.getChart) {
                const chart = Chart.getChart(canvas);
                if (chart) {
                    chart.stop();
                    chart.options.animation = false;
                    chart.update('none');
                }
            }
            // Canvases are transparent; flatten onto white (the dashboard
            // background) before exporting.
            const flattened = document.createElement('canvas');
            flattened.width = canvas.width;
            flattened.height = canvas.height;
            const ctx = flattened.getContext('2d');
            ctx.fillStyle = '#ffffff';
            ctx.fillRect(0, 0, flattened.width, flattened.height);
            ctx.drawImage(canvas, 0, 0);
            entry.url = flattened.toDataURL('image/png');
        } catch (e) {
            // leave entry.url empty
        }
        images.push(entry);
    }
    const node = document.createElement('script');
    node.type = 'application/json';
    node.id = 'rt-chart-images';
    node.appendChild(document.createTextNode(JSON.stringify(images)));
    document.body.appendChild(node);
}, false);
</script>
END_HARVEST

    # Insert before the final </body>. A greedy match skips any "</body>"
    # embedded in inlined scripts (e.g. the editor bundle) to reach the real one.
    if ( $content =~ m{</body>}i ) {
        $content =~ s{(.*)</body>}{$1$harvest</body>}is;
    }
    else {
        $content .= $harvest;
    }
    return $content;
}

# Pull the harvested images back out of the dumped DOM. Returns a hash keyed by
# canvas id; each value is the PNG bytes, or undef where a canvas produced none.
# Only harvested canvases (div.chart canvas) are included.
sub _ExtractChartImagesFromDOM {
    my $dom = shift;
    return unless defined $dom;

    my ($json) = $dom =~ m{<script[^>]*\bid="rt-chart-images"[^>]*>(.*?)</script>}s;
    return unless defined $json;

    my $entries = eval { JSON::decode_json($json) };
    if ( ref $entries ne 'ARRAY' ) {
        RT->Logger->error("Couldn't parse chart images from headless browser output: $@");
        return;
    }

    my %image_of;
    for my $entry (@$entries) {
        next unless ref $entry eq 'HASH';
        my $id = $entry->{id};
        next unless defined $id && length $id;

        my $url = $entry->{url};
        if ( defined $url && $url =~ m{^data:image/png;base64,(.+)$}s ) {
            $image_of{$id} = decode_base64($1);
        }
        else {
            $image_of{$id} = undef;
        }
    }
    return %image_of;
}

# Run the headless browser as a one-shot child and return the DOM it dumps. It
# runs in its own process group under a wall-clock deadline; if it hangs, the
# group is killed (TERM then KILL) and reaped. Returns the DOM, or undef on
# failure.
sub _RunHeadlessBrowser {
    my $command = shift;

    require File::Spec;

    # Capture the browser's stdout (the dumped DOM) and stderr via temp files.
    my $dom_fh = File::Temp->new(
        UNLINK   => 1,
        TEMPLATE => 'email-dashboard-dom-XXXXXX',
        SUFFIX   => '.html',
        TMPDIR   => 1,
    );
    my $err_fh = File::Temp->new(
        UNLINK   => 1,
        TEMPLATE => 'email-dashboard-err-XXXXXX',
        TMPDIR   => 1,
    );

    my $pid = fork;
    if ( !defined $pid ) {
        RT->Logger->error("Couldn't fork to render dashboard charts: $!");
        return;
    }
    elsif ( $pid == 0 ) {

        # Child: new process group (so the browser and its helpers can be
        # killed as a group), then exec with stdio pointed at the temp files.
        # On any redirection or exec failure, _exit (not die) so the parent's
        # END/DESTROY blocks don't run; the parent then sees an empty DOM.
        setpgrp( 0, 0 );
        open( STDIN,  '<', File::Spec->devnull ) or POSIX::_exit(127);
        open( STDOUT, '>', $dom_fh->filename )   or POSIX::_exit(127);
        open( STDERR, '>', $err_fh->filename )   or POSIX::_exit(127);

        exec { $command->[0] } @$command or POSIX::_exit(127);
    }

    # Parent: wait up to the deadline. On timeout, signal the process group
    # (TERM then KILL) and reap it, so we never block forever or orphan it.
    my $timed_out;
    eval {
        local $SIG{ALRM} = sub { die "timeout\n" };
        alarm 120;
        waitpid $pid, 0;
        alarm 0;
    };
    if ($@) {
        $timed_out = 1;
        kill 'TERM', -$pid;
        eval {
            local $SIG{ALRM} = sub { die "timeout\n" };
            alarm 5;
            waitpid $pid, 0;
            alarm 0;
        };
        if ($@) {
            kill 'KILL', -$pid;
            waitpid $pid, 0;
        }
    }
    alarm 0;

    seek $err_fh, 0, 0;
    my $stderr = do { local $/; <$err_fh> };
    RT->Logger->debug("Chrome output while rendering charts: $stderr") if defined $stderr && length $stderr;

    if ($timed_out) {
        RT->Logger->error("Timed out rendering dashboard charts with $command->[0], killed the browser");
        return;
    }

    seek $dom_fh, 0, 0;
    return do { local $/; <$dom_fh> };
}

{
    my $mason;
    my $outbuf = '';
    my $data_dir = '';

    sub _mason {
        unless ($mason) {
            $RT::Logger->debug("Creating Mason object.");

            # user may not have permissions on the data directory, so create a
            # new one
            $data_dir = tempdir(CLEANUP => 1);

            $mason = HTML::Mason::Interp->new(
                RT::Interface::Web::Handler->DefaultHandlerArgs,
                out_method => \$outbuf,
                autohandler_name => '', # disable forced login and more
                data_dir => $data_dir,
            );
            $mason->set_escape( h => \&RT::Interface::Web::EscapeHTML );
            $mason->set_escape( u => \&RT::Interface::Web::EscapeURI  );
            $mason->set_escape( j => \&RT::Interface::Web::EscapeJS   );
        }
        return $mason;
    }

    sub RunComponent {
        _mason->exec(@_);
        my $ret = $outbuf;
        $outbuf = '';
        return $ret;
    }
}

{
    my $scrubber;

    sub _scrubber {
        unless ($scrubber) {
            $scrubber = HTML::Scrubber->new;
            # Allow everything by default, except JS attributes ...
            $scrubber->default(
                1 => {
                    '*' => 1,
                    map { ("on$_" => 0) }
                         qw(blur change click dblclick error focus keydown keypress keyup load
                            mousedown mousemove mouseout mouseover mouseup reset select submit unload)
                }
            );
            # ... and <script>s
            $scrubber->deny('script');

            # ... and the favicon image
            $scrubber->rules(
                link => {
                    href => qr{(?<!favicon\.png)$},
                    '*'  => 1,
                },
            );

        }
        return $scrubber;
    }

    sub ScrubContent {
        my $content = shift;
        return _scrubber->scrub($content);
    }
}

{
    my %cache;

    sub HourDowDomIn {
        my $now = shift;
        my $tz  = shift;

        my $key = "$now $tz";
        return @{$cache{$key}} if exists $cache{$key};

        my ($hour, $dow, $dom);

        {
            local $ENV{'TZ'} = $tz;
            ## Using POSIX::tzset fixes a bug where the TZ environment variable
            ## is cached.
            tzset();
            (undef, undef, $hour, $dom, undef, undef, $dow) = localtime($now);
        }
        tzset(); # return back previous value

        $hour = "0$hour"
            if length($hour) == 1;
        $dow = (qw/Sunday Monday Tuesday Wednesday Thursday Friday Saturday/)[$dow];

        return @{$cache{$key}} = ($hour, $dow, $dom);
    }
}

sub GetResource {
    my $uri = URI->new(shift);
    my ($content, $content_type, $filename, $mimetype, $encoding);

    # Avoid trying to inline any remote URIs.  We absolutified all URIs
    # using WebURL in SendDashboard() above, so choose the simpler match on
    # that rather than testing a bunch of URI accessors.
    my $WebURL = RT->Config->Get("WebURL");
    return unless $uri =~ /^\Q$WebURL/;

    $RT::Logger->debug("Getting resource $uri");

    # strip out the equivalent of WebURL, so we start at the correct /
    my $path = $uri->path;
    my $webpath = RT->Config->Get('WebPath');
    $path =~ s/^\Q$webpath//;

    # add a leading / if needed
    $path = "/$path"
        unless $path =~ m{^/};

    # Try the static handler first for non-Mason CSS, JS, etc.
    my $res = RT::Interface::Web::Handler->GetStatic($path);
    if ($res->is_success) {
        RT->Logger->debug("Fetched '$path' from the static handler");
        $content      = $res->decoded_content;
        $content_type = $res->headers->content_type;
    } else {
        # Try it through Mason instead...
        $HTML::Mason::Commands::r->path_info($path);

        # grab the query arguments
        my %args = map { $_ => [ map {Encode::decode("UTF-8",$_)}
                                     $uri->query_param($_) ] } $uri->query_param;
        # Convert empty and single element arrayrefs to a non-ref scalar
        @$_ < 2 and $_ = $_->[0]
            for values %args;

        $RT::Logger->debug("Running component '$path'");
        $content = RunComponent($path, %args);

        $content_type = $HTML::Mason::Commands::r->content_type;
    }

    # guess at the filename from the component name
    $filename = $1 if $path =~ m{^.*/(.*?)$};

    # the rest of this was taken from Email::MIME::CreateHTML::Resolver::LWP
    ($mimetype, $encoding) = MIME::Types::by_suffix($filename);

    if ($content_type) {
        $mimetype = $content_type;

        # strip down to just a MIME type
        $mimetype = $1 if $mimetype =~ /(\S+);\s*charset=(.*)$/;
    }

    #If all else fails then some conservative and general-purpose defaults are:
    $mimetype ||= 'application/octet-stream';
    $encoding ||= 'base64';

    $RT::Logger->debug("Resource $uri: length=".length($content)." filename='$filename' mimetype='$mimetype', encoding='$encoding'");

    return ($content, $filename, $mimetype, $encoding);
}


{
    package RT::Dashboard::FakeRequest;
    sub new { bless {}, shift }
    sub header_out { return undef }
    sub headers_out { wantarray ? () : {} }
    sub err_headers_out { wantarray ? () : {} }
    sub content_type {
        my $self = shift;
        $self->{content_type} = shift if @_;
        return $self->{content_type};
    }
    sub path_info {
        my $self = shift;
        $self->{path_info} = shift if @_;
        return $self->{path_info};
    }
}

require RT::Base;
RT::Base->_ImportOverlays();

1;

