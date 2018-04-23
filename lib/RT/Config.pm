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

package RT::Config;

use strict;
use warnings;

use 5.010;
use File::Spec ();
use Symbol::Global::Name;
use List::MoreUtils 'uniq';

# Store log messages generated before RT::Logger is available
our @PreInitLoggerMessages;

=head1 NAME

    RT::Config - RT's config

=head1 SYNOPSYS

    # get config object
    use RT::Config;
    my $config = RT::Config->new;
    $config->LoadConfigs;

    # get or set option
    my $rt_web_path = $config->Get('WebPath');
    $config->Set(EmailOutputEncoding => 'latin1');

    # get config object from RT package
    use RT;
    RT->LoadConfig;
    my $config = RT->Config;

=head1 DESCRIPTION

C<RT::Config> class provide access to RT's and RT extensions' config files.

RT uses two files for site configuring:

First file is F<RT_Config.pm> - core config file. This file is shipped
with RT distribution and contains default values for all available options.
B<You should never edit this file.>

Second file is F<RT_SiteConfig.pm> - site config file. You can use it
to customize your RT instance. In this file you can override any option
listed in core config file.

You may also split settings into separate files under the
F<etc/RT_SiteConfig.d/> directory.  All files ending in C<.pm> will be parsed,
in alphabetical order, after F<RT_SiteConfig.pm> is loaded.

RT extensions could also provide their config files. Extensions should
use F<< <NAME>_Config.pm >> and F<< <NAME>_SiteConfig.pm >> names for
config files, where <NAME> is extension name.

B<NOTE>: All options from RT's config and extensions' configs are saved
in one place and thus extension could override RT's options, but it is not
recommended.

=cut

=head2 %META

Hash of Config options that may be user overridable
or may require more logic than should live in RT_*Config.pm

Keyed by config name, there are several properties that
can be set for each config optin:

 Section     - What header this option should be grouped
               under on the user Preferences page
 Overridable - Can users change this option
 SortOrder   - Within a Section, how should the options be sorted
               for display to the user
 Widget      - Mason component path to widget that should be used 
               to display this config option
 WidgetArguments - An argument hash passed to the WIdget
    Description - Friendly description to show the user
    Values      - Arrayref of options (for select Widget)
    ValuesLabel - Hashref, key is the Value from the Values
                  list, value is a user friendly description
                  of the value
    Callback    - subref that receives no arguments.  It returns
                  a hashref of items that are added to the rest
                  of the WidgetArguments
 PostSet       - subref passed the RT::Config object and the current and
                 previous setting of the config option.  This is called well
                 before much of RT's subsystems are initialized, so what you
                 can do here is pretty limited.  It's mostly useful for
                 effecting the value of other config options early.
 PostLoadCheck - subref passed the RT::Config object and the current
                 setting of the config option.  Can make further checks
                 (such as seeing if a library is installed) and then change
                 the setting of this or other options in the Config using 
                 the RT::Config option.
   Obfuscate   - subref passed the RT::Config object, current setting of the config option
                 and a user object, can return obfuscated value. it's called in
                 RT->Config->GetObfuscated() 

=cut

