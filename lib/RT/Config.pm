# BEGIN BPS TAGGED BLOCK {{{
# 
# COPYRIGHT:
#  
# This software is Copyright (c) 1996-2008 Best Practical Solutions, LLC 
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

package RT::Config;

use strict;
use warnings;

use File::Spec ();

=head1 NAME

    RT::Config - RT's config

=head1 SYNOPSYS

    # get config object
    use RT::Config;
    my $config = new RT::Config;
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

our %META = (
    WebDefaultStylesheet => {
        Section         => 'General', #loc
        Overridable     => 1,
        Widget          => '/Widgets/Form/Select',
        WidgetArguments => {
            Description => 'Theme', #loc
            # XXX: we need support for 'get values callback'
            Values      => [qw(3.5-default 3.4-compat web2)],
        },
    },
    DefaultSummaryRows => {
        Section         => 'RT at a glance',
        Overridable     => 1,
        Widget          => '/Widgets/Form/Integer',
        WidgetArguments => {
            Description => 'Number of search results', #loc
        },
    },
    MessageBoxWidth => {
        Section         => 'General',
        Overridable     => 1,
        Widget          => '/Widgets/Form/Integer',
        WidgetArguments => {
            Description => 'Message box width', #loc
        },
    },
    MessageBoxHeight => {
        Section         => 'General',
        Overridable     => 1,
        Widget          => '/Widgets/Form/Integer',
        WidgetArguments => {
            Description => 'Message box height', #loc
        },
    },
    MaxInlineBody => {
        Section         => 'Ticket display', #loc
        Overridable     => 1,
        Widget          => '/Widgets/Form/Integer',
        WidgetArguments => {
            Description => 'Maximum inline message length', #loc
            Hints => "Length in characters; Use '0' to show all messages inline, regardless of length" #loc
        },
    },
    OldestTransactionsFirst => {
        Section         => 'Ticket display',
        Overridable     => 1,
        Widget          => '/Widgets/Form/Boolean',
        WidgetArguments => {
            Description => 'Show oldest history first', #loc
        },
    },
    DateTimeFormat      => {
        Section         => 'Locale', #loc
        Overridable     => 1,
        Widget          => '/Widgets/Form/Select',
        WidgetArguments => {
            Description => 'Date format', #loc
            Values      => [qw(DefaultFormat RFC2822 ISO W3CDTF)],
            ValuesLabel => {
                DefaultFormat => 'Tue Dec 25 21:59:12 1995', #loc
                RFC2822       => 'Tue, 25 Dec 1995 21:59:12 -0300', #loc
                ISO           => '1995-11-25 21:59:12', #loc
                W3CDTF        => '1995-11-25T21:59:12Z', #loc
            },
        },
    },
    DisableGraphViz => {
        Type            => 'SCALAR',
        PostLoadCheck   => sub {
            my $value = shift;
            return unless $value;
            return if $INC{'GraphViz'};
            local $@;
            return if eval {require GraphViz; 1};
            warn "You've enabled GraphViz, but we couldn't load the module: $@";
        },
    },
    MailPlugins         => {
        Type            => 'ARRAY'
    },
    GnuPG               => {
        Type            => 'HASH'
    },
    GnuPGOptions        => {
        Type            => 'HASH'
    },
);
my %OPTIONS = ();

=head1 METHODS

=head2 new

Object constructor returns new object. Takes no arguments.

=cut

sub new
{
    my $proto = shift;
    my $class = ref($proto)? ref($proto): $proto;
    my $self = bless {}, $class;
    $self->_Init(@_);
    return $self;
}

sub _Init
{
    return;
}

=head2 InitConfig

=cut

sub InitConfig
{
    my $self = shift;
    my %args = (File => '', @_);
    $args{'File'} =~ s/(?<=Config)(?=\.pm$)/Meta/;
    return 1;
}

=head2 LoadConfigs

Load all configs. First of all load RT's config then load
extensions' config files in alphabetical order.
Takes no arguments.

=cut

