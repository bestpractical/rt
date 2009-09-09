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
use warnings;
use strict;

package RT;

use RT::CurrentUser;
use RT::DateTime;
use Jifty::Util;

use strict;
use warnings;
use File::Spec ();
use vars qw($Config $System $nobody $Handle );
our $VERSION = '3.999.0';

=head1 NAME

RT - Request Tracker

=head1 SYNOPSIS

A fully featured request tracker package

=head1 description

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
    $Config = RT::Model::Config->new;

    #    require RT::I18N;
    RT::I18N->init;
}

sub config {
    my $self = shift;
    if (!$Config) {
        RT->load_config;
    }
    return $Config;
}

=head2 init

L<configures plugins|init_plugins>.

=cut

sub init {

    #    CheckPerlRequirements();
    #Get a database connection
    init_plugin_paths();

    $System = RT::System->new();

    init_plugins();
    require RT::Lorzy;
    # enable approval subsystem
    require RT::Approval;

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

=head1 CLASS METHODS

=head2 config

Returns the current L<config object|RT::Model::Config>.

Method can be called as class method.

=cut

=head2 system

Returns the current system object L<RT::System>.

=cut

sub system { return RT::System->new }

=head2 system_user

Returns the system user's object, it's object of
L<RT::CurrentUser> class that represents the system.

=cut

sub system_user {
    my $system_user = RT::CurrentUser->new( name => 'RT_System' );
    $system_user->is_superuser(1);
    return $system_user;

}

=head2 Nobody

Returns object of Nobody. It's object of L<RT::CurrentUser> class
that represents a user who can own ticket and nothing else.

=cut

sub nobody {
    unless ($nobody) {
        $nobody = RT::CurrentUser->new( name => 'Nobody' );
        Carp::confess "Could not load 'Nobody' User. This usually indicates a corrupt or missing RT database"
                unless $nobody->id;
    }

    return $nobody
}

=head2 Plugins

Returns a listref of all Plugins currently configured for this RT instance.
You can define plugins by adding them to the @Plugins list in your RT_SiteConfig

=cut

our @PLUGINS = ();

sub plugins {
    my $self = shift;
    unless (@PLUGINS) {
        $self->init_plugin_paths;
        @PLUGINS = $self->init_plugins;
    }
    return \@PLUGINS;
}

=head2 plugin_dirs

Takes optional subdir (e.g. po, lib, etc.) and return plugins' dirs that exist.

=cut

sub plugin_dirs {
    my $self = shift;
    my $subdir = shift;

    my @res;
#    foreach my $plugin ( grep $_, RT->config->get('plugins') ) {
    foreach my $plugin ( grep $_, () ) {
        my $plugindir = $plugin;
        $plugindir =~ s/::/-/g;
        my $path = RT->local_plugin_path. "/$plugindir";
        $path .= "/$subdir" if defined $subdir && length $subdir;
        next unless -d $path;
        push @res, $path;
    }
    return @res;
}

=head2 init_plugin_paths

Push plugins' lib paths into @INC right after F<local/lib>.

=cut

sub init_plugin_paths {
    my $self = shift || __PACKAGE__;

    my @lib_dirs = $self->plugin_dirs('lib');

    my @tmp_inc;
    my $local_lib = $self->local_lib_path;
    for (@INC) {
        if ( Cwd::realpath($_) eq $local_lib) {
            push @tmp_inc, $_, @lib_dirs;
        } else {
            push @tmp_inc, $_;
        }
    }
    my %seen;
    @INC = grep !$seen{$_}++, @tmp_inc;
}

=head2 init_plugins

Initialize all Plugins found in the RT configuration file, setting up
their lib and HTML::Mason component roots.

=cut

sub init_plugins {
    my $self    = shift;
    my @plugins;
    require RT::Plugin;
#    foreach my $plugin (grep $_, RT->config->get('plugins')) {
    foreach my $plugin (grep $_, () ) {
        $plugin->require;
        die $UNIVERSAL::require::ERROR if ($UNIVERSAL::require::ERROR);
        push @plugins, RT::Plugin->new(name =>$plugin);
    }
    return @plugins;
}

=head2 init_jifty

call Jifty->new to init Jifty's stuff.
nomrally, we need to do it early in BEGIN block

=cut

sub init_jifty {
    require Jifty;
    Jifty->new;
}

    Jifty->web->add_javascript(
        qw( titlebox-state.js util.js ahah.js fckeditor.js list.js
		jquery.createdomnodes.js 
        combobox.js  cascaded.js rulebuilder.js 
		
		)
    );

    Jifty::Web->add_trigger(
        name      => 'after_include_javascript',
        callback  => sub {
            my $webpath = RT->config->get('web_path') || '/';
            Jifty->web->out(
                qq{<script type="text/javascript">RT = {};RT.WebPath = '$webpath';</script>}
            );
        },
    );

=head2 local_path

The root of F</local> (user overrides)

=cut

sub local_path { Jifty::Util->app_root . '/local' }

=head2 local_lib_path

The root of F</local/lib> (user libraries)

=cut

sub local_lib_path { shift->local_path . '/lib' }

=head2 sbin_path

The root of F</sbin> (system programs)

=cut

sub sbin_path { Jifty::Util->app_root . '/sbin' }

=head2 bin_path

The root of F</bin> (RT programs)

=cut

sub bin_path { Jifty::Util->app_root . '/bin' }

=head2 html_path

The root of F</share/html> (Mason templates)

=cut

sub html_path { Jifty::Util->app_root . '/share/html' }

=head2 local_html_path

The root of F</local/html> (user Mason templates)

=cut

sub local_html_path { Jifty::Util->app_root . '/local/html' }

=head2 etc_path

The root of F</etc> (configuration)

=cut

sub etc_path { Jifty::Util->app_root . '/etc' }

=head2 var_path

The root of F</var> (internal book-keeping)

=cut

sub var_path { Jifty::Util->app_root . '/var' }

=head2 local_plugin_path

The root of F</local/plugins> (plugins)

=cut

sub local_plugin_path { Jifty::Util->app_root . '/local/plugins' }

=head2 lib_path

The root of F</lib> (RT libraries)

=cut

sub lib_path { Jifty::Util->app_root . '/lib' }

=head1 BUGS

Please report them to C<rt-bugs@bestpractical.com>, if you know what's
broken and have at least some idea of what needs to be fixed.

If you're not sure what's going on, report them
C<rt-devel@lists.bestpractical.com>.

=head1 SEE ALSO

L<RT::StyleGuide>
L<Jifty::DBI>


=cut

sub start {
    #XXX TODO RT pages don't play well with Halo right now
    no warnings 'redefine';
    *Jifty::Plugin::Halo::is_proscribed = sub { 1 };
    RT::init();

    Jifty->web->add_javascript(
        qw( titlebox-state.js util.js ahah.js list.js class.js
            jquery.createdomnodes.js jquery.menu.js combobox.js  cascaded.js rulebuilder.js
      )
    );

    Jifty::Web->add_trigger(
        name      => 'after_include_javascript',
        callback  => sub {
            my $webpath = RT->config->get('web_path') || '/';
            Jifty->web->out(
                qq{<script type="text/javascript">RT = {};RT.WebPath = '$webpath';</script>}
            );
        },
    );
}

1;
