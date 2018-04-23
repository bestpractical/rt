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
use List::MoreUtils 'uniq';

sub MailDashboards {
    my $self = shift;
    my %args = (
        All    => 0,
        DryRun => 0,
        Time   => time,
        @_,
    );

    $RT::Logger->debug("Using time $args{Time} for dashboard generation");

    my $from = $self->GetFrom();
    $RT::Logger->debug("Sending email from $from");

    # look through each user for her subscriptions
    my $Users = RT::Users->new(RT->SystemUser);
    $Users->LimitToPrivileged;

    while (defined(my $user = $Users->Next)) {
        if ($user->PrincipalObj->Disabled) {
            $RT::Logger->debug("Skipping over " . $user->Name . " due to having a disabled account.");
            next;
        }

        my ($hour, $dow, $dom) = HourDowDomIn($args{Time}, $user->Timezone || RT->Config->Get('Timezone'));
        $hour .= ':00';
        $RT::Logger->debug("Checking ".$user->Name."'s subscriptions: hour $hour, dow $dow, dom $dom");

        my $currentuser = RT::CurrentUser->new;
        $currentuser->LoadByName($user->Name);

        my $subscriber_lang = $user->Lang;

        # look through this user's subscriptions, are any supposed to be generated
        # right now?
        for my $subscription ($user->Attributes->Named('Subscription')) {
            next unless $self->IsSubscriptionReady(
                %args,
                Subscription => $subscription,
                User         => $user,
                LocalTime    => [$hour, $dow, $dom],
            );

            my $recipients = $subscription->SubValue('Recipients');
            my $recipients_users = $recipients->{Users};
            my $recipients_groups = $recipients->{Groups};

            my @emails;
            my %recipient_language;

            # add users' emails to email list
            for my $user_id (@{ $recipients_users || [] }) {
                my $user = RT::User->new(RT->SystemUser);
                $user->Load($user_id);
                next unless $user->id;

                push @emails, $user->EmailAddress;
                $recipient_language{$user->EmailAddress} = $user->Lang;
            }

            # add emails for every group's members
            for my $group_id (@{ $recipients_groups || [] }) {
                my $group = RT::Group->new(RT->SystemUser);
                $group->Load($group_id);
                next unless $group->id;

                my $users = $group->UserMembersObj;
                while (my $user = $users->Next) {
                    push @emails, $user->EmailAddress;
                    $recipient_language{$user->EmailAddress} = $user->Lang;
                }
            }

            my $email_success = 0;
            for my $email (uniq @emails) {
                eval {
                    my $lang;
                    for my $langkey (RT->Config->Get('EmailDashboardLanguageOrder')) {
                        if ($langkey eq '_subscription') {
                            if ($lang = $subscription->SubValue('Language')) {
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

                    $currentuser->{'LangHandle'} = RT::I18N->get_handle($lang);

                    $self->SendDashboard(
                        %args,
                        CurrentUser  => $currentuser,
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

            if ($email_success) {
                my $counter = $subscription->SubValue('Counter') || 0;
                $subscription->SetSubValues(Counter => $counter + 1)
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
        @_,
    );

    return 1 if $args{All};

    my $subscription  = $args{Subscription};

    my $counter       = $subscription->SubValue('Counter') || 0;

    my $sub_frequency = $subscription->SubValue('Frequency');
    my $sub_hour      = $subscription->SubValue('Hour');
    my $sub_dow       = $subscription->SubValue('Dow');
    my $sub_dom       = $subscription->SubValue('Dom');
    my $sub_fow       = $subscription->SubValue('Fow') || 1;

    my $log_frequency = $sub_frequency;
    if ($log_frequency eq 'daily') {
        my $days = join ' ', grep { $subscription->SubValue($_) }
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
        return $subscription->SubValue($dow) ? 1 : 0;
    }

    if ($sub_frequency eq 'weekly') {
        # correct day of week?
        return 0 if $sub_dow ne $dow;

        # does it match the "every N weeks" clause?
        return 1 if $counter % $sub_fow == 0;

        $subscription->SetSubValues(Counter => $counter + 1)
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
        Email        => undef,
        Subscription => undef,
        DryRun       => 0,
        @_,
    );

    my $currentuser  = $args{CurrentUser};
    my $subscription = $args{Subscription};

    my $rows = $subscription->SubValue('Rows');

    my $DashboardId = $subscription->SubValue('DashboardId');

    my $dashboard = RT::Dashboard->new($currentuser);
    my ($ok, $msg) = $dashboard->LoadById($DashboardId);

    # failed to load dashboard. perhaps it was deleted or it changed privacy
    if (!$ok) {
        $RT::Logger->warning("Unable to load dashboard $DashboardId of subscription ".$subscription->Id." for user ".$currentuser->Name.": $msg");
        return $self->ObsoleteSubscription(
            %args,
            Subscription => $subscription,
        );
    }

    $RT::Logger->debug('Generating dashboard "'.$dashboard->Name.'" for user "'.$currentuser->Name.'":');

    if ($args{DryRun}) {
        print << "SUMMARY";
    Dashboard: @{[ $dashboard->Name ]}
    User:   @{[ $currentuser->Name ]} <$args{Email}>
SUMMARY
        return;
    }

    local $HTML::Mason::Commands::session{CurrentUser} = $currentuser;
    local $HTML::Mason::Commands::r = RT::Dashboard::FakeRequest->new;

    my $HasResults = undef;

    my $content = RunComponent(
        '/Dashboards/Render.html',
        id         => $dashboard->Id,
        Preview    => 0,
        HasResults => \$HasResults,
    );

    if ($subscription->SubValue('SuppressIfEmpty')) {
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

    $content = ScrubContent($content);

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
            'X-RT-Dashboard-Id' => $subscription->SubValue('DashboardId'),
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

    my $frequency    = $subscription->SubValue('Frequency');

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

RT::Base->_ImportOverlays();

1;

