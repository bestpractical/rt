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
use strict;
use warnings;

package RT::Config;
use File::Spec ();
use Text::Naming::Convention qw/renaming/;

=head1 name

    RT::Config - RT's config

=head1 SYNOPSYS

    # get config object
    use RT::Config;
    my $config = RT::Config->new;
    $config->load_configs;

    # get or set option
    my $rt_web_path = $config->get('WebPath');
    $config->set(EmailOutputEncoding => 'latin1');

    # get config object from RT package
    use RT;
    RT->load_config;
    my $config = RT->config;

=head1 description

C<RT::Config> class provide access to RT's and RT extensions' config files.

RT uses two files for site configuring:

First file is F<RT_Config.pm> - core config file. This file is shipped
with RT distribution and contains default values for all available options.
B<You should never edit this file.>

Second file is F<RT_SiteConfig.pm> - site config file. You can use it
to customize your RT instance. In this file you can override any option
listed in core config file.

RT extensions could also provide thier config files. Extensions should
use F<< <name>_Config.pm >> and F<< <name>_SiteConfig.pm >> names for
config files, where <name> is extension name.

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
 Sortorder   - Within a Section, how should the options be sorted
               for display to the user
 Widget      - Mason component path to widget that should be user 
               to display this config option
 WidgetArguments - An argument hash passed to the Widget
    Description - Friendly description to show the user
    Values      - Arrayref of options (for select Widget)
    values_label - Hashref, key is the Value from the Values
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

=cut



