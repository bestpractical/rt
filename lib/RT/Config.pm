# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2025 Best Practical Solutions, LLC
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

use 5.26.3;
use File::Spec ();
use Symbol::Global::Name;
use List::MoreUtils 'uniq';
use Clone ();
use Hash::Merge;
use Hash::Merge::Extra;
my $merger = Hash::Merge->new();
$merger->add_behavior_spec(Hash::Merge::Extra::L_OVERRIDE, "L_OVERRIDE");

# Store log messages generated before RT::Logger is available
our @PreInitLoggerMessages;

=head1 NAME

RT::Config - RT's config

=head1 SYNOPSIS

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

RT extensions can also provide config files. Extensions should
use F<< <NAME>_Config.pm >> and F<< <NAME>_SiteConfig.pm >> names for
config files, where <NAME> is extension name.

B<NOTE>: All options from RT's config and extensions' configs are saved
in one place and thus an extension can override RT's options, but it is not
recommended.

Starting in RT 5, you can modify configuration via the web UI and those
changes are saved in the database. Database configuration options then
overrides options listed in both site and core config files.

=head2 Hash Style Configuration Options

Configuration options that use a Perl hash, like C<$Lifecycles>, are processed
differently from other options. Top-level keys are merged, in the
precedence order of database, site configs, then core configs. This allows you
to create or override selected top-level keys in site configs and not worry
about duplicating all other keys, which will be retrieved from core configs.
So if you add a custom lifecycle, for example, you don't need to copy RT's
C<default> lifecycle in your custom configuration, just add your new one.

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
 WidgetArguments - An argument hash passed to the Widget
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
            Default     => 1, # allow user to unset it on EditConfig.html
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
                                -e File::Spec->catfile( $css_path, $_, 'main.css' )
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
              . "Defaulting to elevator."
            );

            $self->Set('WebDefaultStylesheet', 'elevator');
        },
    },
    WebDefaultThemeMode => {
        Section         => 'General',                #loc
        Overridable     => 1,
        SortOrder       => 4.1,
        Widget          => '/Widgets/Form/Select',
        WidgetArguments => {
            Description => 'Theme Mode',             #loc
            Values      => [qw(auto light dark)],
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
    MessageBoxRichText => {
        Section => 'Ticket composition',
        Overridable => 1,
        SortOrder => 5.1,
        Widget => '/Widgets/Form/Boolean',
        WidgetArguments => {
            Description => 'WYSIWYG message composer' # loc
        }
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
    JSChartColorScheme => {
        Section         => 'General',                       #loc
        Overridable     => 1,
        SortOrder       => 11,
        Widget          => '/Widgets/Form/String',
        WidgetArguments => {
            Description => 'JavaScript chart color scheme', #loc
        },
    },
    EnableURLShortener => {
        Section         => 'General',                       #loc
        Overridable     => 1,
        SortOrder       => 12,
        Widget          => '/Widgets/Form/Boolean',
        WidgetArguments => {
            Description => 'Enable URL shortener',             #loc
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
    QuickCreateCustomFields => {
        Type => 'HASH',
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
    InlineEdit => {
        Section => 'Ticket display',
        Overridable => 1,
        SortOrder => 12,
        Widget => '/Widgets/Form/Boolean',
        WidgetArguments => {
            Description => 'Enable inline edit?' # loc
        }
    },

    InlineEditPanelBehavior => {
        Type            => 'HASH',
        PostLoadCheck   => sub {
            my $config = shift;
            # use scalar context intentionally to avoid not a hash error
            my $behavior = $config->Get('InlineEditPanelBehavior') || {};

            unless (ref($behavior) eq 'HASH') {
                RT->Logger->error("Config option \%InlineEditPanelBehavior is a @{[ref $behavior]} not a HASH; ignoring");
                $behavior = {};
            }

            my %valid = map { $_ => 1 } qw/link click always hide/;
            for my $class (keys %$behavior) {
                if (ref($behavior->{$class}) eq 'HASH') {
                    for my $panel (keys %{ $behavior->{$class} }) {
                        my $value = $behavior->{$class}{$panel};
                        if (!$valid{$value}) {
                            RT->Logger->error("Config option \%InlineEditPanelBehavior{$class}{$panel}, which is '$value', must be one of: " . (join ', ', map { "'$_'" } sort keys %valid) . "; ignoring");
                            delete $behavior->{$class}{$panel};
                        }
                    }
                } else {
                    RT->Logger->error("Config option \%InlineEditPanelBehavior{$class} is not a HASH; ignoring");
                    delete $behavior->{$class};
                    next;
                }
            }

            $config->Set( InlineEditPanelBehavior => %$behavior );
        },
    },
    ShowSearchNavigation => {
        Section     => 'Ticket display',
        Overridable => 1,
        SortOrder   => 13,
        Widget      => '/Widgets/Form/Boolean',
        WidgetArguments => {
            Description => 'Show search navigation', # loc
            Hints       => 'Show search navigation links of "First", "Last", "Prev" and "Next"', # loc
        }
    },
    QuoteSelectedText => {
        Section     => 'Ticket display',
        Overridable => 1,
        SortOrder   => 14,
        Widget      => '/Widgets/Form/Boolean',
        WidgetArguments => {
            Description => 'Quote selected text on ticket update', # loc
        }
    },
    TicketDescriptionRows => {
        Section     => 'Ticket display',
        Overridable => 1,
        SortOrder   => 15,
        Widget      => '/Widgets/Form/Integer',
        WidgetArguments => {
            Description => 'Ticket Description Rows', # loc
            Hints       => 'Rows for the Description edit box on tickets', # loc
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
        Immutable => 1,
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
        Immutable       => 1,
        Widget          => '/Widgets/Form/String',
        PostLoadCheck   => sub {
            my ($self,$value) = @_;
            $RT::Logger->error("your \$Organization setting ($value) appears to contain whitespace.  Please fix this.")
                if $value =~ /\s/;;
        },
    },

    rtname => {
        Immutable => 1,
        Widget    => '/Widgets/Form/String',
    },

    # Internal config options
    DatabaseExtraDSN => {
        Type      => 'HASH',
        Immutable => 1,
    },
    DatabaseAdmin => {
        Immutable => 1,
        Widget    => '/Widgets/Form/String',
    },
    DatabaseHost => {
        Immutable => 1,
        Widget    => '/Widgets/Form/String',
    },
    DatabaseName => {
        Immutable => 1,
        Widget    => '/Widgets/Form/String',
    },
    DatabasePassword => {
        Immutable => 1,
        Widget    => '/Widgets/Form/String',
        Obfuscate => sub {
            my ($config, $sources, $user) = @_;
            return $user->loc('Password not printed');
        },
    },
    DatabasePort => {
        Immutable => 1,
        Widget    => '/Widgets/Form/Integer',
    },
    DatabaseRTHost => {
        Immutable => 1,
        Widget    => '/Widgets/Form/String',
    },
    DatabaseType => {
        Immutable => 1,
        Widget    => '/Widgets/Form/String',
    },
    DatabaseUser => {
        Immutable => 1,
        Widget    => '/Widgets/Form/String',
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
        Widget          => '/Widgets/Form/Boolean',
        PostLoadCheck   => sub {
            my $self  = shift;
            my $value = shift;
            return if $value;
            return if RT::StaticUtil::RequireModule("GraphViz2");
            $RT::Logger->debug("You've enabled GraphViz, but we couldn't load the module: $@");
            $self->Set( DisableGraphViz => 1 );
        },
    },
    MailCommand => {
        Type    => 'SCALAR',
        Widget  => '/Widgets/Form/String',
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
        Widget => '/Widgets/Form/String',
        PostLoadCheck => sub { RT::Interface::Email->_HTMLFormatter },
    },
    Plugins => {
        Immutable => 1,
    },
    RecordBaseClass => {
        Immutable => 1,
        Widget    => '/Widgets/Form/String',
    },
    WebSessionClass => {
        Immutable => 1,
        Widget    => '/Widgets/Form/String',
    },
    DevelMode => {
        Immutable => 1,
        Widget    => '/Widgets/Form/Boolean',
        PostLoadCheck => sub {
            my $self = shift;

            if ( $self->Get('DevelMode') and $self->Get('WebSecureCookies') ) {
                RT->Logger->debug('If you are doing RT development and running a dev server, disabling the $WebSecureCookies option will allow cookies to work without setting up SSL.');
            }
        },
    },
    DisallowExecuteCode => {
        Immutable => 1,
        Widget    => '/Widgets/Form/Boolean',
    },
    MailPlugins  => {
        Type => 'ARRAY',
        Immutable     => 1,
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
        Immutable => 1,
        Invisible => 1,
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
                if (ref($opt->{'Outgoing'}) eq 'HASH') {
                    # Check each entry in the hash
                    foreach my $q (keys(%{$opt->{'Outgoing'}})) {
                        if (not $enabled{$opt->{'Outgoing'}->{$q}}) {
                            if ($q ne '') {
                                $RT::Logger->warning($opt->{'Outgoing'}->{$q}.
                                                     " explicitly set as outgoing Crypt plugin for queue $q, but not marked Enabled; "
                                                     . (@enabled ? "using $enabled[0]" : "removing"));
                            } else {
                                $RT::Logger->warning($opt->{'Outgoing'}->{$q}.
                                                     " explicitly set as default outgoing Crypt plugin, but not marked Enabled; "
                                                     . (@enabled ? "using $enabled[0]" : "removing"));
                            }
                            $opt->{'Outgoing'}->{$q} = $enabled[0];
                        }
                    }
                    # If there's no entry for the default queue, set one
                    if (!$opt->{'Outgoing'}->{''} && scalar(@enabled)) {
                        $RT::Logger->warning("No default outgoing Crypt plugin set; using $enabled[0]");
                        $opt->{'Outgoing'}->{''} = $enabled[0];
                    }
                } else {
                    if (not $enabled{$opt->{'Outgoing'}}) {
                        $RT::Logger->warning($opt->{'Outgoing'}.
                                             " explicitly set as outgoing Crypt plugin, but not marked Enabled; "
                                             . (@enabled ? "using $enabled[0]" : "removing"));
                    }
                    $opt->{'Outgoing'} = $enabled[0] unless $enabled{$opt->{'Outgoing'}};
                }
            } else {
                $opt->{'Outgoing'} = $enabled[0];
            }
        },
    },
    SMIME        => {
        Type => 'HASH',
        Immutable => 1,
        Invisible => 1,
        Obfuscate => sub {
            my ( $config, $value, $user ) = @_;
            $value->{Passphrase} = $user->loc('Password not printed');
            return $value;
        },
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

            if ($opt->{CheckCRL} && ! RT::Crypt::SMIME->SupportsCRLfile) {
                $opt->{CheckCRL} = 0;
                $RT::Logger->warn(
                    "Your version of OpenSSL does not support the -CRLfile option; disabling \$SMIME{CheckCRL}"
                );
            }
        },
    },
    GnuPG        => {
        Type => 'HASH',
        Immutable => 1,
        Invisible => 1,
        Obfuscate => sub {
            my ( $config, $value, $user ) = @_;
            $value->{Passphrase} = $user->loc('Password not printed');
            return $value;
        },
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
    GnuPGOptions => {
        Type      => 'HASH',
        Immutable => 1,
        Invisible => 1,
        Obfuscate => sub {
            my ( $config, $value, $user ) = @_;
            $value->{passphrase} = $user->loc('Password not printed');
            return $value;
        },
    },
    ReferrerWhitelist => { Type => 'ARRAY' },
    EmailDashboardLanguageOrder  => { Type => 'ARRAY' },
    EmailDashboardRows => {
        Type    => 'ARRAY',
    },
    CustomFieldValuesCanonicalizers => { Type => 'ARRAY' },
    CustomFieldValuesValidations => {
        Type => 'ARRAY',
        PostLoadCheck => sub {
            my $self = shift;
            my @values;
            for my $value (@_) {
                if ( defined $value ) {
                    require RT::CustomField;
                    my ($ret, $msg) = RT::CustomField->_IsValidRegex($value);
                    if ($ret) {
                        push @values, $value;
                    }
                    else {
                        $RT::Logger->warning("Invalid regex '$value' in CustomFieldValuesValidations: $msg");
                    }
                }
                else {
                    $RT::Logger->warning('Empty regex in CustomFieldValuesValidations');
                }

            }
            RT->Config->Set( CustomFieldValuesValidations => @values );
        },
    },
    WebPath => {
        Immutable     => 1,
        Widget        => '/Widgets/Form/String',
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
        Immutable     => 1,
        Widget        => '/Widgets/Form/String',
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
        Immutable     => 1,
        Widget        => '/Widgets/Form/Integer',
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
        Immutable     => 1,
        Widget        => '/Widgets/Form/String',
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
        Immutable     => 1,
        Widget => '/Widgets/Form/String',
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
                my %h;
                if (ref($groups->{$class}) eq 'HASH') {
                    for my $key ( keys %{ $groups->{$class} } ) {
                        my $value = $groups->{$class}{$key};
                        if ( ref $value eq 'ARRAY' ) {
                            if ( ref $value->[1] eq 'ARRAY' ) {
                                # 'RT::Ticket' => {
                                #     General => [
                                #         'Network' => [ 'IP Address', 'Router', ],
                                #     ],
                                # }
                                $h{$key} = $value;
                            }
                            else {
                                # 'RT::Ticket' => {
                                #     'Network' => [ 'IP Address', 'Router', ],
                                # }
                                $h{Default} = [
                                    map { $_, $groups->{$class}->{$_} }
                                    sort { lc($a) cmp lc($b) } keys %{ $groups->{$class} }
                                ];
                                last;
                            }
                        }
                        elsif ( ref $value eq 'HASH' ) {
                            # 'RT::Ticket' => {
                            #     General => {
                            #         'Network' => [ 'IP Address', 'Router', ],
                            #     },
                            # }
                            $h{$key} = [ map { $_, $groups->{$class}{$key}{$_} }
                                    sort { lc($a) cmp lc($b) } keys %{ $groups->{$class}{$key} } ];
                        }
                        else {
                            RT->Logger->error(
                                "Config option \%CustomFieldGroupings{$class}{$key} is not a HASH or ARRAY; ignoring");
                        }
                    }
                } elsif (ref($groups->{$class}) eq 'ARRAY') {
                    $h{Default} = $groups->{$class};
                } else {
                    RT->Logger->error("Config option \%CustomFieldGroupings{$class} is not a HASH or ARRAY; ignoring");
                    delete $groups->{$class};
                    next;
                }

                $groups->{$class} = {};
                for my $category ( keys %h ) {
                    my @h = @{ $h{$category} };
                    while (@h) {
                        my $group = shift @h;
                        my $ref   = shift @h;
                        if ( ref($ref) eq 'ARRAY' ) {
                            push @{ $groups->{$class}{$category} }, $group => $ref;
                        }
                        else {
                            RT->Logger->error(
                                "Config option \%CustomFieldGroupings{$class}{$category}{$group} is not an ARRAY; ignoring");
                        }
                    }
                }
            }
            $config->Set( CustomFieldGroupings => %$groups );
        },
    },
    CustomDateRanges => {
        Type            => 'HASH',
        Widget          => '/Widgets/Form/CustomDateRanges',
        PostLoadCheck   => sub {
            my $config = shift;
            # use scalar context intentionally to avoid not a hash error
            my $ranges = $config->Get('CustomDateRanges') || {};

            unless (ref($ranges) eq 'HASH') {
                RT->Logger->error("Config option \%CustomDateRanges is a @{[ref $ranges]} not a HASH");
                return;
            }

            for my $class (keys %$ranges) {
                if (ref($ranges->{$class}) eq 'HASH') {
                    for my $name (keys %{ $ranges->{$class} }) {
                        my $spec = $ranges->{$class}{$name};
                        if (!ref($spec) || ref($spec) eq 'HASH') {
                            # this will produce error messages if parsing fails
                            RT::StaticUtil::RequireModule($class);
                            $class->_ParseCustomDateRangeSpec($name, $spec);
                        }
                        else {
                            RT->Logger->error("Config option \%CustomDateRanges{$class}{$name} is not a string or HASH");
                        }
                    }
                } else {
                    RT->Logger->error("Config option \%CustomDateRanges{$class} is not a HASH");
                }
            }

            my %system_config = %$ranges;
            if ( my $db_config = $config->Get('CustomDateRangesUI') ) {
                for my $type ( keys %$db_config ) {
                    for my $name ( keys %{ $db_config->{$type} || {} } ) {
                        if ( $system_config{$type}{$name} ) {
                            RT->Logger->warning("$type custom date range $name is defined by config file and db");
                        }
                        else {
                            $system_config{$name} = $db_config->{$type}{$name};
                        }
                    }
                }
            }

            for my $type ( keys %system_config ) {
                my $attributes = RT::Attributes->new( RT->SystemUser );
                $attributes->Limit( FIELD => 'Name',       VALUE => 'Pref-CustomDateRanges' );
                $attributes->Limit( FIELD => 'ObjectType', VALUE => 'RT::User' );
                $attributes->OrderBy( FIELD => 'id' );

                while ( my $attribute = $attributes->Next ) {
                    if ( my $content = $attribute->Content ) {
                        for my $name ( keys %{ $content->{$type} || {} } ) {
                            if ( $system_config{$type}{$name} ) {
                                RT->Logger->warning( "$type custom date range $name is defined by system and user #"
                                        . $attribute->ObjectId );
                            }
                        }
                    }
                }
            }
        },
        NoReset => 1,
    },
    CustomDateRangesUI => {
        Type            => 'HASH',
        Widget          => '/Widgets/Form/CustomDateRanges',
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

    ExternalAuth => {
        Immutable => 1,
        Widget    => '/Widgets/Form/Boolean',
    },

    DisablePasswordForAuthToken => {
        Widget => '/Widgets/Form/Boolean',
    },

    ExternalSettings => {
        Immutable     => 1,
        Obfuscate => sub {
            # Ensure passwords are obfuscated on the System Configuration page
            my ($config, $sources, $user) = @_;
            my $msg = $user->loc('Password not printed');

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
        Immutable     => 1,
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
        Immutable     => 1,
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
    PriorityAsString => {
        Type          => 'HASH',
        PostLoadCheck => sub {
            my $self = shift;
            return unless $self->Get('EnablePriorityAsString');
            my $config = $self->Get('PriorityAsString');

            my %map;

            for my $name ( keys %$config ) {
                if ( my $value = $config->{$name} ) {
                    my @list;
                    if ( ref $value eq 'ARRAY' ) {
                        @list = @$value;
                    }
                    elsif ( ref $value eq 'HASH' ) {
                        @list = %$value;
                    }
                    else {
                        RT->Logger->error("Invalid value for $name in PriorityAsString");
                        undef $config->{$name};
                    }

                    while ( my $label = shift @list ) {
                        my $value = shift @list;
                        $map{$label} //= $value;

                        if ( $map{$label} != $value ) {
                            RT->Logger->debug("Priority $label is inconsistent: $map{$label} VS $value");
                        }
                    }

                }
            }

            unless ( keys %map ) {
                RT->Logger->debug("No valid PriorityAsString options");
                $self->Set( 'EnablePriorityAsString', 0 );
            }
        },
    },
    ProcessArticleFields => {
        Type          => 'HASH',
        PostLoadCheck => sub {
            my $self = shift;
            my $config = $self->Get('ProcessArticleFields') or return;

            for my $name ( keys %$config ) {
                if ( my $value = $config->{$name} ) {
                    if ( ref $value eq 'HASH' ) {
                        for my $field ( qw/Field Class/ ) {
                            unless ( defined $value->{$field} && length $value->{$field} ) {
                                RT->Logger->error("Invalid empty $field value for $name in ProcessArticleFields");
                                $config->{$name} = 0; # Disable the queue
                            }
                        }

                        if ( my $field = $value->{Field} ) {
                            unless ( $field =~ /^CF\./
                                || RT::Ticket->can($field)
                                || RT::Ticket->_Accessible( $field => 'read' ) )
                            {
                                RT->Logger->error("Invalid Field value($field) for $name in ProcessArticleFields");
                                $config->{$name} = 0;    # Disable the queue
                            }
                        }
                    }
                    else {
                        if ( $value ) {
                            RT->Logger->error("Invalid value for $name in ProcessArticleFields");
                            $config->{$name} = 0; # Disable the queue
                        }
                    }
                }
            }
        },
    },
    ProcessArticleMapping => {
        Type          => 'HASH',
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
    AssetHideSimpleSearch => {
        Widget => '/Widgets/Form/Boolean',
    },
    AssetMultipleOwner => {
        Widget => '/Widgets/Form/Boolean',
    },
    AssetShowSearchResultCount => {
        Widget => '/Widgets/Form/Boolean',
    },
    AllowUserAutocompleteForUnprivileged => {
        Widget => '/Widgets/Form/Boolean',
    },
    AlwaysDownloadAttachments => {
        Widget => '/Widgets/Form/Boolean',
    },
    AmbiguousDayInFuture => {
        Widget => '/Widgets/Form/Boolean',
    },
    AmbiguousDayInPast => {
        Widget => '/Widgets/Form/Boolean',
    },
    ApprovalRejectionNotes => {
        Widget => '/Widgets/Form/Boolean',
    },
    ArticleOnTicketCreate => {
        Widget => '/Widgets/Form/Boolean',
    },
    ArticleNewestDefaultSearchResultFormat => {
        Widget => '/Widgets/Form/MultilineString',
    },
    ArticleRecentDefaultSearchResultFormat => {
        Widget => '/Widgets/Form/MultilineString',
    },
    AutoCreateNonExternalUsers => {
        Widget => '/Widgets/Form/Boolean',
    },
    AutocompleteOwnersForSearch => {
        Widget => '/Widgets/Form/Boolean',
    },
    CanonicalizeRedirectURLs => {
        Widget => '/Widgets/Form/Boolean',
    },
    CanonicalizeURLsInFeeds => {
        Widget => '/Widgets/Form/Boolean',
    },
    ChartsTimezonesInDB => {
        Widget => '/Widgets/Form/Boolean',
    },
    CheckMoreMSMailHeaders => {
        Widget => '/Widgets/Form/Boolean',
    },
    DateDayBeforeMonth => {
        Widget => '/Widgets/Form/Boolean',
    },
    DisplayTotalTimeWorked => {
        Widget => '/Widgets/Form/Boolean',
    },
    DontSearchFileAttachments => {
        Widget => '/Widgets/Form/Boolean',
    },
    DropLongAttachments => {
        Widget => '/Widgets/Form/Boolean',
    },
    EditCustomFieldsSingleColumn => {
        Widget => '/Widgets/Form/Boolean',
    },
    EnableReminders => {
        Widget => '/Widgets/Form/Boolean',
    },
    EnablePriorityAsString => {
        Widget => '/Widgets/Form/Boolean',
    },
    ExternalStorageDirectLink => {
        Widget => '/Widgets/Form/Boolean',
    },
    ForceApprovalsView => {
        Widget => '/Widgets/Form/Boolean',
    },
    ForwardFromUser => {
        Widget => '/Widgets/Form/Boolean',
    },
    Framebusting => {
        Widget => '/Widgets/Form/Boolean',
    },
    HideArticleSearchOnReplyCreate => {
        Widget => '/Widgets/Form/Boolean',
    },
    HideResolveActionsWithDependencies => {
        Widget => '/Widgets/Form/Boolean',
    },
    HideTimeFieldsFromUnprivilegedUsers => {
        Widget => '/Widgets/Form/Boolean',
    },
    LoopsToRTOwner => {
        Widget => '/Widgets/Form/Boolean',
    },
    MessageBoxIncludeSignature => {
        Widget => '/Widgets/Form/Boolean',
    },
    MessageBoxIncludeSignatureOnComment => {
        Widget => '/Widgets/Form/Boolean',
    },
    OnlySearchActiveTicketsInSimpleSearch => {
        Widget => '/Widgets/Form/Boolean',
    },
    ParseNewMessageForTicketCcs => {
        Widget => '/Widgets/Form/Boolean',
    },
    PreferDateTimeFormatNatural => {
        Widget => '/Widgets/Form/Boolean',
    },
    PreviewScripMessages => {
        Widget => '/Widgets/Form/Boolean',
    },
    RecordOutgoingEmail => {
        Widget => '/Widgets/Form/Boolean',
    },
    RestrictLoginReferrer => {
        Widget => '/Widgets/Form/Boolean',
    },
    RestrictReferrer => {
        Widget => '/Widgets/Form/Boolean',
    },
    SearchResultsAutoRedirect => {
        Widget => '/Widgets/Form/Boolean',
    },
    SelfServiceUseDashboard => {
        Widget => '/Widgets/Form/Boolean',
    },
    ShowBccHeader => {
        Widget => '/Widgets/Form/Boolean',
    },
    ShowEditSystemConfig => {
        Immutable => 1,
        Widget    => '/Widgets/Form/Boolean',
    },
    ShowEditLifecycleConfig => {
        Immutable => 1,
        Widget    => '/Widgets/Form/Boolean',
    },
    ShowMoreAboutPrivilegedUsers => {
        Widget => '/Widgets/Form/Boolean',
    },
    ShowRTPortal => {
        Widget => '/Widgets/Form/Boolean',
    },
    TimeTrackingFirstDayOfWeek => {
        Widget => '/Widgets/Form/String',
    },
    TimeTrackingDisplayCF => {
        Widget => '/Widgets/Form/String',
    },
    ShowRemoteImages => {
        Widget => '/Widgets/Form/Boolean',
    },
    ShowTransactionImages => {
        Widget => '/Widgets/Form/Boolean',
    },
    StoreLoops => {
        Widget => '/Widgets/Form/Boolean',
    },
    StrictLinkACL => {
        Widget => '/Widgets/Form/Boolean',
    },
    SuppressInlineTextFiles => {
        Widget => '/Widgets/Form/Boolean',
    },
    TableAccent => {
        Immutable => 1,
        Widget    => '/Widgets/Form/String',
    },
    TreatAttachedEmailAsFiles => {
        Widget => '/Widgets/Form/Boolean',
    },
    TruncateLongAttachments => {
        Widget => '/Widgets/Form/Boolean',
    },
    TrustHTMLAttachments => {
        Widget => '/Widgets/Form/Boolean',
    },
    UseFriendlyFromLine => {
        Widget => '/Widgets/Form/Boolean',
    },
    UseFriendlyToLine => {
        Widget => '/Widgets/Form/Boolean',
    },
    UseOriginatorHeader => {
        Widget => '/Widgets/Form/Boolean',
    },
    UseSQLForACLChecks => {
        Widget => '/Widgets/Form/Boolean',
    },
    UseTransactionBatch => {
        Widget => '/Widgets/Form/Boolean',
    },
    ValidateUserEmailAddresses => {
        Widget => '/Widgets/Form/Boolean',
    },
    PageLayoutMapping => {
        Type => 'HASH',
        MergeMode => 'recursive',
        Invisible => 1,
    },
    PageLayouts => {
        Type => 'HASH',
        MergeMode => 'recursive',
        Invisible => 1,
    },
    WebFallbackToRTLogin => {
        Widget => '/Widgets/Form/Boolean',
    },
    WebFlushDbCacheEveryRequest => {
        Widget => '/Widgets/Form/Boolean',
    },
    WebHttpOnlyCookies => {
        Widget => '/Widgets/Form/Boolean',
    },
    WebRemoteUserAuth => {
        Widget => '/Widgets/Form/Boolean',
    },
    WebRemoteUserAutocreate => {
        Widget => '/Widgets/Form/Boolean',
    },
    WebRemoteUserContinuous => {
        Widget => '/Widgets/Form/Boolean',
    },
    WebRemoteUserGecos => {
        Widget => '/Widgets/Form/Boolean',
    },
    WebRemoteUserAdditionalMapping => {
        Type => 'HASH',
        PostLoadCheck => sub {
            my $self = shift;
            my $config = $self->Get('WebRemoteUserAdditionalMapping');
            return unless keys %$config;

            my $user_obj = RT::User->new(RT->SystemUser);
            my @valid_attributes = ( $user_obj->WritableAttributes, qw(Privileged Disabled) );
            for my $user_env ( keys %$config ) {
                my $user_attr = $config->{$user_env};
                unless ( grep { $_ eq $user_attr } @valid_attributes ) {
                    RT->Logger->debug("$user_attr is not a valid user attribute, removing from config");
                    delete $config->{$user_env};
                    next;
                }
            }
            $self->Set( 'WebRemoteUserAdditionalMapping', %$config );
        }
    },
    WebSameSiteCookies => {
        Widget => '/Widgets/Form/String',
        PostLoadCheck => sub {
            my $self = shift;
            my $value = $self->Get('WebSameSiteCookies');

            # while both of these detected conditions are against current web standards,
            # web standards have been known to change so these are only logged as warnings.
            if ($value !~ /^(Strict|Lax)$/i) {
                if ($value =~ /^None$/i) {
                    if (not $self->Get('WebSecureCookies')) {
                        RT::Logger->warning("The config option 'WebSameSiteCookies' has a value '$value' and WebSecureCookies is not set, browsers may reject the cookies.");
                    }
                }
                else {
                    RT::Logger->warning("The config option 'WebSameSiteCookies' has a value '$value' not known to be in the standard.");
                }
            }
        },
    },
    WebSecureCookies => {
        Widget => '/Widgets/Form/Boolean',
    },
    WebStrictBrowserCache => {
        Widget => '/Widgets/Form/Boolean',
    },
    WikiImplicitLinks => {
        Widget => '/Widgets/Form/Boolean',
    },
    HideOneTimeSuggestions => {
        Widget => '/Widgets/Form/Boolean',
    },
    LinkArticlesOnInclude => {
        Widget => '/Widgets/Form/Boolean',
    },
    EnableArticleTemplates => {
        Widget => '/Widgets/Form/Boolean',
    },
    ArticleTemplatesWithRequestArgs => {
        Widget => '/Widgets/Form/Boolean',
    },
    SelfServiceCorrespondenceOnly => {
        Widget => '/Widgets/Form/Boolean',
    },
    SelfServiceDownloadUserData => {
        Widget => '/Widgets/Form/Boolean',
    },
    SelfServiceShowGroupTickets => {
        Widget => '/Widgets/Form/Boolean',
    },
    SelfServiceShowArticleSearch => {
        Widget => '/Widgets/Form/Boolean',
    },
    SelfServiceShowUserImages => {
        Widget => '/Widgets/Form/Boolean',
    },
    ShowSearchResultCount => {
        Widget => '/Widgets/Form/Boolean',
    },
    AllowGroupAutocompleteForUnprivileged => {
        Widget => '/Widgets/Form/Boolean',
    },

    AttachmentListCount => {
        Widget => '/Widgets/Form/Integer',
    },
    AutoLogoff => {
        Widget => '/Widgets/Form/Integer',
    },
    BcryptCost => {
        Widget => '/Widgets/Form/Integer',
    },
    DashboardTestEmailLimit => {
        Widget => '/Widgets/Form/String',
    },
    DefaultSummaryRows => {
        Widget => '/Widgets/Form/Integer',
    },
    DropdownMenuLimit => {
        Widget => '/Widgets/Form/Integer',
    },
    ExternalStorageCutoffSize => {
        Widget => '/Widgets/Form/Integer',
    },
    LogoutRefresh => {
        Widget => '/Widgets/Form/Integer',
    },
    MaxAttachmentSize => {
        Widget => '/Widgets/Form/Integer',
    },
    MaxFulltextAttachmentSize => {
        Widget => '/Widgets/Form/Integer',
    },
    MaxUserImageSize => {
        Widget => '/Widgets/Form/Integer',
    },
    MinimumPasswordLength => {
        Widget => '/Widgets/Form/Integer',
    },
    MoreAboutRequestorGroupsLimit => {
        Widget => '/Widgets/Form/Integer',
    },
    TicketsItemMapSize => {
        Widget => '/Widgets/Form/Integer',
    },

    AssetDefaultSearchResultOrderBy => {
        Widget => '/Widgets/Form/String',
    },
    CanonicalizeEmailAddressMatch => {
        Widget => '/Widgets/Form/String',
    },
    CanonicalizeEmailAddressReplace => {
        Widget => '/Widgets/Form/String',
    },
    CommentAddress => {
        Widget => '/Widgets/Form/String',
    },
    CorrespondAddress => {
        Widget => '/Widgets/Form/String',
    },
    DashboardAddress => {
        Widget => '/Widgets/Form/String',
    },
    DashboardSubject => {
        Widget => '/Widgets/Form/String',
    },
    DatabaseQueryTimeout => {
        Immutable => 1,
        Widget    => '/Widgets/Form/String',
        PostLoadCheck => sub {
            my $self = shift;
            if ( defined $ENV{RT_DATABASE_QUERY_TIMEOUT} && length $ENV{RT_DATABASE_QUERY_TIMEOUT} ) {
                RT->Logger->debug(
                    "Env RT_DATABASE_QUERY_TIMEOUT is defined, setting DatabaseQueryTimeout to '$ENV{RT_DATABASE_QUERY_TIMEOUT}'."
                );
                $self->Set('DatabaseQueryTimeout', $ENV{RT_DATABASE_QUERY_TIMEOUT} );
            }
        },
    },
    EmailDashboardIncludeCharts => {
        Widget => '/Widgets/Form/Boolean',
        PostLoadCheck => sub {
            my $self = shift;
            return unless $self->Get('EmailDashboardIncludeCharts');

            if ( RT::StaticUtil::RequireModule('WWW::Mechanize::Chrome') ) {
                my $chrome = RT->Config->Get('ChromePath') || 'chromium';
                if ( !WWW::Mechanize::Chrome->find_executable( $chrome ) ) {
                    RT->Logger->warning("Can't find chrome executable from \$ChromePath value '$chrome', disabling \$EmailDashboardIncludeCharts");
                    $self->Set( 'EmailDashboardIncludeCharts', 0 );
                }
            }
            else {
                RT->Logger->warning('WWW::Mechanize::Chrome is not installed, disabling $EmailDashboardIncludeCharts');
                $self->Set( 'EmailDashboardIncludeCharts', 0 );
            }
        },
    },
    EmailDashboardInlineCSS => {
        Widget => '/Widgets/Form/Boolean',
    },
    ChromePath => {
        Widget => '/Widgets/Form/String',
    },
    ChromeLaunchArguments => {
        Type => 'ARRAY',
    },
    DefaultErrorMailPrecedence => {
        Widget => '/Widgets/Form/String',
    },
    DefaultMailPrecedence => {
        Widget => '/Widgets/Form/String',
    },
    DefaultSearchResultOrderBy => {
        Widget => '/Widgets/Form/String',
    },
    EmailOutputEncoding => {
        Widget => '/Widgets/Form/String',
    },
    FriendlyFromLineFormat => {
        Widget => '/Widgets/Form/String',
    },
    FriendlyToLineFormat => {
        Widget => '/Widgets/Form/String',
    },
    LDAPHost => {
        Widget => '/Widgets/Form/String',
    },
    LDAPUser => {
        Widget => '/Widgets/Form/String',
    },
    LDAPPassword => {
        Widget => '/Widgets/Form/String',
        Obfuscate => sub {
            my ($config, $sources, $user) = @_;
            return $user->loc('Password not printed');
        },
    },
    LDAPBase => {
        Widget => '/Widgets/Form/String',
    },
    LDAPGroupBase => {
        Widget => '/Widgets/Form/String',
    },
    LogDir => {
        Immutable => 1,
        Widget => '/Widgets/Form/String',
    },
    LogToFileNamed => {
        Immutable => 1,
        Widget => '/Widgets/Form/String',
    },
    LogoAltText => {
        Widget => '/Widgets/Form/String',
    },
    LogoLinkURL => {
        Widget => '/Widgets/Form/String',
    },
    LogoURL => {
        Widget => '/Widgets/Form/String',
    },
    SmallLogoURL => {
        Widget => '/Widgets/Form/String',
    },
    LogoutURL => {
        Widget => '/Widgets/Form/String',
    },
    OwnerEmail => {
        Widget => '/Widgets/Form/String',
    },
    QuoteWrapWidth => {
        Widget => '/Widgets/Form/Integer',
    },
    RedistributeAutoGeneratedMessages => {
        Widget          => '/Widgets/Form/Select',
        WidgetArguments => {
            Values      => [qw(0 1 privileged)],
            ValuesLabel => {
                '0' => 'Do not redistribute machine generated correspondences', # loc
                '1' => 'Redistribute machine generated correspondences to all', # loc
                'privileged' => 'Redistribute machine generated correspondences only to privileged users', # loc
            },
        },
    },
    RTSupportEmail => {
        Widget => '/Widgets/Form/String',
    },
    SelfServiceRequestUpdateQueue => {
        Widget => '/Widgets/Form/String',
    },
    SendmailArguments => {
        Widget => '/Widgets/Form/String',
    },
    SendmailBounceArguments => {
        Widget => '/Widgets/Form/String',
    },
    SendmailPath => {
        Widget => '/Widgets/Form/String',
    },
    SetOutgoingMailFrom => {
        Widget => '/Widgets/Form/String',
    },
    Timezone => {
        Widget => '/Widgets/Form/Select',
        WidgetArguments => {
            Callback => sub {
                my $ret = { Values => [], ValuesLabel => {} };

                # all_names doesn't include deprecated names,
                # but those deprecated names still work
                my @names = DateTime::TimeZone->all_names;

                my $cur_value  = RT->Config->Get('Timezone');
                my $file_value = RT->Config->_GetFromFilesOnly('Timezone');

                # Add current values in case they are deprecated.
                for my $value ( $file_value, $cur_value ) {
                    next unless $value;
                    unshift @names, $value unless grep { $_ eq $value } @names;
                }

                my $dt = DateTime->now;
                foreach my $tzname (@names) {
                    push @{ $ret->{Values} }, $tzname;
                    $dt->set_time_zone($tzname);
                    $ret->{ValuesLabel}{$tzname} = $tzname . ' ' . $dt->strftime('%z');
                }
                return $ret;
            },
        },
    },
    VERPPrefix => {
        Widget => '/Widgets/Form/String',
        WidgetArguments => { Hints  => 'rt-', },
    },
    VERPDomain => {
        Widget => '/Widgets/Form/String',
        WidgetArguments => {
            Callback => sub {  return { Hints => RT->Config->Get( 'Organization') } },
        },
    },
    WebImagesURL => {
        Widget => '/Widgets/Form/String',
    },

    AssetDefaultSearchResultOrder => {
        Widget => '/Widgets/Form/Select',
        WidgetArguments => { Values => [qw(ASC DESC)] },
    },
    DefaultSearchResultRowsPerPage => {
        Widget          => '/Widgets/Form/Select',
        WidgetArguments => {
            Callback    => sub {
                my @values = RT->Config->Get('SearchResultsPerPage');
                my %labels = (
                    map { $_ => $_ } @values,
                );

                if ( exists $labels{'0'} ) {
                    $labels{'0'} = 'Unlimited'; # loc
                }

                return { Values => \@values, ValuesLabel => \%labels };
            },
        },
    },
    LogToSyslog => {
        Immutable => 1,
        Widget => '/Widgets/Form/Select',
        WidgetArguments => { Values => [qw(debug info notice warning error critical alert emergency)] },
    },
    LogToSTDERR => {
        Immutable => 1,
        Widget => '/Widgets/Form/Select',
        WidgetArguments => { Values => [qw(debug info notice warning error critical alert emergency)] },
    },
    LogToFile => {
        Immutable => 1,
        Widget => '/Widgets/Form/Select',
        WidgetArguments => { Values => [qw(debug info notice warning error critical alert emergency)] },
    },
    LogStackTraces => {
        Immutable => 1,
        Widget => '/Widgets/Form/Select',
        WidgetArguments => { Values => [qw(debug info notice warning error critical alert emergency)] },
    },
    StatementLog => {
        Widget => '/Widgets/Form/Select',
        WidgetArguments => { Values => ['', qw(debug info notice warning error critical alert emergency)] },
    },

    DefaultCatalog => {
        Widget          => '/Widgets/Form/Select',
        WidgetArguments => {
            Description => 'Default catalog',    #loc
            Default     => 1, # allow user to unset it on EditConfig.html
            Callback    => sub {
                my $ret = { Values => [], ValuesLabel => {} };
                my $c = RT::Catalogs->new( $HTML::Mason::Commands::session{'CurrentUser'} );
                $c->UnLimit;
                while ( my $catalog = $c->Next ) {
                    next unless $catalog->CurrentUserHasRight("CreateAsset");
                    push @{ $ret->{Values} }, $catalog->Id;
                    $ret->{ValuesLabel}{ $catalog->Id } = $catalog->Name;
                }
                return $ret;
            },
        }
    },
    DefaultSearchResultOrder => {
        Widget => '/Widgets/Form/Select',
        WidgetArguments => { Values => [qw(ASC DESC)] },
    },
    SelfServiceUserPrefs => {
        Widget          => '/Widgets/Form/Select',
        WidgetArguments => {
            Values      => [qw(edit-prefs view-info edit-prefs-view-info full-edit)],
            ValuesLabel => {
                'edit-prefs'           => 'Edit Locale and change password',                           # loc
                'view-info'            => 'View all the info',                                         # loc
                'edit-prefs-view-info' => 'View all the info, and edit Locale and change password',    # loc
                'full-edit'            => 'View and update all the info',                              # loc
            },
        },
    },
    AssetDefaultSearchResultFormat => {
        Widget => '/Widgets/Form/SearchFormat',
    },
    AssetSimpleSearchFormat => {
        Widget => '/Widgets/Form/SearchFormat',
    },
    AssetSummaryFormat => {
        Widget => '/Widgets/Form/SearchFormat',
    },
    AssetSummaryRelatedTicketsFormat => {
        Widget => '/Widgets/Form/SearchFormat',
    },
    DefaultSearchResultFormat => {
        Widget => '/Widgets/Form/SearchFormat',
    },
    DefaultSelfServiceSearchResultFormat => {
        Widget => '/Widgets/Form/SearchFormat',
    },
    GroupSearchResultFormat => {
        Widget => '/Widgets/Form/SearchFormat',
    },
    GroupSummaryExtraInfo => {
        Widget => '/Widgets/Form/SearchFormat',
    },
    GroupSummaryTicketListFormat => {
        Widget => '/Widgets/Form/SearchFormat',
    },
    LDAPFilter => {
        Widget => '/Widgets/Form/MultilineString',
    },
    LDAPGroupFilter => {
        Widget => '/Widgets/Form/MultilineString',
    },
    MoreAboutRequestorExtraInfo => {
        Widget => '/Widgets/Form/SearchFormat',
    },
    MoreAboutRequestorTicketListFormat => {
        Widget => '/Widgets/Form/SearchFormat',
    },
    UserAssetExtraInfo => {
        Widget => '/Widgets/Form/SearchFormat',
    },
    UserDataResultFormat => {
        Widget => '/Widgets/Form/SearchFormat',
    },
    UserSearchResultFormat => {
        Widget => '/Widgets/Form/SearchFormat',
    },
    UserSummaryExtraInfo => {
        Widget => '/Widgets/Form/SearchFormat',
    },
    UserSummaryTicketListFormat => {
        Widget => '/Widgets/Form/SearchFormat',
    },
    UserTicketDataResultFormat => {
        Widget => '/Widgets/Form/SearchFormat',
    },
    UserTransactionDataResultFormat => {
        Widget => '/Widgets/Form/SearchFormat',
    },
    LogToSyslogConf => {
        Immutable     => 1,
    },
    LogScripsForUser => {
        Type => 'HASH',
    },
    ShowMobileSite => {
        Widget => '/Widgets/Form/Boolean',
    },
    SVG => {
        Widget => '/Widgets/Form/MultilineString',
    },
    StaticRoots => {
        Type      => 'ARRAY',
        Immutable => 1,
    },
    EmailSubjectTagRegex => {
        Immutable => 1,
    },
    ExtractSubjectTagMatch => {
        Immutable => 1,
    },
    ExtractSubjectTagNoMatch => {
        Immutable => 1,
    },
    WebNoAuthRegex => {
        Immutable => 1,
    },
    SelfServiceRegex => {
        Immutable => 1,
    },
);
my %OPTIONS = ();
our %OVERRIDDEN_OPTIONS;
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

        if ( $is_site && $@ =~ /^Can't locate \Q$args{File}/ ) {

            # Since perl 5.18, the "Can't locate ..." error message contains
            # more details. warn to help debug if there is a permission issue.
            warn qq{Couldn't load RT config file $args{'File'}:\n\n$@} if $@ =~ /Permission denied at/;
            return 1;
        }

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

my $PluginSectionMap = [];
sub RegisterPluginConfig {
    my $self = shift;
    my %args = ( Plugin => '', Content => [], Meta => {}, @_ );

    return unless $args{Plugin} && @{ $args{Content} };

    push @$PluginSectionMap, {
        Name    => $args{Plugin},
        Content => [
            {
                Content => $args{Content},
            },
        ],
    };

    foreach my $key ( %{ $args{Meta} } ) {
        $META{$key} = $args{Meta}->{$key} || {};
    }
}

=head2 SectionMap

A data structure used to breakup the option list into tabs/sections/subsections/options
This is done by parsing RT_Config.pm.

=cut

our $SectionMap = [];
our $SectionMapLoaded = 0;    # so we only load it once

sub LoadSectionMap {
    my $self = shift;

    if ($SectionMapLoaded) {
        return $SectionMap;
    }

    my $ConfigFile = "$RT::EtcPath/RT_Config.pm";
    require Pod::Simple::HTML;
    my $PodParser  = Pod::Simple::HTML->new();

    my $html;
    $PodParser->output_string( \$html );
    $PodParser->parse_file($ConfigFile);

    my $has_subsection;
    while ( $html =~ m{<(h[123]|dt)\b[^>]*>(.*?)</\1>}sg ) {
        my ( $tag, $content ) = ( $1, $2 );
        if ( $tag eq 'h1' ) {
            my ($title) = $content =~ m{<a class='u'\s*name="[^"]*"\s*>([^<]*)</a>};
            next if $title =~ /^(?:NAME|DESCRIPTION)$/;
            push @$SectionMap, { Name => $title, Content => [] };
        }
        elsif (@$SectionMap) {
            if ( $tag eq 'h2' ) {
                my ($title) = $content =~ m{<a class='u'\s*name="[^"]*"\s*>([^<]*)</a>};
                push @{ $SectionMap->[-1]{Content} }, { Name => $title, Content => [] };
                $has_subsection = 0;
            }
            elsif ( $tag eq 'h3' ) {
                my ($title) = $content =~ m{<a class='u'\s*name="[^"]*"\s*>([^<]*)</a>};
                push @{ $SectionMap->[-1]{Content}[-1]{Content} }, { Name => $title, Content => [] };
                $has_subsection ||= 1;
            }
            else {
                # tag is 'dt'
                if ( !$has_subsection ) {

                    # Create an empty subsection to keep the same data structure
                    push @{ $SectionMap->[-1]{Content}[-1]{Content} }, { Name => '', Content => [] };
                    $has_subsection = 1;
                }

                # a single item (dt) can document several options, in separate <code> elements
                my ($name) = $content =~ m{name=".([^"]*)"};
                $name =~ s{,_.}{-}g;    # e.g. DatabaseHost,_$DatabaseRTHost
                while ( $content =~ m{<code>(.)([^<]*)</code>}sg ) {
                    my ( $sigil, $option ) = ( $1, $2 );
                    next unless $sigil =~ m{[\@\%\$]};    # no sigil => this is a value for a select option
                    if ( $META{$option} ) {
                        next if $META{$option}{Invisible};
                    }
                    push @{ $SectionMap->[-1]{Content}[-1]{Content}[-1]{Content} }, { Name => $option, Help => $name };
                }
            }
        }
    }

    push @$SectionMap, {
        Name    => 'Plugins',
        Content => $PluginSectionMap,
    };

    # Remove empty tabs/sections
    for my $tab (@$SectionMap) {
        for my $section ( @{ $tab->{Content} } ) {
            @{ $section->{Content} } = grep { @{ $_->{Content} } } @{ $section->{Content} };
        }
        @{ $tab->{Content} } = grep { @{ $_->{Content} } } @{ $tab->{Content} };
    }
    @$SectionMap = grep { @{ $_->{Content} } } @$SectionMap;

    $SectionMapLoaded = 1;
    return $SectionMap;
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
of configuration variables which provide "Default" settings for this config
variable, in that order.

Returns different things in scalar and array contexts. For scalar
options it's not that important, however for arrays and hash it's.
In scalar context returns references to arrays and hashes.

Use C<scalar> Perl's op to force context, especially when you use
C<(..., Argument => RT->Config->Get('ArrayOpt'), ...)>
as Perl's '=>' op doesn't change context of the right hand argument to
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
    return $self->_ReturnValue( $OVERRIDDEN_OPTIONS{$name}, $META{$name}->{'Type'} || 'SCALAR' )
        if exists $OVERRIDDEN_OPTIONS{$name};

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

    return $self->Get($name) unless $obfuscate;

    my $res = Clone::clone( $self->Get($name) );
    $res = $obfuscate->( $self, $res, $user && $user->Id ? $user : RT->SystemUser );
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

    my $raw_value = $args{'Value'};
    # if option is already set we have to check where
    # it comes from and may be ignore it
    if ( exists $OPTIONS{$name} ) {
        if ( $type eq 'HASH' ) {
            if ( ( $META{$name}{MergeMode} // '' ) eq 'recursive' ) {
                my $merged = $merger->merge(
                    $self->Get($name) || {},
                    { @{ $args{'Value'} }, @{ $args{'Value'} } % 2 ? (undef) : (), },
                );
                $args{'Value'} = [%$merged];
            }
            else {
                $args{'Value'} = [ @{ $args{'Value'} }, @{ $args{'Value'} } % 2 ? (undef) : (), $self->Get($name), ];
            }
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
    foreach (qw(Package File Line SiteConfig Extension Database)) {
        $META{$name}->{'Source'}->{$_} = $args{$_};
    }

    if ( $type eq 'HASH' ) {
        push @{ $META{$name}->{'Sources'} ||= [] },
            { %{ $META{$name}->{'Source'} }, Value => { @$raw_value, @$raw_value % 2 ? undef : () } };
    }

    $self->Set( $name, @{ $args{'Value'} } );

    return 1;
}

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
    my %args        = ( Object => undef, CategoryObj => undef, Grouping => undef, @_ );
    my ( $object_type, $category ) = RT::CustomField->_GroupingClass($args{Object}, $args{CategoryObj} ? $args{CategoryObj}->Name : () );
    my $groupings   = RT->Config->Get( 'CustomFieldGroupings' );
    return 0 unless $groupings;
    return 1
        if $groupings->{$object_type} && grep { $_ eq $args{Grouping} }
        # Fall back to Default groupings if $category is undef or doesn't have specific groupings defined in config.
        @{ $groupings->{$object_type}{$category // 'Default'} // $groupings->{$object_type}{Default} // [] };
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

my $database_config_cache_time = 0;
my %original_setting_from_files;
my $in_config_change_txn = 0;

sub BeginDatabaseConfigChanges {
    $in_config_change_txn = $in_config_change_txn + 1;
}

sub EndDatabaseConfigChanges {
    $in_config_change_txn = $in_config_change_txn - 1;
    if (!$in_config_change_txn) {
        shift->ApplyConfigChangeToAllServerProcesses();
    }
}

sub ApplyConfigChangeToAllServerProcesses {
    my $self = shift;

    return if $in_config_change_txn;

    # first apply locally
    $self->LoadConfigFromDatabase();
    $HTML::Mason::Commands::ReloadScrubber = 1;
    $self->PostLoadCheck;

    # then notify other servers
    RT->System->ConfigCacheNeedsUpdate($database_config_cache_time);
}

sub RefreshConfigFromDatabase {
    my $self = shift;
    if ($in_config_change_txn) {
        RT->Logger->error("It appears that there were unbalanced calls to BeginDatabaseConfigChanges with EndDatabaseConfigChanges; this indicates a software fault");
        $in_config_change_txn = 0;
    }

    if( RT->InstallMode ) { return; } # RT can't load the config in the DB if the DB is not there!
    my $needs_update = RT->System->ConfigCacheNeedsUpdate;
    if ($needs_update > $database_config_cache_time) {
        $self->LoadConfigFromDatabase();
        $HTML::Mason::Commands::ReloadScrubber = 1;
        if ( $ENV{'RT_TEST_DISABLE_CONFIG_CACHE'} ) {
            # When running in test mode, disable the local DB config cache
            # to allow for immediate config changes. Without this, tests needed
            # to sleep for 1 second to allow time for config updates.
            $database_config_cache_time = 0;
        }
        else {
            $database_config_cache_time = $needs_update;
        }
        $self->PostLoadCheck;
    }
}

sub LoadConfigFromDatabase {
    my $self = shift;

    my $settings = RT::Configurations->new(RT->SystemUser);
    # For initial load, we only need to load enabled items.
    # For updates, load all updated items instead.
    if ( $database_config_cache_time ) {
        my $date = RT::Date->new(RT->SystemUser);
        $date->Set( Format => 'unix', Value => $database_config_cache_time );
        $settings->FindAllRows;
        $settings->Limit( FIELD => 'LastUpdated', VALUE => $date->ISO, OPERATOR => '>=' );
    }
    else {
        $settings->LimitToEnabled;
    }

    my $now = time;
    my %disabled;
    while (my $setting = $settings->Next) {
        my $name = $setting->Name;
        my ($value, $error) = $setting->DecodedContent;
        next if $error;

        if (!exists $original_setting_from_files{$name}) {
            $original_setting_from_files{$name} = [
                scalar($self->Get($name)),
                Clone::clone(scalar($self->Meta($name))),
            ];
        }

        $disabled{$name} = $setting->Disabled ? 1 : 0;
        next if $disabled{$name};

        my $meta = $META{$name};
        if ($meta->{'Source'}) {
            my %source = %{ $meta->{'Source'} };

            # No need to set it again if the configuration is the same as before
            next if ( $source{'File'} // '' ) eq 'database' && $source{'Line'} == $setting->Id;

            # are we inadvertantly overriding RT_SiteConfig.pm?
            if ($source{'SiteConfig'} && $source{'File'} ne 'database') {
                push @PreInitLoggerMessages,
                    "Change of config option '$name' at $source{File} line $source{Line} has been overridden by the config setting from the database. "
                    ."Please remove it from $source{File} or from the database to avoid confusion.";
            }
        }

        my $type = $meta->{Type} || 'SCALAR';

        my $val = $type eq 'ARRAY' ? $value
                : $type eq 'HASH'  ? [ %$value ]
                                   : [ $value ];

        # If a hash key is duplicated in both database and config files, database version wins.
        if ($type eq 'HASH') {
            if ( ( $META{$name}{MergeMode} // '' ) eq 'recursive' ) {
                $val = [ %{ $merger->merge( { @$val }, $self->_GetFromFilesOnly($name) || {} ) } ];
            }
            else {
                $val = [ %{ $self->_GetFromFilesOnly($name) || {} }, @$val ];
            }
            $self->Set($name, ());
        }

        $self->SetFromConfig(
            Option     => \$name,
            Value      => $val,
            Package    => 'N/A',
            File       => 'database',
            Line       => $setting->Id,
            Database   => 1,
            SiteConfig => 1,
        );
    }

    # Restore updated items that got disabled.
    for my $name ( grep { $disabled{$_} } keys %disabled ) {
        my ($value, $meta) = @{ $original_setting_from_files{$name} };
        my $type = $meta->{Type} || 'SCALAR';

        if ($type eq 'ARRAY') {
            $self->Set($name, @$value);
        }
        elsif ($type eq 'HASH') {
            $self->Set($name, %$value);
        }
        else {
            $self->Set($name, $value);
        }

        %{ $META{$name} } = %$meta;
    }

    $database_config_cache_time = $now;
}

sub _GetFromFilesOnly {
    my ( $self, $name ) = @_;
    return $original_setting_from_files{$name} ? $original_setting_from_files{$name}[0] : undef;
}

RT::Base->_ImportOverlays();

1;