sub LoadConfigs
{
    my $self = shift;
    my @configs = $self->Configs;
    $self->InitConfig( File => $_ ) foreach @configs;
    $self->LoadConfig( File => $_ ) foreach @configs;
    $self->PostLoadCheck;
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

sub LoadConfig
{
    my $self = shift;
    my %args = (File => '', @_);
    $args{'File'} =~ s/(?<!Site)(?=Config\.pm$)/Site/;
    if ($args{'File'} eq 'RT_SiteConfig.pm' and my $site_config = $ENV{RT_SITE_CONFIG}) {
        $self->_LoadConfig( %args, File => $site_config );
    }
    else {
        $self->_LoadConfig( %args );
    }
    $args{'File'} =~ s/Site(?=Config\.pm$)//;
    $self->_LoadConfig( %args );
    return 1;
}

sub _LoadConfig
{
    my $self = shift;
    my %args = (File => '', @_);

    my $is_ext = $args{'File'} !~ /^RT_(?:Site)?Config/? 1: 0;
    my $is_site = $args{'File'} =~ /SiteConfig/? 1: 0;

    eval {
        package RT;
        local *Set = sub(\[$@%]@) {
            my ($opt_ref, @args) = @_;
            my ($pack, $file, $line) = caller;
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
        local @INC = ($RT::LocalEtcPath, $RT::EtcPath, @INC);
        require $args{'File'};
    };
    if( $@ ) {
        return 1 if $is_site && $@ =~ qr{^Can't locate \Q$args{File}};
        if ( $is_site || $@ !~ qr{^Can't locate \Q$args{File}} ) {
            die qq{Couldn't load RT config file $args{'File'}:\n\n$@};
        }

        my $username = getpwuid($>);
        my $group = getgrgid($();

        my ($file_path, $fileuid, $filegid);
        foreach ( $RT::LocalEtcPath, $RT::EtcPath, @INC ) {
            my $tmp = File::Spec->catfile( $_, $args{File} );
            ($fileuid,$filegid) = (stat( $tmp ))[4,5];
            if ( defined $fileuid ) {
                $file_path = $tmp;
                last;
            }
        }
        unless ( $file_path ) {
            die qq{Couldn't load RT config file $args{'File'} as user $username / group $group.\n}
               .qq{The file couldn't be find in $RT::LocalEtcPath and $RT::EtcPath.\n$@};
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
        my $filegroup = getgrgid($filegid);
        my $errormessage = sprintf($message,
            $file_path, $fileusername, $filegroup, $filegroup
        );
        die "$errormessage\n$@";
    }
    return 1;
}

sub PostLoadCheck {
    my $self = shift;
    foreach my $o ( grep $META{$_}{'PostLoadCheck'}, $self->Options( Overridable => undef ) ) {
        $META{$o}->{'PostLoadCheck'}->( $self->Get($o) );
    }
}

=head2 Configs

Returns list of the top level configs file names. F<RT_Config.pm> is always
first, other configs are ordered by name.

=cut

sub Configs
{
    my $self = shift;
    my @configs = ();
    foreach my $path( $RT::LocalEtcPath, $RT::EtcPath ) {
        my $mask = File::Spec->catfile($path, "*_Config.pm");
        my @files = glob $mask;
        @files = grep !/^RT_Config\.pm$/,
                 grep $_ && /^\w+_Config\.pm$/,
                 map { s/^.*[\\\/]//; $_ } @files;
        push @configs, @files;
    }

    @configs = sort @configs;
    unshift(@configs, 'RT_Config.pm');

    return @configs;
}

=head2 Get

Takes name of the option as argument and returns its current value.

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
    my ($self, $name, $user) = @_;

    my $res;
    if ( $user&& $user->id && $META{ $name }->{'Overridable'} ) {
        $user = $user->UserObj if $user->isa('RT::CurrentUser');
        my $prefs = $user->Preferences( $RT::System );
        $res = $prefs->{ $name } if $prefs;
    }
    $res = $OPTIONS{ $name } unless defined $res;
    return $self->_ReturnValue($res, $META{ $name }->{'Type'} || 'SCALAR');
}

=head2 Set

Set option's value to new value. Takes name of the option and new value.
Returns old value.

The new value should be scalar, array or hash depending on type of the option.
If the option is not defined in meta or the default RT config then it is of
scalar type.

=cut

sub Set {
    my ($self, $name) = (shift, shift);
    
    my $old = $OPTIONS{ $name };
    my $type = $META{ $name }->{'Type'} || 'SCALAR';
    if ( $type eq 'ARRAY' ) {
        $OPTIONS{$name} = [ @_ ];
        { no strict 'refs';  @{"RT::$name"} = (@_); }
    } elsif ( $type eq 'HASH' ) {
        $OPTIONS{$name} = { @_ };
        { no strict 'refs';  %{"RT::$name"} = (@_); }
    } else {
        $OPTIONS{$name} = shift;
        { no strict 'refs';  ${"RT::$name"} = $OPTIONS{$name}; }
    }
    $META{$name}->{'Type'} = $type;
    return $self->_ReturnValue($old, $type);
}

sub _ReturnValue {
    my ($self, $res, $type) = @_;
    return $res unless wantarray;

    if( $type eq 'ARRAY' ) {
        return @{ $res || [] };
    } elsif( $type eq 'HASH' ) {
        return %{ $res || {} };
    }
    return $res;
}

sub SetFromConfig
{
    my $self = shift;
    my %args = (
        Option => undef,
        Value => [],
        Package => 'RT',
        File => '',
        Line => 0,
        SiteConfig => 1,
        Extension => 0,
        @_
    );

    unless ( $args{'File'} ) {
        ($args{'Package'}, $args{'File'}, $args{'Line'}) = caller(1);
    }

    my $opt = $args{'Option'};

    my $type;
    my $name = $self->__GetNameByRef( $opt );
    if( $name ) {
        $type = ref $opt;
        $name =~ s/.*:://;
    } else {
        $name = $$opt;
        $type = $META{ $name }->{'Type'} || 'SCALAR';
    }

    return 1 if exists $OPTIONS{ $name } && !$args{'SiteConfig'};

    $META{ $name }->{'Type'} = $type;
    foreach ( qw(Package File Line SiteConfig Extension) ) {
        $META{ $name }->{'Source'}->{$_} = $args{$_};
    }
    $self->Set( $name, @{ $args{'Value'} } );

    return 1;
}

{ my $last_pack = '';
sub __GetNameByRef
{
    my $self = shift;
    my $ref = shift;
    my $pack = shift;
    if ( !$pack && $last_pack ) {
        my $tmp = $self->__GetNameByRef( $ref, $last_pack );
        return $tmp if $tmp;
    }
    $pack ||= 'main::';
    $pack .= '::' unless substr($pack, -2) eq '::';

    my %ref_sym = (
        SCALAR => '$',
        ARRAY => '@',
        HASH => '%',
        CODE => '&',
    );
    no strict 'refs';
    my $name = undef;
    # scan $pack name table(hash)
    foreach my $k( keys %{$pack} ) {
        # hash for main:: has reference on itself
        next if $k eq 'main::';

        # if entry has trailing '::' then
        # it is link to other name space
        if ( $k =~ /::$/ ) {
            $name = $self->__GetNameByRef($ref, $k);
            return $name if $name;
        }

        # entry of the table with references to
        # SCALAR, ARRAY... and other types with
        # the same name
        my $entry = ${$pack}{$k};
        next unless $entry;

        # get entry for type we are looking for
        my $entry_ref = *{$entry}{ref($ref)};
        next unless $entry_ref;

        # if references are equal then we've found
        if( $entry_ref == $ref ) {
            $last_pack = $pack;
            return ($ref_sym{ref($ref)} || '*') . $pack . $k;
        }
    }
    return '';
} }

=head2 Metadata


=head2 Meta

=cut

sub Meta {
    return $META{$_[1]};
}

sub Sections {
    my $self = shift;
    my %seen;
    return sort
           grep !$seen{$_}++,
           map $_->{'Section'} || 'General',
           values %META;
}

sub Options {
    my $self = shift;
    my %args = ( Section => undef, Overridable => 1, @_ );
    my @res = sort keys %META;
    @res = grep( ( $META{$_}->{'Section'} || 'General' ) eq $args{'Section'}, @res ) if defined $args{'Section'};
    if ( defined $args{'Overridable'} ) {
        @res = grep( ( $META{$_}->{'Overridable'} || 0 ) == $args{'Overridable'}, @res );
    }
    return @res;
}

=head3 Type

=cut

sub Type {
    my $self = shift;
    my $name = shift;
}

=head3 IsOverridable

=cut

1;