our %META = (
    # General user overridable options
    DefaultQueue => {
        Section         => 'General',
        Overridable     => 1,
        Sortorder       => 1,
        Widget          => '/Widgets/Form/Select',
        WidgetArguments => {
            Description => 'default queue',    #loc
            Callback    => sub {
                my $ret = { values => [], values_label => {} };
                my $q = new RT::Model::Queues(
                    $HTML::Mason::Commands::session{'current_user'} );
                $q->Unlimit;
                while ( my $queue = $q->next ) {
                    next unless $queue->current_user_has_right("CreateTicket");
                    push @{ $ret->{values} }, $queue->id;
                    $ret->{values_label}{ $queue->id } = $queue->name;
                }
                return $ret;
            },
        }
    },
    UsernameFormat => {
        Section         => 'General',
        Overridable     => 1,
        Sortorder       => 2,
        Widget          => '/Widgets/Form/Select',
        WidgetArguments => {
            Description => 'Username format',       # loc
            Values      => [qw(concise verbose)],
            values_label => {
                concise => 'Short usernames',           # loc_left_pair
                verbose => 'Name and email address',    # loc_left_pair
            },
        },
    },
        
    WebDefaultStylesheet => {
        section         => 'General',                #loc
        overridable     => 1,
        sortorder       => 3,
        widget          => '/Widgets/Form/Select',
        widget_arguments => {
            description => 'Theme',                  #loc
                 # XXX: we need support for 'get values callback'
            values => [qw(3.5-default 3.4-compat web2)],
        },
    },
    DefaultSummaryRows => {
        section         => 'RT at a glance',          #loc
        overridable     => 1,
        widget          => '/Widgets/Form/Integer',
        widget_arguments => {
            description => 'Number of search results',    #loc
        },
    },
    MessageBoxRichText => {
        section         => 'General',
        overridable     => 1,
        sortorder       => 4,
        widget          => '/Widgets/Form/Boolean',
        widget_arguments => {
            description => 'WYSIWYG message composer'     # loc
        }
    },
    MessageBoxRichTextHeight => {
        section         => 'General',
        overridable     => 1,
        sortorder       => 5,
        widget          => '/Widgets/Form/Integer',
        widget_arguments => {
            description => 'WYSIWYG composer height',    # loc
        }
    },
    MessageBoxWidth => {
        section         => 'General',
        overridable     => 1,
        sortorder       => 6,
        widget          => '/Widgets/Form/Integer',
        widget_arguments => {
            description => 'Message box width',          #loc
        },
    },
    MessageBoxHeight => {
        section         => 'General',
        overridable     => 1,
        sortorder       => 7,
        widget          => '/Widgets/Form/Integer',
        widget_arguments => {
            description => 'Message box height',         #loc
        },
    },

    # User overridable options for RT at a glance
    DefaultSummaryRows => {
        section         => 'RT at a glance',             #loc
        overridable     => 1,
        widget          => '/Widgets/Form/Integer',
        widget_arguments => {
            Description => 'Number of search results',    #loc
        },
    },

    # User overridable options for Ticket displays
    MaxInlineBody => {
        section => 'Ticket display',    #loc
        overridable     => 1,
        sortorder       => 1,
        widget          => '/Widgets/Form/Integer',
        widget_arguments => {
            description => 'Maximum inline message length',    #loc
            hints =>
"Length in characters; Use '0' to show all messages inline, regardless of length" #loc
        },
    },
    OldestTransactionsFirst => {
        section         => 'Ticket display', #loc
        overridable     => 1,
        sortorder       => 2,
        widget          => '/Widgets/Form/Boolean',
        widget_arguments => {
            description => 'Show oldest transactions first',    #loc
        },
    },
    ShowUnreadMessageNotifications => {
        section         => 'Ticket display',
        overridable     => 1,
        sortorder       => 3,
        widget          => '/Widgets/Form/Boolean',
        widget_arguments => {
            description => 'Notify me of unread messages',    #loc
        },

    },
    PlainTextPre => {
        section         => 'Ticket display',
        overridable     => 1,
        sortorder       => 4,
        widget          => '/Widgets/Form/Boolean',
        widget_arguments => {
            description => 'Use monospace font',
            hints       => "Use fixed-width font to display plaintext messages"
        },
    },
    DateTimeFormat => {
        section         => 'Locale', #loc
        overridable     => 1,
        widget          => '/Widgets/Form/Select',
        widget_arguments => {
            description => 'Date format', #loc
            Callback    => sub {
                my $ret = { values => [], values_label => {} };
                my $now = RT::DateTime->now;
                for my $name (qw/rfc2822 rfc2616 iso iCal /) {
                    push @{ $ret->{values} }, $name;
                    $ret->{values_label}{$name} = "$name (" . $now->$name . ")";
                }
                return $ret;
            },
        },
    },
    EmailFrequency => {
        section         => 'Mail',                   #loc
        overridable     => 1,
        default         => 'Individual messages',
        widget          => '/Widgets/Form/Select',
        widget_arguments => {
            description => 'email delivery',         #loc
            values      => [
                'Individual messages',               #loc
                'Daily digest',                      #loc
                'Weekly digest',                     #loc
                'Suspended'                          #loc
            ]
        }
    },

    # Internal config options
    DisableGraphViz => {
        type          => 'SCALAR',
        post_load_check => sub {
            my $self  = shift;
            my $value = shift;
            return if $value;
            return if $INC{'GraphViz.pm'};
            local $@;
            return if eval { require GraphViz; 1 };
            Jifty->log->debug(
                "You've enabled GraphViz, but we couldn't load the module: $@");
            $self->set( DisableGraphViz => 1 );
        },
    },
    DisableGD => {
        type          => 'SCALAR',
        post_load_check => sub {
            my $self  = shift;
            my $value = shift;
            return if $value;
            return if $INC{'GD.pm'};
            local $@;
            return if eval { require GD; 1 };
            Jifty->log->debug(
                "You've enabled GD, but we couldn't load the module: $@");
            $self->set( DisableGD => 1 );
        },
    },
    MailPlugins  => { type => 'ARRAY' },
    Plugins      => { type => 'ARRAY' },
    GnuPG        => { type => 'HASH' },
    GnuPGOptions => {
        type          => 'HASH',
        post_load_check => sub {
            my $self = shift;
            my $gpg  = $self->get('GnuPG');
            return unless $gpg->{'enable'};
            my $gpgopts = $self->get('GnuPGOptions');
            unless ( -d $gpgopts->{homedir} && -r _ ) {    # no homedir, no gpg
                Jifty->log->debug(
                        "RT's GnuPG libraries couldn't successfully read your"
                      . " configured GnuPG home directory ("
                      . $gpgopts->{homedir}
                      . "). PGP support has been disabled" );
                $gpg->{'enable'} = 0;
                return;
            }
            require RT::Crypt::GnuPG;
            unless ( RT::Crypt::GnuPG->probe() ) {
                Jifty->log->debug(
                    "RT's GnuPG libraries couldn't successfully execute gpg."
                      . " PGP support has been disabled" );
                $gpg->{'enable'} = 0;
            }
          }
    },
);
my %OPTIONS = ();

