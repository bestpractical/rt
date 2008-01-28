
use warnings;
use strict;

package RT;

use RT::CurrentUser;

use strict;
use warnings;
use File::Spec ();
use vars qw($Config $System $nobody $Handle );
our $VERSION = '3.7.14';

our $BasePath         = '/home/jesse/svk/3.999-DANGEROUS';
our $EtcPath          = '/home/jesse/svk/3.999-DANGEROUS/etc';
our $BinPath          = '/home/jesse/svk/3.999-DANGEROUS/bin';
our $VarPath          = '/home/jesse/svk/3.999-DANGEROUS/var';
our $LocalPath        = '/home/jesse/svk/3.999-DANGEROUS/local';
our $LocalLibPath     = '/home/jesse/svk/3.999-DANGEROUS/local/lib';
our $LocalEtcPath     = '/home/jesse/svk/3.999-DANGEROUS/local/etc';
our $LocalLexiconPath = '/home/jesse/svk/3.999-DANGEROUS/local/po';
our $LocalPluginPath  = $LocalPath . "/plugins";

# $MasonComponentRoot is where your rt instance keeps its mason html files

our $MasonComponentRoot = '/home/jesse/svk/3.999-DANGEROUS/html';

# $MasonLocalComponentRoot is where your rt instance keeps its site-local
# mason html files.

our $MasonLocalComponentRoot = '/home/jesse/svk/3.999-DANGEROUS/local/html';

# $MasonDataDir Where mason keeps its datafiles

our $MasonDataDir = '/home/jesse/svk/3.999-DANGEROUS/var/mason_data';

# RT needs to put session data (for preserving state between connections
# via the web interface)
our $MasonSessionDir = '/home/jesse/svk/3.999-DANGEROUS/var/session_data';

=head1 name

RT - Request Tracker

=head1 SYNOPSIS

A fully featured request tracker package

=head1 DESCRIPTION

=head2 INITIALIZATION

=head2 load_config

Load RT's config file.  First, the site configuration file
(F<RT_SiteConfig.pm>) is loaded, in order to establish overall site
settings like hostname and name of RT instance.  Then, the core
configuration file (F<RT_Config.pm>) is loaded to set fallback values
for all settings; it bases some values on settings from the site
configuration file.

In order for the core configuration to not override the site's
settings, the function C<Set> is used; it only sets values if they
have not been set already.

=cut

sub load_config {
    require RT::Config;
    $Config = RT::Config->new();
    $Config->load_configs;

    #    require RT::I18N;

    # RT::Essentials mistakenly recommends that WebPath be set to '/'.
    # If the user does that, do what they mean.
    $RT::WebPath = '' if ( $RT::WebPath eq '/' );

    RT::I18N->init;
}

sub config {
    my $self = shift;
    return $RT::Config;
}

=head2 Init

L<Connect to the database /connect_to_database>, L<initilizes system objects /InitSystemObjects>,
L<preloads classes /InitClasses> 

=cut

sub init {

    #    CheckPerlRequirements();
    #Get a database connection
    init_system_objects();
    init_plugins();
}

# Signal handlers
## This is the default handling of warnings and die'ings in the code
## (including other used modules - maybe except for errors catched by
## Mason).  It will log all problems through the standard logging
## mechanism (see above).

sub check_perl_requirements {
    if ( $^V < 5.008003 ) {
        die sprintf
            "RT requires Perl v5.8.3 or newer.  Your current Perl is v%vd\n",
            $^V;
    }

    local ($@);
    eval {
        my $x = '';
        my $y = \$x;
        require Scalar::Util;
        Scalar::Util::weaken($y);
    };
    if ($@) {
        die <<"EOF";

RT requires the Scalar::Util module be built with support for  the 'weaken'
function. 

It is sometimes the case that operating system upgrades will replace 
a working Scalar::Util with a non-working one. If your system was working
correctly up until now, this is likely the cause of the problem.

Please reinstall Scalar::Util, being careful to let it build with your C 
compiler. Ususally this is as simple as running the following command as
root.

    perl -MCPAN -e'install Scalar::Util'

EOF

    }
}

=head2 InitSystemObjects

Initializes system objects: C<RT->system>, C<RT->system_user>
and C<RT->nobody>.

=cut

sub init_system_objects {

    #RT's "nobody user" is a genuine database user. its ID lives here.
    $nobody = RT::CurrentUser->new( name => 'Nobody' );
    Carp::confess
        "Could not load 'Nobody' User. This usually indicates a corrupt or missing RT database"
        unless $nobody->id;

    $System = RT::System->new();
}

=head1 CLASS METHODS

=head2 Config

Returns the current L<config object RT::Config>, but note that
you must L<load config /load_config> first otherwise this method
returns undef.

Method can be called as class method.

=cut

=head2 DatabaseHandle

Returns the current L<database handle object RT::Handle>.


=cut

sub database_handle { return $Handle }

=head2 System

Returns the current L<system object RT::System>. See also
L</InitSystemObjects>.

=cut

sub system { return RT::System->new }

=head2 system_user

Returns the system user's object, it's object of
L<RT::CurrentUser> class that represents the system. See also
L</InitSystemObjects>.

=cut

sub system_user {
    my $system_user = RT::CurrentUser->new( name => 'RT_System' );
    $system_user->is_superuser(1);
    return $system_user;

}

=head2 Nobody

Returns object of Nobody. It's object of L<RT::CurrentUser> class
that represents a user who can own ticket and nothing else. See
also L</InitSystemObjects>.

=cut

sub nobody { return $nobody }

=head2 Plugins

Returns a listref of all Plugins currently configured for this RT instance.
You can define plugins by adding them to the @Plugins list in your RT_SiteConfig

=cut

our @PLUGINS = ();

sub plugins {
    my $self = shift;
    @PLUGINS = $self->init_plugins unless (@PLUGINS);
    return \@PLUGINS;
}

=head2 InitPlugins

Initialze all Plugins found in the RT configuration file, setting up their lib and HTML::Mason component roots.

=cut

sub init_plugins {
    my $self = shift;
    my @plugins;
    use RT::Plugin;
    foreach my $plugin ( RT->config->get('Plugins') ) {
        next unless $plugin;
        my $plugindir = $plugin;
        $plugindir =~ s/::/-/g;
        unless ( -d $RT::LocalPluginPath . "/$plugindir" ) {
            Jifty->log->fatal(
                "Plugin $plugindir not found in $RT::LocalPluginPath");
        }

        # Splice the plugin's lib dir into @INC;
        my @tmp_inc;

        for (@INC) {
            if ( $_ eq $RT::LocalLibPath ) {
                        push @tmp_inc, $_,
                            $RT::LocalPluginPath . "/$plugindir";
                } else {
                        push @tmp_inc, $_;
                }
        }

        @INC = @tmp_inc;
        $plugin->require;
        die $UNIVERSAL::require::ERROR if ($UNIVERSAL::require::ERROR);
        push @plugins, RT::Plugin->new( name => $plugin );
    }
    return @plugins;

}

=head1 BUGS

Please report them to rt-bugs@bestpractical.com, if you know what's
broken and have at least some idea of what needs to be fixed.

If you're not sure what's going on, report them rt-devel@lists.bestpractical.com.

=head1 SEE ALSO

L<RT::StyleGuide>
L<Jifty::DBI>


=cut

1;
