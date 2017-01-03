# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2017 Best Practical Solutions, LLC
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


use File::Spec ();

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

RT extensions could also provide thier config files. Extensions should
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
               under on the user Settings page
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
 PostLoadCheck - subref passed the RT::Config object and the current
                 setting of the config option.  Can make further checks
                 (such as seeing if a library is installed) and then change
                 the setting of this or other options in the Config using 
                 the RT::Config option.
   Obfuscate   - subref passed the RT::Config object, current setting of the config option
                 and a user object, can return obfuscated value. it's called in
                 RT->Config->GetObfuscated() 

=cut

our %META = (
    # General user overridable options
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
            Values      => [qw(concise verbose)],
            ValuesLabel => {
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
    WebDefaultStylesheet => {
        Section         => 'General',                #loc
        Overridable     => 1,
        SortOrder       => 4,
        Widget          => '/Widgets/Form/Select',
        WidgetArguments => {
            Description => 'Theme',                  #loc
            # XXX: we need support for 'get values callback'
            Values => [qw(web2 aileron ballard)],
        },
        PostLoadCheck => sub {
            my $self = shift;
            my $value = $self->Get('WebDefaultStylesheet');

            my @comp_roots = RT::Interface::Web->ComponentRoots;
            for my $comp_root (@comp_roots) {
                return if -d $comp_root.'/NoAuth/css/'.$value;
            }

            $RT::Logger->warning(
                "The default stylesheet ($value) does not exist in this instance of RT. "
              . "Defaulting to aileron."
            );

            $self->Set('WebDefaultStylesheet', 'aileron');
        },
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
    MessageBoxWrap => {
        Section         => 'Ticket composition',                #loc
        Overridable     => 1,
        SortOrder       => 8.1,
        Widget          => '/Widgets/Form/Select',
        WidgetArguments => {
            Description => 'Message box wrapping',   #loc
            Values => [qw(SOFT HARD)],
            Hints => "When the WYSIWYG editor is not enabled, this setting determines whether automatic line wraps in the ticket message box are sent to RT or not.",              # loc
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
    SearchResultsRefreshInterval => {
        Section         => 'General',                       #loc
        Overridable     => 1,
        SortOrder       => 9,
        Widget          => '/Widgets/Form/Select',
        WidgetArguments => {
            Description => 'Search results refresh interval',                            #loc
            Values      => [qw(0 120 300 600 1200 3600 7200)],
            ValuesLabel => {
                0 => "Don't refresh search results.",                      #loc
                120 => "Refresh search results every 2 minutes.",          #loc
                300 => "Refresh search results every 5 minutes.",          #loc
                600 => "Refresh search results every 10 minutes.",         #loc
                1200 => "Refresh search results every 20 minutes.",        #loc
                3600 => "Refresh search results every 60 minutes.",        #loc
                7200 => "Refresh search results every 120 minutes.",       #loc
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
            Values      => [qw(0 120 300 600 1200 3600 7200)],
            ValuesLabel => {
                0 => "Don't refresh home page.",                  #loc
                120 => "Refresh home page every 2 minutes.",      #loc
                300 => "Refresh home page every 5 minutes.",      #loc
                600 => "Refresh home page every 10 minutes.",     #loc
                1200 => "Refresh home page every 20 minutes.",    #loc
                3600 => "Refresh home page every 60 minutes.",    #loc
                7200 => "Refresh home page every 120 minutes.",   #loc
            },  
        },  
    },

    # User overridable options for Ticket displays
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
    DeferTransactionLoading => {
        Section         => 'Ticket display',
        Overridable     => 1,
        SortOrder       => 3,
        Widget          => '/Widgets/Form/Boolean',
        WidgetArguments => {
            Description => 'Hide ticket history by default',    #loc
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
    PlainTextPre => {
        Section         => 'Ticket display',
        Overridable     => 1,
        SortOrder       => 5,
        Widget          => '/Widgets/Form/Boolean',
        WidgetArguments => {
            Description => 'add <pre> tag around plain text attachments', #loc
            Hints       => "Use this to protect the format of plain text" #loc
        },
    },
    PlainTextMono => {
        Section         => 'Ticket display',
        Overridable     => 1,
        SortOrder       => 5,
        Widget          => '/Widgets/Form/Boolean',
        WidgetArguments => {
            Description => 'display wrapped and formatted plain text attachments', #loc
            Hints => 'Use css rules to display text monospaced and with formatting preserved, but wrap as needed.  This does not work well with IE6 and you should use the previous option', #loc
        },
    },
    MoreAboutRequestorTicketList => {
        Section         => 'Ticket display',                       #loc
        Overridable     => 1,
        SortOrder       => 6,
        Widget          => '/Widgets/Form/Select',
        WidgetArguments => {
            Description => q|What tickets to display in the 'More about requestor' box|,                #loc
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
            Description => q|Show simplified recipient list on ticket update|,                #loc
        },
    },
    DisplayTicketAfterQuickCreate => {
        Section         => 'Ticket display',
        Overridable     => 1,
        SortOrder       => 8,
        Widget          => '/Widgets/Form/Boolean',
        WidgetArguments => {
            Description => q{Display ticket after "Quick Create"}, #loc
        },
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
                    $RT::Logger->error("Table for full-text index is set to Attachments, not SphinxSE table; disabling");
                    $v->{Enable} = $v->{Indexed} = 0;
                } elsif (not $v->{'MaxMatches'}) {
                    $RT::Logger->warn("No MaxMatches set for full-text index; defaulting to 10000");
                    $v->{MaxMatches} = 10_000;
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
            return if $INC{'GraphViz.pm'};
            local $@;
            return if eval {require GraphViz; 1};
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
            return if $INC{'GD.pm'};
            local $@;
            return if eval {require GD; 1};
            $RT::Logger->debug("You've enabled GD, but we couldn't load the module: $@");
            $self->Set( DisableGD => 1 );
        },
    },
    MailPlugins  => { Type => 'ARRAY' },
    Plugins      => {
        Type => 'ARRAY',
        PostLoadCheck => sub {
            my $self = shift;
            my $value = $self->Get('Plugins');
            # XXX Remove in RT 4.2
            return unless $value and grep {$_ eq "RT::FM"} @{$value};
            warn 'RTFM has been integrated into core RT, and must be removed from your @Plugins';
        },
    },
    GnuPG        => { Type => 'HASH' },
    GnuPGOptions => { Type => 'HASH',
        PostLoadCheck => sub {
            my $self = shift;
            my $gpg = $self->Get('GnuPG');
            return unless $gpg->{'Enable'};
            my $gpgopts = $self->Get('GnuPGOptions');
            unless (-d $gpgopts->{homedir}  && -r _ ) { # no homedir, no gpg
                $RT::Logger->debug(
                    "RT's GnuPG libraries couldn't successfully read your".
                    " configured GnuPG home directory (".$gpgopts->{homedir}
                    ."). PGP support has been disabled");
                $gpg->{'Enable'} = 0;
                return;
            }


            require RT::Crypt::GnuPG;
            unless (RT::Crypt::GnuPG->Probe()) {
                $RT::Logger->debug(
                    "RT's GnuPG libraries couldn't successfully execute gpg.".
                    " PGP support has been disabled");
                $gpg->{'Enable'} = 0;
            }
        }
    },
    ReferrerWhitelist => { Type => 'ARRAY' },
    ResolveDefaultUpdateType => {
        PostLoadCheck => sub {
            my $self  = shift;
            my $value = shift;
            return unless $value;
            $RT::Logger->info('The ResolveDefaultUpdateType config option has been deprecated.  '.
                              'You can change the site default in your %Lifecycles config.');
        }
    },
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
                    warn "Unknown encoding '$encoding' in \@EmailInputEncodings option";
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

    ActiveStatus => {
        Type => 'ARRAY',
        PostLoadCheck => sub {
            my $self  = shift;
            return unless shift;
            # XXX Remove in RT 4.2
            warn <<EOT;
The ActiveStatus configuration has been replaced by the new Lifecycles
functionality. You should set the 'active' property of the 'default'
lifecycle and add transition rules; see RT_Config.pm for documentation.
EOT
        },
    },
    InactiveStatus => {
        Type => 'ARRAY',
        PostLoadCheck => sub {
            my $self  = shift;
            return unless shift;
            # XXX Remove in RT 4.2
            warn <<EOT;
The InactiveStatus configuration has been replaced by the new Lifecycles
functionality. You should set the 'inactive' property of the 'default'
lifecycle and add transition rules; see RT_Config.pm for documentation.
EOT
        },
    },
);
my %OPTIONS = ();

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

=head2 InitConfig

Do nothin right now.

=cut

sub InitConfig {
    my $self = shift;
    my %args = ( File => '', @_ );
    $args{'File'} =~ s/(?<=Config)(?=\.pm$)/Meta/;
    return 1;
}

=head2 LoadConfigs

Load all configs. First of all load RT's config then load
extensions' config files in alphabetical order.
Takes no arguments.

=cut

sub LoadConfigs {
    my $self    = shift;

    $self->InitConfig( File => 'RT_Config.pm' );
    $self->LoadConfig( File => 'RT_Config.pm' );

    my @configs = $self->Configs;
    $self->InitConfig( File => $_ ) foreach @configs;
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
    if ( $args{'File'} eq 'RT_SiteConfig.pm'
        and my $site_config = $ENV{RT_SITE_CONFIG} )
    {
        $self->_LoadConfig( %args, File => $site_config );
    } else {
        $self->_LoadConfig(%args);
    }
    $args{'File'} =~ s/Site(?=Config\.pm$)//;
    $self->_LoadConfig(%args);
    return 1;
}

sub _LoadConfig {
    my $self = shift;
    my %args = ( File => '', @_ );

    my ($is_ext, $is_site);
    if ( $args{'File'} eq ($ENV{RT_SITE_CONFIG}||'') ) {
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
        my @etc_dirs = ($RT::LocalEtcPath);
        push @etc_dirs, RT->PluginDirs('etc') if $is_ext;
        push @etc_dirs, $RT::EtcPath, @INC;
        local @INC = @etc_dirs;
        require $args{'File'};
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

    my $res = $self->Get(@_);
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
    my $name = $self->__GetNameByRef($opt);
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
                warn
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
                warn
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

    our %REF_SYMBOLS = (
            SCALAR => '$',
            ARRAY  => '@',
            HASH   => '%',
            CODE   => '&',
        );

{
    my $last_pack = '';

    sub __GetNameByRef {
        my $self = shift;
        my $ref  = shift;
        my $pack = shift;
        if ( !$pack && $last_pack ) {
            my $tmp = $self->__GetNameByRef( $ref, $last_pack );
            return $tmp if $tmp;
        }
        $pack ||= 'main::';
        $pack .= '::' unless substr( $pack, -2 ) eq '::';

        no strict 'refs';
        my $name = undef;

        # scan $pack's nametable(hash)
        foreach my $k ( keys %{$pack} ) {

            # The hash for main:: has a reference to itself
            next if $k eq 'main::';

            # if the entry has a trailing '::' then
            # it is a link to another name space
            if ( substr( $k, -2 ) eq '::') {
                $name = $self->__GetNameByRef( $ref, $pack eq 'main::'? $k : $pack.$k );
                return $name if $name;
            }

            # entry of the table with references to
            # SCALAR, ARRAY... and other types with
            # the same name
            my $entry = ${$pack}{$k};
            next unless $entry;

            # Inlined constants are simplified in the symbol table --
            # namely, when possible, you only get a reference back in
            # $entry, rather than a full GLOB.  In 5.10, scalar
            # constants began being inlined this way; starting in 5.20,
            # list constants are also inlined.  Notably, ref(GLOB) is
            # undef, but inlined constants are currently either REF,
            # SCALAR, or ARRAY.
            next if ref($entry);

            my $ref_type = ref($ref);

            # regex/arrayref/hashref/coderef are stored in SCALAR glob
            $ref_type = 'SCALAR' if $ref_type eq 'REF';

            my $entry_ref = *{$entry}{ $ref_type };
            next if ref $entry_ref && ref $entry_ref ne ref $ref;
            next unless $entry_ref;

            # if references are equal then we've found
            if ( $entry_ref == $ref ) {
                $last_pack = $pack;
                return ( $REF_SYMBOLS{ $ref_type } || '*' ) . $pack . $k;
            }
        }
        return '';
    }
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
    my @res  = keys %META;
    
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

RT::Base->_ImportOverlays();

1;