=head1 METHODS

=head2 new

object constructor returns new Object. Takes no arguments.

=cut

sub new {
    my $proto = shift;
    my $class = ref($proto) ? ref($proto) : $proto;
    my $self  = bless {}, $class;
    $self->_init(@_);
    return $self;
}

sub _init { return; }

=head2 init_config

=cut

sub init_config {
    my $self = shift;
    my %args = ( file => '', @_ );
    $args{'file'} =~ s/(?<=Config)(?=\.pm$)/Meta/;
    return 1;
}

=head2 load_configs

Load all configs. First of all load RT's config then load
extensions' config files in alphabetical order.
Takes no arguments.

Do nothin right now.

=cut

sub load_configs {
    my $self = shift;

    $self->init_config( file => 'RT_Config.pm' );
    $self->load_config( file => 'RT_Config.pm' );

    my @configs = $self->configs;
    $self->init_config( file => $_ ) foreach @configs;
    $self->load_config( file => $_ ) foreach @configs;
    return;
}

=head1 load_config

Takes param hash with C<file> field.
First, the site configuration file is loaded, in order to establish
overall site settings like hostname and name of RT instance.
Then, the core configuration file is loaded to set fallback values
for all settings; it bases some values on settings from the site
configuration file.

B<Note> that core config file don't change options if site config
has set them so to add value to some option instead of
overriding you have to copy original value from core config file.

=cut

sub load_config {
    my $self = shift;
    my %args = ( file => '', @_ );
    $args{'file'} =~ s/(?<!Site)(?=Config\.pm$)/Site/;
    if ( $args{'file'} eq 'RT_SiteConfig.pm'
        and my $site_config = $ENV{RT_SITE_CONFIG} )
    {
        $self->_load_config( %args, file => $site_config );
    } else {
        $self->_load_config(%args);
    }
    $args{'file'} =~ s/Site(?=Config\.pm$)//;
    $self->_load_config(%args);
    return 1;
}