our %META;
%META = (
    # General user overridable options
    RestrictReferrerLogin => {
        PostLoadCheck => sub {
            my $self = shift;
            if (defined($self->Get('RestrictReferrerLogin'))) {
                RT::Logger->error("The config option 'RestrictReferrerLogin' is incorrect, and should be 'RestrictLoginReferrer' instead.");
            }
        },
    },
    DefaultQueue => {
        Section         => 'General',
        Overridable     => 1,
        SortOrder       => 1,
        Widget          => '/Widgets/Form/Select',
        WidgetArguments => {
            Description => 'Default queue',    #loc
            Callback    => sub {
                my $ret = { Values => [], ValuesLabel => {}};
                my $q = RT::Queues->new($HTML::Mason::Commands::session{'CurrentUser'});
                $q->UnLimit;
                while (my $queue = $q->Next) {
                    next unless $queue->CurrentUserHasRight("CreateTicket");
                    push @{$ret->{Values}}, $queue->Id;
                    $ret->{ValuesLabel}{$queue->Id} = $queue->Name;
                }
                return $ret;
            },
        }
    },
    RememberDefaultQueue => {
        Section     => 'General',
        Overridable => 1,
        SortOrder   => 2,
        Widget      => '/Widgets/Form/Boolean',
        WidgetArguments => {
            Description => 'Remember default queue' # loc
        }
    },
    UsernameFormat => {
        Section         => 'General',
        Overridable     => 1,
        SortOrder       => 3,
        Widget          => '/Widgets/Form/Select',
        WidgetArguments => {
            Description => 'Username format', # loc
            Values      => [qw(role concise verbose)],
            ValuesLabel => {
                role    => 'Privileged: usernames; Unprivileged: names and email addresses', # loc
                concise => 'Short usernames', # loc
                verbose => 'Name and email address', # loc
            },
        },
    },
    AutocompleteOwners => {
        Section     => 'General',
        Overridable => 1,
        SortOrder   => 3.1,
        Widget      => '/Widgets/Form/Boolean',
        WidgetArguments => {
            Description => 'Use autocomplete to find owners?', # loc
            Hints       => 'Replaces the owner dropdowns with textboxes' #loc
        }
    },
    AutocompleteQueues => {
        Section     => 'General',
        Overridable => 1,
        SortOrder   => 3.2,
        Widget      => '/Widgets/Form/Boolean',
        WidgetArguments => {
            Description => 'Use autocomplete to find queues?', # loc
            Hints       => 'Replaces the queue dropdowns with textboxes' #loc
        }
    },
    WebDefaultStylesheet => {
        Section         => 'General',                #loc
        Overridable     => 1,
        SortOrder       => 4,
        Widget          => '/Widgets/Form/Select',
        WidgetArguments => {
            Description => 'Theme',                  #loc
            Callback    => sub {
                state @stylesheets;
                unless (@stylesheets) {
                    for my $static_path ( RT::Interface::Web->StaticRoots ) {
                        my $css_path =
                          File::Spec->catdir( $static_path, 'css' );
                        next unless -d $css_path;
                        if ( opendir my $dh, $css_path ) {
                            push @stylesheets, grep {
                                $_ ne 'base' && -e File::Spec->catfile( $css_path, $_, 'main.css' )
                            } readdir $dh;
                        }
                        else {
                            RT->Logger->error("Can't read $css_path: $!");
                        }
                    }
                    @stylesheets = sort { lc $a cmp lc $b } uniq @stylesheets;
                }
                return { Values => \@stylesheets };
            },
        },
        PostLoadCheck => sub {
            my $self = shift;
            my $value = $self->Get('WebDefaultStylesheet');

            my @roots = RT::Interface::Web->StaticRoots;
            for my $root (@roots) {
                return if -d "$root/css/$value";
            }

            $RT::Logger->warning(
                "The default stylesheet ($value) does not exist in this instance of RT. "
              . "Defaulting to rudder."
            );

            $self->Set('WebDefaultStylesheet', 'rudder');
        },
    },
    TimeInICal => {
        Section     => 'General',
        Overridable => 1,
        SortOrder   => 5,
        Widget      => '/Widgets/Form/Boolean',
        WidgetArguments => {
            Description => 'Include time in iCal feed events?', # loc
            Hints       => 'Formats iCal feed events with date and time' #loc
        }
    },
    UseSideBySideLayout => {
        Section => 'Ticket composition',
        Overridable => 1,
        SortOrder => 5,
        Widget => '/Widgets/Form/Boolean',
        WidgetArguments => {
            Description => 'Use a two column layout for create and update forms?' # loc
        }
    },
    MessageBoxRichText => {
        Section => 'Ticket composition',
        Overridable => 1,
        SortOrder => 5.1,
        Widget => '/Widgets/Form/Boolean',
        WidgetArguments => {
            Description => 'WYSIWYG message composer' # loc
        }
    },
    MessageBoxUseSystemContextMenu => {
        Section         => 'Ticket composition', #loc
        Overridable     => 1,
        SortOrder       => 5.2,
        Widget          => '/Widgets/Form/Boolean',
        WidgetArguments => {
            Description => 'WYSIWYG use browser right-click menu', #loc
        },
    },
    MessageBoxRichTextHeight => {
        Section => 'Ticket composition',
        Overridable => 1,
        SortOrder => 6,
        Widget => '/Widgets/Form/Integer',
        WidgetArguments => {
            Description => 'WYSIWYG composer height', # loc
        }
    },
    MessageBoxWidth => {
        Section         => 'Ticket composition',
        Overridable     => 1,
        SortOrder       => 7,
        Widget          => '/Widgets/Form/Integer',
        WidgetArguments => {
            Description => 'Message box width',           #loc
        },
    },
    MessageBoxHeight => {
        Section         => 'Ticket composition',
        Overridable     => 1,
        SortOrder       => 8,
        Widget          => '/Widgets/Form/Integer',
        WidgetArguments => {
            Description => 'Message box height',          #loc
        },
    },
    DefaultTimeUnitsToHours => {
        Section         => 'Ticket composition', #loc
        Overridable     => 1,
        SortOrder       => 9,
        Widget          => '/Widgets/Form/Boolean',
        WidgetArguments => {
            Description => 'Enter time in hours by default', #loc
            Hints       => 'Only for entry, not display', #loc
        },
    },
    SignatureAboveQuote => {
        Section         => 'Ticket composition', #loc
        Overridable     => 1,
        SortOrder       => 10,
        Widget          => '/Widgets/Form/Boolean',
        WidgetArguments => {
            Description => 'Place signature above quote', #loc
        },
    },
    PreferDropzone => {
        Section         => 'Ticket composition', #loc
        Overridable     => 1,
        SortOrder       => 11,
        Widget          => '/Widgets/Form/Boolean',
        WidgetArguments => {
            Description => 'Use dropzone if available', #loc
        },
    },
    RefreshIntervals => {
        Type => 'ARRAY',
        PostLoadCheck => sub {
            my $self = shift;
            my @intervals = $self->Get('RefreshIntervals');
            if (grep { $_ == 0 } @intervals) {
                $RT::Logger->warning("Please do not include a 0 value in RefreshIntervals, as that default is already added for you.");
            }
        },
    },
    SearchResultsRefreshInterval => {
        Section         => 'General',                       #loc
        Overridable     => 1,
        SortOrder       => 9,
        Widget          => '/Widgets/Form/Select',
        WidgetArguments => {
            Description => 'Search results refresh interval', #loc
            Callback    => sub {
                my @values = RT->Config->Get('RefreshIntervals');
                my %labels = (
                    0 => "Don't refresh search results.", # loc
                );

                for my $value (@values) {
                    if ($value % 60 == 0) {
                        $labels{$value} = [
                            'Refresh search results every [quant,_1,minute,minutes].', #loc
                            $value / 60
                        ];
                    }
                    else {
                        $labels{$value} = [
                            'Refresh search results every [quant,_1,second,seconds].', #loc
                            $value
                        ];
                    }
                }

                unshift @values, 0;

                return { Values => \@values, ValuesLabel => \%labels };
            },
        },  
    },

    # User overridable options for RT at a glance
    HomePageRefreshInterval => {
        Section         => 'RT at a glance',                       #loc
        Overridable     => 1,
        SortOrder       => 2,
        Widget          => '/Widgets/Form/Select',
        WidgetArguments => {
            Description => 'Home page refresh interval',                #loc
            Callback    => sub {
                my @values = RT->Config->Get('RefreshIntervals');
                my %labels = (
                    0 => "Don't refresh home page.", # loc
                );

                for my $value (@values) {
                    if ($value % 60 == 0) {
                        $labels{$value} = [
                            'Refresh home page every [quant,_1,minute,minutes].', #loc
                            $value / 60
                        ];
                    }
                    else {
                        $labels{$value} = [
                            'Refresh home page every [quant,_1,second,seconds].', #loc
                            $value
                        ];
                    }
                }

                unshift @values, 0;

                return { Values => \@values, ValuesLabel => \%labels };
            },
        },  
    },

    # User overridable options for Ticket displays
    PreferRichText => {
        Section         => 'Ticket display', # loc
        Overridable     => 1,
        SortOrder       => 0.9,
        Widget          => '/Widgets/Form/Boolean',
        WidgetArguments => {
            Description => 'Display messages in rich text if available', # loc
            Hints       => 'Rich text (HTML) shows formatting such as colored text, bold, italics, and more', # loc
        },
    },
    MaxInlineBody => {
        Section         => 'Ticket display',              #loc
        Overridable     => 1,
        SortOrder       => 1,
        Widget          => '/Widgets/Form/Integer',
        WidgetArguments => {
            Description => 'Maximum inline message length',    #loc
            Hints =>
            "Length in characters; Use '0' to show all messages inline, regardless of length" #loc
        },
    },
    OldestTransactionsFirst => {
        Section         => 'Ticket display',
        Overridable     => 1,
        SortOrder       => 2,
        Widget          => '/Widgets/Form/Boolean',
        WidgetArguments => {
            Description => 'Show oldest history first',    #loc
        },
    },
    ShowHistory => {
        Section         => 'Ticket display',
        Overridable     => 1,
        SortOrder       => 3,
        Widget          => '/Widgets/Form/Select',
        WidgetArguments => {
            Description => 'Show history',                #loc
            Values      => [qw(delay click always scroll)],
            ValuesLabel => {
                delay   => "after the rest of the page loads",  #loc
                click   => "after clicking a link",             #loc
                always  => "immediately",                       #loc
                scroll  => "as you scroll",                     #loc
            },
        },
    },
    ShowUnreadMessageNotifications => { 
        Section         => 'Ticket display',
        Overridable     => 1,
        SortOrder       => 4,
        Widget          => '/Widgets/Form/Boolean',
        WidgetArguments => {
            Description => 'Notify me of unread messages',    #loc
        },

    },
    PlainTextMono => {
        Section         => 'Ticket display',
        Overridable     => 1,
        SortOrder       => 5,
        Widget          => '/Widgets/Form/Boolean',
        WidgetArguments => {
            Description => 'Display plain-text attachments in fixed-width font', #loc
            Hints => 'Display all plain-text attachments in a monospace font with formatting preserved, but wrapping as needed.', #loc
        },
    },
    MoreAboutRequestorTicketList => {
        Section         => 'Ticket display',                       #loc
        Overridable     => 1,
        SortOrder       => 6,
        Widget          => '/Widgets/Form/Select',
        WidgetArguments => {
            Description => 'What tickets to display in the "More about requestor" box',                #loc
            Values      => [qw(Active Inactive All None)],
            ValuesLabel => {
                Active   => "Show the Requestor's 10 highest priority active tickets",                  #loc
                Inactive => "Show the Requestor's 10 highest priority inactive tickets",      #loc
                All      => "Show the Requestor's 10 highest priority tickets",      #loc
                None     => "Show no tickets for the Requestor", #loc
            },
        },
    },
    SimplifiedRecipients => {
        Section         => 'Ticket display',                       #loc
        Overridable     => 1,
        SortOrder       => 7,
        Widget          => '/Widgets/Form/Boolean',
        WidgetArguments => {
            Description => "Show simplified recipient list on ticket update",                #loc
        },
    },
    SquelchedRecipients => {
        Section         => 'Ticket display',                       #loc
        Overridable     => 1,
        SortOrder       => 8,
        Widget          => '/Widgets/Form/Boolean',
        WidgetArguments => {
            Description => "Default to squelching all outgoing email notifications (from web interface) on ticket update", #loc
        },
    },
    DisplayTicketAfterQuickCreate => {
        Section         => 'Ticket display',
        Overridable     => 1,
        SortOrder       => 9,
        Widget          => '/Widgets/Form/Boolean',
        WidgetArguments => {
            Description => 'Display ticket after "Quick Create"', #loc
        },
    },
    QuoteFolding => {
        Section => 'Ticket display',
        Overridable => 1,
        SortOrder => 10,
        Widget => '/Widgets/Form/Boolean',
        WidgetArguments => {
            Description => 'Enable quote folding?' # loc
        }
    },
    HideUnsetFieldsOnDisplay => {
        Section => 'Ticket display',
        Overridable => 1,
        SortOrder => 11,
        Widget => '/Widgets/Form/Boolean',
        WidgetArguments => {
            Description => 'Hide unset fields?' # loc
        }
    },

    # User overridable locale options
    DateTimeFormat => {
        Section         => 'Locale',                       #loc
        Overridable     => 1,
        Widget          => '/Widgets/Form/Select',
        WidgetArguments => {
            Description => 'Date format',                            #loc
            Callback => sub { my $ret = { Values => [], ValuesLabel => {}};
                              my $date = RT::Date->new($HTML::Mason::Commands::session{'CurrentUser'});
                              $date->SetToNow;
                              foreach my $value ($date->Formatters) {
                                 push @{$ret->{Values}}, $value;
                                 $ret->{ValuesLabel}{$value} = $date->Get(
                                     Format     => $value,
                                     Timezone   => 'user',
                                 );
                              }
                              return $ret;
            },
        },
    },

    RTAddressRegexp => {
        Type    => 'SCALAR',
        PostLoadCheck => sub {
            my $self = shift;
            my $value = $self->Get('RTAddressRegexp');
            if (not $value) {
                $RT::Logger->debug(
                    'The RTAddressRegexp option is not set in the config.'
                    .' Not setting this option results in additional SQL queries to'
                    .' check whether each address belongs to RT or not.'
                    .' It is especially important to set this option if RT receives'
                    .' emails on addresses that are not in the database or config.'
                );
            } elsif (ref $value and ref $value eq "Regexp") {
                # Ensure that the regex is case-insensitive; while the
                # local part of email addresses is _technically_
                # case-sensitive, most MTAs don't treat it as such.
                $RT::Logger->warning(
                    'RTAddressRegexp is set to a case-sensitive regular expression.'
                    .' This may lead to mail loops with MTAs which treat the'
                    .' local part as case-insensitive -- which is most of them.'
                ) if "$value" =~ /^\(\?[a-z]*-([a-z]*):/ and "$1" =~ /i/;
            }
        },
    },
    # User overridable mail options
    EmailFrequency => {
        Section         => 'Mail',                                     #loc
        Overridable     => 1,
        Default     => 'Individual messages',
        Widget          => '/Widgets/Form/Select',
        WidgetArguments => {
            Description => 'Email delivery',    #loc
            Values      => [
            'Individual messages',    #loc
            'Daily digest',           #loc
            'Weekly digest',          #loc
            'Suspended'               #loc
            ]
        }
    },
    NotifyActor => {
        Section         => 'Mail',                                     #loc
        Overridable     => 1,
        SortOrder       => 2,
        Widget          => '/Widgets/Form/Boolean',
        WidgetArguments => {
            Description => 'Outgoing mail', #loc
            Hints => 'Should RT send you mail for ticket updates you make?', #loc
        }
    },

    # this tends to break extensions that stash links in ticket update pages
    Organization => {
        Type            => 'SCALAR',
        PostLoadCheck   => sub {
            my ($self,$value) = @_;
            $RT::Logger->error("your \$Organization setting ($value) appears to contain whitespace.  Please fix this.")
                if $value =~ /\s/;;
        },
    },

    # Internal config options
    DatabaseExtraDSN => {
        Type => 'HASH',
    },

    FullTextSearch => {
        Type => 'HASH',
        PostLoadCheck => sub {
            my $self = shift;
            my $v = $self->Get('FullTextSearch');
            return unless $v->{Enable} and $v->{Indexed};
            my $dbtype = $self->Get('DatabaseType');
            if ($dbtype eq 'Oracle') {
                if (not $v->{IndexName}) {
                    $RT::Logger->error("No IndexName set for full-text index; disabling");
                    $v->{Enable} = $v->{Indexed} = 0;
                }
            } elsif ($dbtype eq 'Pg') {
                my $bad = 0;
                if (not $v->{'Column'}) {
                    $RT::Logger->error("No Column set for full-text index; disabling");
                    $v->{Enable} = $v->{Indexed} = 0;
                } elsif ($v->{'Column'} eq "Content"
                             and (not $v->{'Table'} or $v->{'Table'} eq "Attachments")) {
                    $RT::Logger->error("Column for full-text index is set to Content, not tsvector column; disabling");
                    $v->{Enable} = $v->{Indexed} = 0;
                }
            } elsif ($dbtype eq 'mysql') {
                if (not $v->{'Table'}) {
                    $RT::Logger->error("No Table set for full-text index; disabling");
                    $v->{Enable} = $v->{Indexed} = 0;
                } elsif ($v->{'Table'} eq "Attachments") {
                    $RT::Logger->error("Table for full-text index is set to Attachments, not FTS table; disabling");
                    $v->{Enable} = $v->{Indexed} = 0;
                } else {
                    my (undef, $create) = eval { $RT::Handle->dbh->selectrow_array("SHOW CREATE TABLE " . $v->{Table}); };
                    my ($engine) = ($create||'') =~ /engine=(\S+)/i;
                    if (not $create) {
                        $RT::Logger->error("External table ".$v->{Table}." does not exist");
                        $v->{Enable} = $v->{Indexed} = 0;
                    } elsif (lc $engine eq "sphinx") {
                        # External Sphinx indexer
                        $v->{Sphinx} = 1;
                        unless ($v->{'MaxMatches'}) {
                            $RT::Logger->warn("No MaxMatches set for full-text index; defaulting to 10000");
                            $v->{MaxMatches} = 10_000;
                        }
                    } else {
                        # Internal, one-column table
                        $v->{Column} = 'Content';
                        $v->{Engine} = $engine;
                    }
                }
            } else {
                $RT::Logger->error("Indexed full-text-search not supported for $dbtype");
                $v->{Indexed} = 0;
            }
        },
    },
    DisableGraphViz => {
        Type            => 'SCALAR',
        PostLoadCheck   => sub {
            my $self  = shift;
            my $value = shift;
            return if $value;
            return if GraphViz->require;
            $RT::Logger->debug("You've enabled GraphViz, but we couldn't load the module: $@");
            $self->Set( DisableGraphViz => 1 );
        },
    },
    DisableGD => {
        Type            => 'SCALAR',
        PostLoadCheck   => sub {
            my $self  = shift;
            my $value = shift;
            return if $value;
            return if GD->require;
            $RT::Logger->debug("You've enabled GD, but we couldn't load the module: $@");
            $self->Set( DisableGD => 1 );
        },
    },
    MailCommand => {
        Type    => 'SCALAR',
        PostLoadCheck => sub {
            my $self = shift;
            my $value = $self->Get('MailCommand');
            return if ref($value) eq "CODE"
                or $value =~/^(sendmail|sendmailpipe|qmail|testfile|mbox)$/;
            $RT::Logger->error("Unknown value for \$MailCommand: $value; defaulting to sendmailpipe");
            $self->Set( MailCommand => 'sendmailpipe' );
        },
    },
    HTMLFormatter => {
        Type => 'SCALAR',
        PostLoadCheck => sub { RT::Interface::Email->_HTMLFormatter },
    },
    MailPlugins  => {
        Type => 'ARRAY',
        PostLoadCheck => sub {
            my $self = shift;

            # Make sure Crypt is post-loaded first
            $META{Crypt}{'PostLoadCheck'}->( $self, $self->Get( 'Crypt' ) );

            RT::Interface::Email::Plugins(Add => ["Authz::Default", "Action::Defaults"]);
            RT::Interface::Email::Plugins(Add => ["Auth::MailFrom"])
                  unless RT::Interface::Email::Plugins(Code => 1, Method => "GetCurrentUser");
        },
    },
    Crypt        => {
        Type => 'HASH',
        PostLoadCheck => sub {
            my $self = shift;
            require RT::Crypt;

            for my $proto (RT::Crypt->EnabledProtocols) {
                my $opt = $self->Get($proto);
                if (not RT::Crypt->LoadImplementation($proto)) {
                    $RT::Logger->error("You enabled $proto, but we couldn't load module RT::Crypt::$proto");
                    $opt->{'Enable'} = 0;
                } elsif (not RT::Crypt->LoadImplementation($proto)->Probe) {
                    $opt->{'Enable'} = 0;
                } elsif ($META{$proto}{'PostLoadCheck'}) {
                    $META{$proto}{'PostLoadCheck'}->( $self, $self->Get( $proto ) );
                }

            }

            my $opt = $self->Get('Crypt');
            my @enabled = RT::Crypt->EnabledProtocols;
            my %enabled;
            $enabled{$_} = 1 for @enabled;
            $opt->{'Enable'} = scalar @enabled;
            $opt->{'Incoming'} = [ $opt->{'Incoming'} ]
                if $opt->{'Incoming'} and not ref $opt->{'Incoming'};
            if ( $opt->{'Incoming'} && @{ $opt->{'Incoming'} } ) {
                $RT::Logger->warning("$_ explicitly set as incoming Crypt plugin, but not marked Enabled; removing")
                    for grep {not $enabled{$_}} @{$opt->{'Incoming'}};
                $opt->{'Incoming'} = [ grep {$enabled{$_}} @{$opt->{'Incoming'}} ];
            } else {
                $opt->{'Incoming'} = \@enabled;
            }
            if ( $opt->{'Outgoing'} ) {
                if (not $enabled{$opt->{'Outgoing'}}) {
                    $RT::Logger->warning($opt->{'Outgoing'}.
                                             " explicitly set as outgoing Crypt plugin, but not marked Enabled; "
                                             . (@enabled ? "using $enabled[0]" : "removing"));
                }
                $opt->{'Outgoing'} = $enabled[0] unless $enabled{$opt->{'Outgoing'}};
            } else {
                $opt->{'Outgoing'} = $enabled[0];
            }
        },
    },
    SMIME        => {
        Type => 'HASH',
        PostLoadCheck => sub {
            my $self = shift;
            my $opt = $self->Get('SMIME');
            return unless $opt->{'Enable'};

            if (exists $opt->{Keyring}) {
                unless ( File::Spec->file_name_is_absolute( $opt->{Keyring} ) ) {
                    $opt->{Keyring} = File::Spec->catfile( $RT::BasePath, $opt->{Keyring} );
                }
                unless (-d $opt->{Keyring} and -r _) {
                    $RT::Logger->info(
                        "RT's SMIME libraries couldn't successfully read your".
                        " configured SMIME keyring directory (".$opt->{Keyring}
                        .").");
                    delete $opt->{Keyring};
                }
            }

            if (defined $opt->{CAPath}) {
                if (-d $opt->{CAPath} and -r _) {
                    # directory, all set
                } elsif (-f $opt->{CAPath} and -r _) {
                    # file, all set
                } else {
                    $RT::Logger->warn(
                        "RT's SMIME libraries could not read your configured CAPath (".$opt->{CAPath}.")"
                    );
                    delete $opt->{CAPath};
                }
            }
        },
    },
    GnuPG        => {
        Type => 'HASH',
        PostLoadCheck => sub {
            my $self = shift;
            my $gpg = $self->Get('GnuPG');
            return unless $gpg->{'Enable'};

            my $gpgopts = $self->Get('GnuPGOptions');
            unless ( File::Spec->file_name_is_absolute( $gpgopts->{homedir} ) ) {
                $gpgopts->{homedir} = File::Spec->catfile( $RT::BasePath, $gpgopts->{homedir} );
            }
            unless (-d $gpgopts->{homedir}  && -r _ ) { # no homedir, no gpg
                $RT::Logger->info(
                    "RT's GnuPG libraries couldn't successfully read your".
                    " configured GnuPG home directory (".$gpgopts->{homedir}
                    ."). GnuPG support has been disabled");
                $gpg->{'Enable'} = 0;
                return;
            }

            if ( grep exists $gpg->{$_}, qw(RejectOnMissingPrivateKey RejectOnBadData AllowEncryptDataInDB) ) {
                $RT::Logger->warning(
                    "The RejectOnMissingPrivateKey, RejectOnBadData and AllowEncryptDataInDB"
                    ." GnuPG options are now properties of the generic Crypt configuration. You"
                    ." should set them there instead."
                );
                delete $gpg->{$_} for qw(RejectOnMissingPrivateKey RejectOnBadData AllowEncryptDataInDB);
            }
        }
    },
    GnuPGOptions => { Type => 'HASH' },
    ReferrerWhitelist => { Type => 'ARRAY' },
    EmailDashboardLanguageOrder  => { Type => 'ARRAY' },
    CustomFieldValuesCanonicalizers => { Type => 'ARRAY' },
    WebPath => {
        PostLoadCheck => sub {
            my $self  = shift;
            my $value = shift;

            # "In most cases, you should leave $WebPath set to '' (an empty value)."
            return unless $value;

            # try to catch someone who assumes that you shouldn't leave this empty
            if ($value eq '/') {
                $RT::Logger->error("For the WebPath config option, use the empty string instead of /");
                return;
            }

            # $WebPath requires a leading / but no trailing /, or it can be blank.
            return if $value =~ m{^/.+[^/]$};

            if ($value =~ m{/$}) {
                $RT::Logger->error("The WebPath config option requires no trailing slash");
            }

            if ($value !~ m{^/}) {
                $RT::Logger->error("The WebPath config option requires a leading slash");
            }
        },
    },
    WebDomain => {
        PostLoadCheck => sub {
            my $self  = shift;
            my $value = shift;

            if (!$value) {
                $RT::Logger->error("You must set the WebDomain config option");
                return;
            }

            if ($value =~ m{^(\w+://)}) {
                $RT::Logger->error("The WebDomain config option must not contain a scheme ($1)");
                return;
            }

            if ($value =~ m{(/.*)}) {
                $RT::Logger->error("The WebDomain config option must not contain a path ($1)");
                return;
            }

            if ($value =~ m{:(\d*)}) {
                $RT::Logger->error("The WebDomain config option must not contain a port ($1)");
                return;
            }
        },
    },
    WebPort => {
        PostLoadCheck => sub {
            my $self  = shift;
            my $value = shift;

            if (!$value) {
                $RT::Logger->error("You must set the WebPort config option");
                return;
            }

            if ($value !~ m{^\d+$}) {
                $RT::Logger->error("The WebPort config option must be an integer");
            }
        },
    },
    WebBaseURL => {
        PostLoadCheck => sub {
            my $self  = shift;
            my $value = shift;

            if (!$value) {
                $RT::Logger->error("You must set the WebBaseURL config option");
                return;
            }

            if ($value !~ m{^https?://}i) {
                $RT::Logger->error("The WebBaseURL config option must contain a scheme (http or https)");
            }

            if ($value =~ m{/$}) {
                $RT::Logger->error("The WebBaseURL config option requires no trailing slash");
            }

            if ($value =~ m{^https?://.+?(/[^/].*)}i) {
                $RT::Logger->error("The WebBaseURL config option must not contain a path ($1)");
            }
        },
    },
    WebURL => {
        PostLoadCheck => sub {
            my $self  = shift;
            my $value = shift;

            if (!$value) {
                $RT::Logger->error("You must set the WebURL config option");
                return;
            }

            if ($value !~ m{^https?://}i) {
                $RT::Logger->error("The WebURL config option must contain a scheme (http or https)");
            }

            if ($value !~ m{/$}) {
                $RT::Logger->error("The WebURL config option requires a trailing slash");
            }
        },
    },
    EmailInputEncodings => {
        Type => 'ARRAY',
        PostLoadCheck => sub {
            my $self  = shift;
            my $value = $self->Get('EmailInputEncodings');
            return unless $value && @$value;

            my %seen;
            foreach my $encoding ( grep defined && length, splice @$value ) {
                next if $seen{ $encoding };
                if ( $encoding eq '*' ) {
                    unshift @$value, '*';
                    next;
                }

                my $canonic = Encode::resolve_alias( $encoding );
                unless ( $canonic ) {
                    $RT::Logger->warning("Unknown encoding '$encoding' in \@EmailInputEncodings option");
                }
                elsif ( $seen{ $canonic }++ ) {
                    next;
                }
                else {
                    push @$value, $canonic;
                }
            }
        },
    },
    CustomFieldGroupings => {
        Type            => 'HASH',
        PostLoadCheck   => sub {
            my $config = shift;
            # use scalar context intentionally to avoid not a hash error
            my $groups = $config->Get('CustomFieldGroupings') || {};

            unless (ref($groups) eq 'HASH') {
                RT->Logger->error("Config option \%CustomFieldGroupings is a @{[ref $groups]} not a HASH; ignoring");
                $groups = {};
            }

            for my $class (keys %$groups) {
                my @h;
                if (ref($groups->{$class}) eq 'HASH') {
                    push @h, $_, $groups->{$class}->{$_}
                        for sort {lc($a) cmp lc($b)} keys %{ $groups->{$class} };
                } elsif (ref($groups->{$class}) eq 'ARRAY') {
                    @h = @{ $groups->{$class} };
                } else {
                    RT->Logger->error("Config option \%CustomFieldGroupings{$class} is not a HASH or ARRAY; ignoring");
                    delete $groups->{$class};
                    next;
                }

                $groups->{$class} = [];
                while (@h) {
                    my $group = shift @h;
                    my $ref   = shift @h;
                    if (ref($ref) eq 'ARRAY') {
                        push @{$groups->{$class}}, $group => $ref;
                    } else {
                        RT->Logger->error("Config option \%CustomFieldGroupings{$class}{$group} is not an ARRAY; ignoring");
                    }
                }
            }
            $config->Set( CustomFieldGroupings => %$groups );
        },
    },
    ExternalStorage => {
        Type            => 'HASH',
        PostLoadCheck   => sub {
            my $self = shift;
            my %hash = $self->Get('ExternalStorage');
            return unless keys %hash;

            require RT::ExternalStorage;

            my $backend = RT::ExternalStorage::Backend->new(%hash);
            RT->System->ExternalStorage($backend);
        },
    },
    ChartColors => {
        Type    => 'ARRAY',
    },
    LogoImageHeight => {
        Deprecated => {
            LogLevel => "info",
            Message => "The LogoImageHeight configuration option did not affect display, and has been removed; please remove it from your RT_SiteConfig.pm",
        },
    },
    LogoImageWidth => {
        Deprecated => {
            LogLevel => "info",
            Message => "The LogoImageWidth configuration option did not affect display, and has been removed; please remove it from your RT_SiteConfig.pm",
        },
    },

    ExternalSettings => {
        Obfuscate => sub {
            # Ensure passwords are obfuscated on the System Configuration page
            my ($config, $sources, $user) = @_;

            my $msg = 'Password not printed';
               $msg = $user->loc($msg) if $user and $user->Id;

            for my $source (values %$sources) {
                $source->{pass} = $msg;
            }
            return $sources;
        },
        PostLoadCheck => sub {
            my $self = shift;
            my $settings = shift || {};

            $self->EnableExternalAuth() if keys %$settings > 0;

            my $remove = sub {
                my ($service) = @_;
                delete $settings->{$service};

                $self->Set( 'ExternalAuthPriority',
                        [ grep { $_ ne $service } @{ $self->Get('ExternalAuthPriority') || [] } ] );

                $self->Set( 'ExternalInfoPriority',
                        [ grep { $_ ne $service } @{ $self->Get('ExternalInfoPriority') || [] } ] );
            };

            for my $service (keys %$settings) {
                my %conf = %{ $settings->{$service} };

                if ($conf{type} !~ /^(ldap|db|cookie)$/) {
                    $RT::Logger->error(
                        "Service '$service' in ExternalInfoPriority is not ldap, db, or cookie; removing."
                    );
                    $remove->($service);
                    next;
                }

                next unless $conf{type} eq 'db';

                # Ensure people don't misconfigure DBI auth to point to RT's
                # Users table; only check server/hostname/table, as
                # user/pass might be different (root, for instance)
                no warnings 'uninitialized';
                next unless lc $conf{server} eq lc RT->Config->Get('DatabaseHost') and
                        lc $conf{database} eq lc RT->Config->Get('DatabaseName') and
                        lc $conf{table} eq 'users';

                $RT::Logger->error(
                    "RT::Authen::ExternalAuth should _not_ be configured with a database auth service ".
                    "that points back to RT's internal Users table.  Removing the service '$service'! ".
                    "Please remove it from your config file."
                );

                $remove->($service);
            }
            $self->Set( 'ExternalSettings', $settings );
        },
    },

    ExternalAuthPriority => {
        PostLoadCheck => sub {
            my $self = shift;
            my @values = @{ shift || [] };

            return unless @values or $self->Get('ExternalSettings');

            if (not @values) {
                $RT::Logger->debug("ExternalAuthPriority not defined. Attempting to create based on ExternalSettings");
                $self->Set( 'ExternalAuthPriority', \@values );
                return;
            }
            my %settings;
            if ( $self->Get('ExternalSettings') ){
                %settings = %{ $self->Get('ExternalSettings') };
            }
            else{
                $RT::Logger->error("ExternalSettings not defined. ExternalAuth requires the ExternalSettings configuration option to operate properly");
                return;
            }
            for my $key (grep {not $settings{$_}} @values) {
                $RT::Logger->error("Removing '$key' from ExternalAuthPriority, as it is not defined in ExternalSettings");
            }
            @values = grep {$settings{$_}} @values;
            $self->Set( 'ExternalAuthPriority', \@values );
        },
    },

    ExternalInfoPriority => {
        PostLoadCheck => sub {
            my $self = shift;
            my @values = @{ shift || [] };

            return unless @values or $self->Get('ExternalSettings');

            if (not @values) {
                $RT::Logger->debug("ExternalInfoPriority not defined. User information (including user enabled/disabled) cannot be externally-sourced");
                $self->Set( 'ExternalInfoPriority', \@values );
                return;
            }

            my %settings;
            if ( $self->Get('ExternalSettings') ){
                %settings = %{ $self->Get('ExternalSettings') };
            }
            else{
                $RT::Logger->error("ExternalSettings not defined. ExternalAuth requires the ExternalSettings configuration option to operate properly");
                return;
            }
            for my $key (grep {not $settings{$_}} @values) {
                $RT::Logger->error("Removing '$key' from ExternalInfoPriority, as it is not defined in ExternalSettings");
            }
            @values = grep {$settings{$_}} @values;

            for my $key (grep {$settings{$_}{type} eq "cookie"} @values) {
                $RT::Logger->error("Removing '$key' from ExternalInfoPriority, as cookie authentication cannot be used as an information source");
            }
            @values = grep {$settings{$_}{type} ne "cookie"} @values;

            $self->Set( 'ExternalInfoPriority', \@values );
        },
    },

    ServiceBusinessHours => {
        Type => 'HASH',
        PostLoadCheck   => sub {
            my $self = shift;
            my $config = $self->Get('ServiceBusinessHours');
            for my $name (keys %$config) {
                if ($config->{$name}->{7}) {
                    RT->Logger->error("Config option \%ServiceBusinessHours '$name' erroneously specifies '$config->{$name}->{7}->{Name}' as day 7; Sunday should be specified as day 0.");
                }
            }
        },
    },

    ServiceAgreements => {
        Type => 'HASH',
    },
);
my %OPTIONS = ();
my @LOADED_CONFIGS = ();

=head1 METHODS

=head2 new

Object constructor returns new object. Takes no arguments.

=cut

sub new {
    my $proto = shift;
    my $class = ref($proto) ? ref($proto) : $proto;
    my $self  = bless {}, $class;
    $self->_Init(@_);
    return $self;
}

sub _Init {
    return;
}

=head2 LoadConfigs

Load all configs. First of all load RT's config then load
extensions' config files in alphabetical order.
Takes no arguments.

=cut

sub LoadConfigs {
    my $self    = shift;

    $self->LoadConfig( File => 'RT_Config.pm' );

    my @configs = $self->Configs;
    $self->LoadConfig( File => $_ ) foreach @configs;
    return;
}

=head1 LoadConfig

Takes param hash with C<File> field.
First, the site configuration file is loaded, in order to establish
overall site settings like hostname and name of RT instance.
Then, the core configuration file is loaded to set fallback values
for all settings; it bases some values on settings from the site
configuration file.

B<Note> that core config file don't change options if site config
has set them so to add value to some option instead of
overriding you have to copy original value from core config file.

=cut

sub LoadConfig {
    my $self = shift;
    my %args = ( File => '', @_ );
    $args{'File'} =~ s/(?<!Site)(?=Config\.pm$)/Site/;
    if ( $args{'File'} eq 'RT_SiteConfig.pm' ) {
        my $load = $ENV{RT_SITE_CONFIG} || $args{'File'};
        $self->_LoadConfig( %args, File => $load );
        # to allow load siteconfig again and again in case it's updated
        delete $INC{$load};

        my $dir = $ENV{RT_SITE_CONFIG_DIR} || "$RT::EtcPath/RT_SiteConfig.d";
        my $localdir = $ENV{RT_SITE_CONFIG_DIR} || "$RT::LocalEtcPath/RT_SiteConfig.d";
        for my $file ( sort(<$dir/*.pm>), sort(<$localdir/*.pm>) ) {
            $self->_LoadConfig( %args, File => $file, Site => 1, Extension => '' );
            delete $INC{$file};
        }
    }
    else {
        $self->_LoadConfig(%args);
        delete $INC{$args{'File'}};
    }

    $args{'File'} =~ s/Site(?=Config\.pm$)//;
    $self->_LoadConfig(%args);
    return 1;
}

sub _LoadConfig {
    my $self = shift;
    my %args = ( File => '', @_ );

    my ($is_ext, $is_site);
    if ( defined $args{Site} && defined $args{Extension} ) {
        $is_ext = $args{Extension};
        $is_site = $args{Site};
    }
    elsif ( $args{'File'} eq ($ENV{RT_SITE_CONFIG}||'') ) {
        ($is_ext, $is_site) = ('', 1);
    } else {
        $is_ext = $args{'File'} =~ /^(?!RT_)(?:(.*)_)(?:Site)?Config/ ? $1 : '';
        $is_site = $args{'File'} =~ /SiteConfig/ ? 1 : 0;
    }

    eval {
        package RT;
        local *Set = sub(\[$@%]@) {
            my ( $opt_ref, @args ) = @_;
            my ( $pack, $file, $line ) = caller;
            return $self->SetFromConfig(
                Option     => $opt_ref,
                Value      => [@args],
                Package    => $pack,
                File       => $file,
                Line       => $line,
                SiteConfig => $is_site,
                Extension  => $is_ext,
            );
        };
        local *Plugin = sub {
            my (@new_plugins) = @_;
            @new_plugins = map {s/-/::/g if not /:/; $_} @new_plugins;
            my ( $pack, $file, $line ) = caller;
            return $self->SetFromConfig(
                Option     => \@RT::Plugins,
                Value      => [@RT::Plugins, @new_plugins],
                Package    => $pack,
                File       => $file,
                Line       => $line,
                SiteConfig => $is_site,
                Extension  => $is_ext,
            );
        };
        my @etc_dirs = ($RT::LocalEtcPath);
        push @etc_dirs, RT->PluginDirs('etc') if $is_ext;
        push @etc_dirs, $RT::EtcPath, @INC;
        local @INC = @etc_dirs;
        eval { require $args{'File'} };
        if ( $@ && $@ !~ /did not return a true value/ ) {
            die $@;
        }
    };
    if ($@) {
        return 1 if $is_site && $@ =~ /^Can't locate \Q$args{File}/;
        if ( $is_site || $@ !~ /^Can't locate \Q$args{File}/ ) {
            die qq{Couldn't load RT config file $args{'File'}:\n\n$@};
        }

        my $username = getpwuid($>);
        my $group    = getgrgid($();

        my ( $file_path, $fileuid, $filegid );
        foreach ( $RT::LocalEtcPath, $RT::EtcPath, @INC ) {
            my $tmp = File::Spec->catfile( $_, $args{File} );
            ( $fileuid, $filegid ) = ( stat($tmp) )[ 4, 5 ];
            if ( defined $fileuid ) {
                $file_path = $tmp;
                last;
            }
        }
        unless ($file_path) {
            die
                qq{Couldn't load RT config file $args{'File'} as user $username / group $group.\n}
                . qq{The file couldn't be found in $RT::LocalEtcPath and $RT::EtcPath.\n$@};
        }

        my $message = <<EOF;

RT couldn't load RT config file %s as:
    user: $username 
    group: $group

The file is owned by user %s and group %s.  

This usually means that the user/group your webserver is running
as cannot read the file.  Be careful not to make the permissions
on this file too liberal, because it contains database passwords.
You may need to put the webserver user in the appropriate group
(%s) or change permissions be able to run succesfully.
EOF

        my $fileusername = getpwuid($fileuid);
        my $filegroup    = getgrgid($filegid);
        my $errormessage = sprintf( $message,
            $file_path, $fileusername, $filegroup, $filegroup );
        die "$errormessage\n$@";
    } else {
        # Loaded successfully
        push @LOADED_CONFIGS, {
            as          => $args{'File'},
            filename    => $INC{ $args{'File'} },
            extension   => $is_ext,
            site        => $is_site,
        };
    }
    return 1;
}

sub PostLoadCheck {
    my $self = shift;
    foreach my $o ( grep $META{$_}{'PostLoadCheck'}, $self->Options( Overridable => undef ) ) {
        $META{$o}->{'PostLoadCheck'}->( $self, $self->Get($o) );
    }
}

=head2 Configs

Returns list of config files found in local etc, plugins' etc
and main etc directories.

=cut

sub Configs {
    my $self    = shift;

    my @configs = ();
    foreach my $path ( $RT::LocalEtcPath, RT->PluginDirs('etc'), $RT::EtcPath ) {
        my $mask = File::Spec->catfile( $path, "*_Config.pm" );
        my @files = glob $mask;
        @files = grep !/^RT_Config\.pm$/,
            grep $_ && /^\w+_Config\.pm$/,
            map { s/^.*[\\\/]//; $_ } @files;
        push @configs, sort @files;
    }

    my %seen;
    @configs = grep !$seen{$_}++, @configs;
    return @configs;
}

=head2 LoadedConfigs

Returns a list of hashrefs, one for each config file loaded.  The keys of the
hashes are:

=over 4

=item as

Name this config file was loaded as (relative filename usually).

=item filename

The full path and filename.

=item extension

The "extension" part of the filename.  For example, the file C<RTIR_Config.pm>
will have an C<extension> value of C<RTIR>.

=item site

True if the file is considered a site-level override.  For example, C<site>
will be false for C<RT_Config.pm> and true for C<RT_SiteConfig.pm>.

=back

=cut

sub LoadedConfigs {
    # Copy to avoid the caller changing our internal data
    return map { \%$_ } @LOADED_CONFIGS
}

=head2 Get

Takes name of the option as argument and returns its current value.

In the case of a user-overridable option, first checks the user's
preferences before looking for site-wide configuration.

Returns values from RT_SiteConfig, RT_Config and then the %META hash
of configuration variables's "Default" for this config variable,
in that order.

Returns different things in scalar and array contexts. For scalar
options it's not that important, however for arrays and hash it's.
In scalar context returns references to arrays and hashes.

Use C<scalar> perl's op to force context, especially when you use
C<(..., Argument => RT->Config->Get('ArrayOpt'), ...)>
as perl's '=>' op doesn't change context of the right hand argument to
scalar. Instead use C<(..., Argument => scalar RT->Config->Get('ArrayOpt'), ...)>.

It's also important for options that have no default value(no default
in F<etc/RT_Config.pm>). If you don't force scalar context then you'll
get empty list and all your named args will be messed up. For example
C<(arg1 => 1, arg2 => RT->Config->Get('OptionDoesNotExist'), arg3 => 3)>
will result in C<(arg1 => 1, arg2 => 'arg3', 3)> what is most probably
unexpected, or C<(arg1 => 1, arg2 => RT->Config->Get('ArrayOption'), arg3 => 3)>
will result in C<(arg1 => 1, arg2 => 'element of option', 'another_one' => ..., 'arg3', 3)>.

=cut

sub Get {
    my ( $self, $name, $user ) = @_;

    my $res;
    if ( $user && $user->id && $META{$name}->{'Overridable'} ) {
        my $prefs = $user->Preferences($RT::System);
        $res = $prefs->{$name} if $prefs;
    }
    $res = $OPTIONS{$name}           unless defined $res;
    $res = $META{$name}->{'Default'} unless defined $res;
    return $self->_ReturnValue( $res, $META{$name}->{'Type'} || 'SCALAR' );
}

=head2 GetObfuscated

the same as Get, except it returns Obfuscated value via Obfuscate sub

=cut

sub GetObfuscated {
    my $self = shift;
    my ( $name, $user ) = @_;
    my $obfuscate = $META{$name}->{Obfuscate};

    # we use two Get here is to simplify the logic of the return value
    # configs need obfuscation are supposed to be less, so won't be too heavy

    return $self->Get(@_) unless $obfuscate;

    require Clone;
    my $res = Clone::clone( $self->Get( @_ ) );
    $res = $obfuscate->( $self, $res, $user );
    return $self->_ReturnValue( $res, $META{$name}->{'Type'} || 'SCALAR' );
}

=head2 Set

Set option's value to new value. Takes name of the option and new value.
Returns old value.

The new value should be scalar, array or hash depending on type of the option.
If the option is not defined in meta or the default RT config then it is of
scalar type.

=cut

sub Set {
    my ( $self, $name ) = ( shift, shift );

    my $old = $OPTIONS{$name};
    my $type = $META{$name}->{'Type'} || 'SCALAR';
    if ( $type eq 'ARRAY' ) {
        $OPTIONS{$name} = [@_];
        { no warnings 'once'; no strict 'refs'; @{"RT::$name"} = (@_); }
    } elsif ( $type eq 'HASH' ) {
        $OPTIONS{$name} = {@_};
        { no warnings 'once'; no strict 'refs'; %{"RT::$name"} = (@_); }
    } else {
        $OPTIONS{$name} = shift;
        {no warnings 'once'; no strict 'refs'; ${"RT::$name"} = $OPTIONS{$name}; }
    }
    $META{$name}->{'Type'} = $type;
    $META{$name}->{'PostSet'}->($self, $OPTIONS{$name}, $old)
        if $META{$name}->{'PostSet'};
    if ($META{$name}->{'Deprecated'}) {
        my %deprecated = %{$META{$name}->{'Deprecated'}};
        my $new_var = $deprecated{Instead} || '';
        $self->SetFromConfig(
            Option => \$new_var,
            Value  => [$OPTIONS{$name}],
            %{$self->Meta($name)->{'Source'}}
        ) if $new_var;
        $META{$name}->{'PostLoadCheck'} ||= sub {
            RT->Deprecated(
                Message => "Configuration option $name is deprecated",
                Stack   => 0,
                %deprecated,
            );
        };
    }
    return $self->_ReturnValue( $old, $type );
}

sub _ReturnValue {
    my ( $self, $res, $type ) = @_;
    return $res unless wantarray;

    if ( $type eq 'ARRAY' ) {
        return @{ $res || [] };
    } elsif ( $type eq 'HASH' ) {
        return %{ $res || {} };
    }
    return $res;
}

sub SetFromConfig {
    my $self = shift;
    my %args = (
        Option     => undef,
        Value      => [],
        Package    => 'RT',
        File       => '',
        Line       => 0,
        SiteConfig => 1,
        Extension  => 0,
        @_
    );

    unless ( $args{'File'} ) {
        ( $args{'Package'}, $args{'File'}, $args{'Line'} ) = caller(1);
    }

    my $opt = $args{'Option'};

    my $type;
    my $name = Symbol::Global::Name->find($opt);
    if ($name) {
        $type = ref $opt;
        $name =~ s/.*:://;
    } else {
        $name = $$opt;
        $type = $META{$name}->{'Type'} || 'SCALAR';
    }

    # if option is already set we have to check where
    # it comes from and may be ignore it
    if ( exists $OPTIONS{$name} ) {
        if ( $type eq 'HASH' ) {
            $args{'Value'} = [
                @{ $args{'Value'} },
                @{ $args{'Value'} }%2? (undef) : (),
                $self->Get( $name ),
            ];
        } elsif ( $args{'SiteConfig'} && $args{'Extension'} ) {
            # if it's site config of an extension then it can only
            # override options that came from its main config
            if ( $args{'Extension'} ne $META{$name}->{'Source'}{'Extension'} ) {
                my %source = %{ $META{$name}->{'Source'} };
                push @PreInitLoggerMessages,
                    "Change of config option '$name' at $args{'File'} line $args{'Line'} has been ignored."
                    ." This option earlier has been set in $source{'File'} line $source{'Line'}."
                    ." To overide this option use ". ($source{'Extension'}||'RT')
                    ." site config."
                ;
                return 1;
            }
        } elsif ( !$args{'SiteConfig'} && $META{$name}->{'Source'}{'SiteConfig'} ) {
            # if it's core config then we can override any option that came from another
            # core config, but not site config

            my %source = %{ $META{$name}->{'Source'} };
            if ( $source{'Extension'} ne $args{'Extension'} ) {
                # as a site config is loaded earlier then its base config
                # then we warn only on different extensions, for example
                # RTIR's options is set in main site config
                push @PreInitLoggerMessages,
                    "Change of config option '$name' at $args{'File'} line $args{'Line'} has been ignored."
                    ." It may be ok, but we want you to be aware."
                    ." This option has been set earlier in $source{'File'} line $source{'Line'}."
                ;
            }

            return 1;
        }
    }

    $META{$name}->{'Type'} = $type;
    foreach (qw(Package File Line SiteConfig Extension)) {
        $META{$name}->{'Source'}->{$_} = $args{$_};
    }
    $self->Set( $name, @{ $args{'Value'} } );

    return 1;
}

=head2 Metadata


=head2 Meta

=cut

sub Meta {
    return $META{ $_[1] };
}

sub Sections {
    my $self = shift;
    my %seen;
    my @sections = sort
        grep !$seen{$_}++,
        map $_->{'Section'} || 'General',
        values %META;
    return @sections;
}

sub Options {
    my $self = shift;
    my %args = ( Section => undef, Overridable => 1, Sorted => 1, @_ );
    my @res  = sort keys %META;
    
    @res = grep( ( $META{$_}->{'Section'} || 'General' ) eq $args{'Section'},
        @res 
    ) if defined $args{'Section'};

    if ( defined $args{'Overridable'} ) {
        @res
            = grep( ( $META{$_}->{'Overridable'} || 0 ) == $args{'Overridable'},
            @res );
    }

    if ( $args{'Sorted'} ) {
        @res = sort {
            ($META{$a}->{SortOrder}||9999) <=> ($META{$b}->{SortOrder}||9999)
            || $a cmp $b 
        } @res;
    } else {
        @res = sort { $a cmp $b } @res;
    }
    return @res;
}

=head2 AddOption( Name => '', Section => '', ... )

=cut

sub AddOption {
    my $self = shift;
    my %args = (
        Name            => undef,
        Section         => undef,
        Overridable     => 0,
        SortOrder       => undef,
        Widget          => '/Widgets/Form/String',
        WidgetArguments => {},
        @_
    );

    unless ( $args{Name} ) {
        $RT::Logger->error("Need Name to add a new config");
        return;
    }

    unless ( $args{Section} ) {
        $RT::Logger->error("Need Section to add a new config option");
        return;
    }

    $META{ delete $args{Name} } = \%args;
}

=head2 DeleteOption( Name => '' )

=cut

sub DeleteOption {
    my $self = shift;
    my %args = (
        Name            => undef,
        @_
        );
    if ( $args{Name} ) {
        delete $META{$args{Name}};
    }
    else {
        $RT::Logger->error("Need Name to remove a config option");
        return;
    }
}

=head2 UpdateOption( Name => '' ), Section => '', ... )

=cut

sub UpdateOption {
    my $self = shift;
    my %args = (
        Name            => undef,
        Section         => undef,
        Overridable     => undef,
        SortOrder       => undef,
        Widget          => undef,
        WidgetArguments => undef,
        @_
    );

    my $name = delete $args{Name};

    unless ( $name ) {
        $RT::Logger->error("Need Name to update a new config");
        return;
    }

    unless ( exists $META{$name} ) {
        $RT::Logger->error("Config $name doesn't exist");
        return;
    }

    for my $type ( keys %args ) {
        next unless defined $args{$type};
        $META{$name}{$type} = $args{$type};
    }
    return 1;
}

sub ObjectHasCustomFieldGrouping {
    my $self        = shift;
    my %args        = ( Object => undef, Grouping => undef, @_ );
    my $object_type = RT::CustomField->_GroupingClass($args{Object});
    my $groupings   = RT->Config->Get( 'CustomFieldGroupings' );
    return 0 unless $groupings;
    return 1 if $groupings->{$object_type} && grep { $_ eq $args{Grouping} } @{ $groupings->{$object_type} };
    return 0;
}

# Internal method to activate ExtneralAuth if any ExternalAuth config
# options are set.
sub EnableExternalAuth {
    my $self = shift;

    $self->Set('ExternalAuth', 1);
    require RT::Authen::ExternalAuth;
    return;
}

RT::Base->_ImportOverlays();

1;