sub _load_config {
    my $self = shift;
    my %args = ( file => '', @_ );

    my $is_ext = $args{'file'} !~ /^RT_(?:Site)?Config/ ? 1 : 0;
    my $is_site = $args{'file'} =~ /SiteConfig/ ? 1 : 0;

    eval {
        package RT;
        local *set = sub(\[$@%]@) {
            my ( $opt_ref, @args ) = @_;
            my ( $pack, $file, $line ) = caller;
            return $self->set_from_config(
                option     => $opt_ref,
                value      => [@args],
                package    => $pack,
                file       => $file,
                line       => $line,
                site_config => $is_site,
                extension  => $is_ext,
            );
        };
        my @etc_dirs = ($RT::LocalEtcPath);
        push @etc_dirs, RT->plugin_dirs('etc') if $is_ext;
        push @etc_dirs, $RT::EtcPath, @INC;
        local @INC = @etc_dirs;
        require $args{'file'};
    };
    if ($@) {
        return 1 if $is_site && $@ =~ qr{^Can't locate \Q$args{file}};
        if ( $is_site || $@ !~ qr{^Can't locate \Q$args{file}} ) {
            die qq{Couldn't load RT config file $args{'file'}:\n\n$@};
        }

        my $username = getpwuid($>);
        my $group    = getgrgid($();

        my ( $file_path, $fileuid, $filegid );
        foreach ( $RT::LocalEtcPath, $RT::EtcPath, @INC ) {
            my $tmp = File::Spec->catfile( $_, $args{file} );
            ( $fileuid, $filegid ) = ( stat($tmp) )[ 4, 5 ];
            if ( defined $fileuid ) {
                $file_path = $tmp;
                last;
            }
        }
        unless ($file_path) {
            die
qq{Couldn't load RT config file $args{'file'} as user $username / group $group.\n}
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
        my $errormessage = sprintf( $message, $file_path, $fileusername, $filegroup, $filegroup );
        die "$errormessage\n$@";
    }
    return 1;
}

=head2 configs

Returns list of config files found in local etc, plugins' etc
and main etc directories.


=cut

sub configs {
    my $self = shift;

    
    my @configs = ();
    foreach my $path ( $RT::LocalEtcPath, RT->plugin_dirs('etc'), $RT::EtcPath )
    {
        my $mask = File::Spec->catfile( $path, "*_Config.pm" );
        my @files = glob $mask;
        @files = grep !/^RT_Config\.pm$/, grep $_ && /^\w+_Config\.pm$/, map { s/^.*[\\\/]//; $_ } @files;
        push @configs, sort @files;
        
    }

    my %seen;
    @configs = grep !$seen{$_}++, @configs;
    
    return @configs;
}

sub post_load_check {
    my $self = shift;
    foreach my $o (
        grep $META{$_}{'post_load_check'},
        $self->options( overridable => undef )
      )
    {
        $META{$o}->{'post_load_check'}->( $self, $self->get($o) );
    }
}

=head2 get

Takes name of the option as argument and returns its current value.

In the case of a user-overridable option, first checks the user's preferences before looking for site-wide configuration.

Returns values from RT_SiteConfig, RT_Config and then the %META hash of configuration variables's "Default" for this config variable, in that order.


Returns different things in scalar and array contexts. For scalar
options it's not that important, however for arrays and hash it's.
In scalar context returns references to arrays and hashes.

Use C<scalar> perl's op to force context, especially when you use
C<(..., Argument => RT->config->get('ArrayOpt'), ...)>
as perl's '=>' op doesn't change context of the right hand argument to
scalar. Instead use C<(..., Argument => scalar RT->config->get('ArrayOpt'), ...)>.

It's also important for options that have no default value(no default
in F<etc/RT_Config.pm>). If you don't force scalar context then you'll
get empty list and all your named args will be messed up. For example
C<(arg1 => 1, arg2 => RT->config->get('OptionDoesNotExist'), arg3 => 3)>
will result in C<(arg1 => 1, arg2 => 'arg3', 3)> what is most probably
unexpected, or C<(arg1 => 1, arg2 => RT->config->get('ArrayOption'), arg3 => 3)>
will result in C<(arg1 => 1, arg2 => 'element of option', 'another_one' => ..., 'arg3', 3)>.

=cut

sub get {
    my ( $self, $name, $user ) = @_;

    if ( $name ne 'rtname' && $name !~ /[A-Z]/ ) {
        # we need to rename it to be UpperCamelCase
        $name = renaming( $name, { convention => 'UpperCamelCase' } );
    }

    my $res;
    if ( $user && $user->id && $META{$name}->{'overridable'} ) {
        $user = $user->user_object if $user->isa('RT::CurrentUser');
        my $prefs = $user->preferences( RT->system );
        $res = $prefs->{$name} if $prefs;
    }
    $res = $OPTIONS{$name}           unless defined $res;
    $res = $META{$name}->{'Default'} unless defined $res;
    return $self->_return_value( $res, $META{$name}->{'type'} || 'SCALAR' );
}

=head2 set

Set option's value to new value. Takes name of the option and new value.
Returns old value.

The new value should be scalar, array or hash depending on type of the option.
If the option is not defined in meta or the default RT config then it is of
scalar type.

=cut

sub set {
    my ( $self, $name ) = ( shift, shift );

    if ( $name ne 'rtname' && $name !~ /[A-Z]/ ) {
        # we need to rename it to be UpperCamelCase
        $name = renaming( $name, { convention => 'UpperCamelCase' } );
    }

    my $old = $OPTIONS{$name};
    my $type = $META{$name}->{'type'} || 'SCALAR';
    if ( $type eq 'ARRAY' ) {
        $OPTIONS{$name} = [@_];
        { no warnings 'once'; no strict 'refs'; @{"RT::$name"} = (@_); }
    } elsif ( $type eq 'HASH' ) {
        $OPTIONS{$name} = {@_};
        { no warnings 'once'; no strict 'refs'; %{"RT::$name"} = (@_); }
    } else {
        $OPTIONS{$name} = shift;
        {
            no warnings 'once';
            no strict 'refs';
            ${"RT::$name"} = $OPTIONS{$name};
        }
    }
    $META{$name}->{'type'} = $type;
    return $self->_return_value( $old, $type );
}

sub _return_value {
    my ( $self, $res, $type ) = @_;
    return $res unless wantarray;

    if ( $type eq 'ARRAY' ) {
        return @{ $res || [] };
    } elsif ( $type eq 'HASH' ) {
        return %{ $res || {} };
    }
    return $res;
}

sub set_from_config {
    my $self = shift;
    my %args = (
        option     => undef,
        value      => [],
        package    => 'RT',
        file       => '',
        line       => 0,
        site_config => 1,
        extension  => 0,
        @_
    );

    unless ( $args{'file'} ) {
        ( $args{'package'}, $args{'file'}, $args{'line'} ) = caller(1);
    }

    my $opt = $args{'option'};

    my $type;
    my $name = $self->__getname_by_ref($opt);
    if ($name) {
        $type = ref $opt;
        $name =~ s/.*:://;
    } else {
        $name = $$opt;
        $type = $META{$name}->{'type'} || 'SCALAR';
    }

    return 1 if exists $OPTIONS{$name} && !$args{'site_config'};

    $META{$name}->{'type'} = $type;
    foreach (qw(package file line site_config extension)) {
        $META{$name}->{'Source'}->{$_} = $args{$_};
    }
    $self->set( $name, @{ $args{'value'} } );

    return 1;
}

{
    my $last_pack = '';

    sub __getname_by_ref {
        my $self = shift;
        my $ref  = shift;
        my $pack = shift;
        if ( !$pack && $last_pack ) {
            my $tmp = $self->__getname_by_ref( $ref, $last_pack );
            return $tmp if $tmp;
        }
        $pack ||= 'main::';
        $pack .= '::' unless substr( $pack, -2 ) eq '::';

        my %ref_sym = (
            SCALAR => '$',
            ARRAY  => '@',
            HASH   => '%',
            CODE   => '&',
        );
        no strict 'refs';
        my $name = undef;

        # scan $pack's nametable(hash)
        foreach my $k ( keys %{$pack} ) {

            # hash for main:: has reference on itself
            next if $k eq 'main::';

            # if entry has trailing '::' then
            # it is link to other name space
            if ( $k =~ /::$/ ) {
                $name = $self->__getname_by_ref( $ref, $k );
                return $name if $name;
            }

            # entry of the table with references to
            # SCALAR, ARRAY... and other types with
            # the same name
            my $entry = ${$pack}{$k};
            next unless $entry;

            # get entry for type we are looking for
            # XXX skip references to scalars or other references.
            # Otherwie 5.10 goes boom. may be we should skip any
            # reference
            return if ref($entry) eq 'SCALAR' || ref($entry) eq 'REF';
            my $entry_ref = *{$entry}{ ref($ref) };
            next unless $entry_ref;

            # if references are equal then we've found
            if ( $entry_ref == $ref ) {
                $last_pack = $pack;
                return ( $ref_sym{ ref($ref) } || '*' ) . $pack . $k;
            }
        }
        return '';
    }
}

=head2 metadata


=head2 meta

=cut

sub meta {
    return $META{ $_[1] };
}

sub sections {
    my $self = shift;
    my %seen;
    return sort
        grep !$seen{$_}++, map $_->{'section'} || 'General', values %META;
}

sub options {
    my $self = shift;
    my %args = ( section => undef, overridable => 1, @_ );
    my @res  = sort {
        ( $META{$a}->{sortorder} || 9999 )
          <=> ( $META{$b}->{sortorder} || 9999 )
          || $a cmp $b
    } keys %META;
    
    @res = grep( ( $META{$_}->{'section'} || 'General' ) eq $args{'section'}, @res )
        if defined $args{'section'};
    if ( defined $args{'overridable'} ) {
        @res = grep( ( $META{$_}->{'overridable'} || 0 ) == $args{'overridable'}, @res );
    }
    return @res;
}

1;
