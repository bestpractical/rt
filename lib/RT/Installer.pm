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

package RT::Installer;
use strict;
use warnings;

use DateTime;

require UNIVERSAL::require;
my %Meta = (
    DatabaseType => {
        Widget          => '/Widgets/Form/Select',
        WidgetArguments => {
            Description => 'Database type',    # loc
            Values      => [
                grep {
                    my $m = 'DBD::' . $_;
                    $m->require ? 1 : 0
                  } qw/mysql Pg SQLite Oracle/
            ],
            ValuesLabel => {
                mysql  => 'MySQL',             #loc
                Pg     => 'PostgreSQL',        #loc
                SQLite => 'SQLite',            #loc
                Oracle => 'Oracle',            #loc
            },
        },
    },
    DatabaseHost => {
        Widget          => '/Widgets/Form/String',
        WidgetArguments => {
            Description => 'Database host', #loc
            Default => 1,
            DefaultLabel => "Keep 'localhost' if you're not sure. Leave blank to connect locally over a socket", #loc
            Hints => "The domain name of your database server (like 'db.example.com').",       #loc
        },
    },
    DatabasePort => {
        Widget          => '/Widgets/Form/Integer',
        WidgetArguments => {
            Description => 'Database port',         #loc
            Default     => 1,
            DefaultLabel =>
              'Leave empty to use the default value for your database',              #loc
        },
    },
    DatabaseName => {
        Widget          => '/Widgets/Form/String',
        WidgetArguments => {
            Description => 'Database name',                       #loc
        },
    },
    DatabaseAdmin => {
        SkipWrite       => 1,
        Widget          => '/Widgets/Form/String',
        WidgetArguments => {
            Default => 1,
            Hints => "Leave this alone to use the default dba username for your database type", #loc
            Description => 'DBA username', # loc
            DefaultLabel => '',
        },
    },
    DatabaseAdminPassword => {
        SkipWrite       => 1,
        Widget          => '/Widgets/Form/String',
        WidgetArguments => {
            Description => 'DBA password',  #loc
            DefaultLabel => "The DBA's database password",#loc
            Type => 'password',
            Hints => "You must provide the dba's password so we can create the RT database and user.",
        },
    },
    DatabaseUser => {
        Widget          => '/Widgets/Form/String',
        WidgetArguments => {
            Description => 'Database username for RT',                      #loc
            Hints => 'RT will connect to the database using this user.  It will be created for you.', #loc
        },
    },
    DatabasePassword => {
        Widget          => '/Widgets/Form/String',
        WidgetArguments => {
            Description => 'Database password for RT',                      #loc
            Type        => 'password',
            Hints       => 'The password RT should use to connect to the database.',
        },
    },
    rtname => {
        Widget          => '/Widgets/Form/String',
        WidgetArguments => {
            Description => 'Site name',                        #loc
            Hints => 'RT will use this string to uniquely identify your installation and looks for it in the subject of emails to decide what ticket a message applies to.  We recommend that you set this to your internet domain. (ex: example.com)' #loc
        },
    },
    MinimumPasswordLength => {
        Widget          => '/Widgets/Form/Integer',
        WidgetArguments => {
            Description => 'Minimum password length',    #loc
        },
    },
    Password => {
        SkipWrite       => 1,
        Widget          => '/Widgets/Form/String',
        WidgetArguments => {
            Description => 'Administrative password', #loc
            Hints => 'RT will create a user called "root" and set this as their password', #loc
            Type => 'password',
        },
    },
    OwnerEmail => {
        Widget          => '/Widgets/Form/String',
        WidgetArguments => {
            Description => 'RT Administrator Email',                   #loc
            Hints => "When RT can't handle an email message, where should it be forwarded?", #loc
        },
    },
    CommentAddress => {
        Widget          => '/Widgets/Form/String',
        WidgetArguments => {
            Description => 'Comment address',                           #loc
            Hints =>
'the default addresses that will be listed in From: and Reply-To: headers of comment mail.' #loc
        },
    },
    CorrespondAddress => {
        Widget          => '/Widgets/Form/String',
        WidgetArguments => {
            Description => 'Correspond address',    #loc
            Hints =>
'the default addresses that will be listed in From: and Reply-To: headers of correspondence mail.' #loc
        },
    },
    SendmailPath => {
        Widget          => '/Widgets/Form/String',
        WidgetArguments => {
            Hints => 'Where to find your sendmail binary.',    #loc
            Description => 'Path to sendmail', #loc
        },
    },
    Timezone => {
        Widget          => '/Widgets/Form/Select',
        WidgetArguments => {
            Description => 'Timezone',                              #loc
            Callback    => sub {
                my $ret;
                $ret->{Values} = ['', DateTime::TimeZone->all_names];

                my $dt = DateTime->now;
                for my $tz ( DateTime::TimeZone->all_names ) {
                    $dt->set_time_zone( $tz );
                    $ret->{ValuesLabel}{$tz} =
                        $tz . ' ' . $dt->strftime('%z');
                }
                $ret->{ValuesLabel}{''} = 'System Default'; #loc

                return $ret;
            },
        },
    },
    WebDomain => {
        Widget          => '/Widgets/Form/String',
        WidgetArguments => {
            Description => 'Domain name',                  #loc
            Hints => "Don't include http://, just something like 'localhost', 'rt.example.com'", #loc
        },
    },
    WebPort => {
        Widget          => '/Widgets/Form/Integer',
        WidgetArguments => {
            Description => 'Web port',                     #loc
            Hints => 'which port your web server will listen to, e.g. 8080', #loc
        },
    },

);

sub Meta {
    my $class = shift;
    my $type  = shift;
    return $Meta{$type} if $type;
    return \%Meta;
}

sub CurrentValue {
    my $class = shift;
    my $type  = shift;
    $type = $class if !ref $class && $class && $class ne 'RT::Installer';

    return undef unless $type;
    return $RT::Installer
      && exists $RT::Installer->{InstallConfig}{$type}
      ? $RT::Installer->{InstallConfig}{$type}
      : scalar RT->Config->Get($type);
}

sub CurrentValues {
    my $class = shift;
    my @types = @_;
    push @types, $class if !ref $class && $class && $class ne 'RT::Installer';

    return { map { $_ => CurrentValue($_) } @types };
}

sub ConfigFile {
    require File::Spec;
    return $ENV{RT_SITE_CONFIG} || File::Spec->catfile( $RT::EtcPath, 'RT_SiteConfig.pm' );
}

sub SaveConfig {
    my $class = shift;

    my $file = $class->ConfigFile;

    my $content;

    {
        local $/;
        open( my $fh, '<', $file ) or die $!;
        $content = <$fh>;
        $content =~ s/^\s*1;\s*$//m;
    }

    # make organization the same as rtname
    $RT::Installer->{InstallConfig}{Organization} =
      $RT::Installer->{InstallConfig}{rtname};

    if ( open my $fh, '>', $file ) {
        for ( sort keys %{ $RT::Installer->{InstallConfig} } ) {

            # we don't want to store root's password in config.
            next if $class->Meta($_) and $class->Meta($_)->{SkipWrite};

            $RT::Installer->{InstallConfig}{$_} = ''
              unless defined $RT::Installer->{InstallConfig}{$_};

            # remove obsolete settings we'll add later
            $content =~ s/^\s* Set \s* \( \s* \$$_ .*$//xm;

            my $value = $RT::Installer->{InstallConfig}{$_};
            $value =~ s/(['\\])/\\$1/g;
            $content .= "Set( \$$_, '$value' );\n";
        }
        $content .= "1;\n";
        print $fh $content;
        close $fh;

        return ( 1, "Successfully saved configuration to $file." );
    }

    return ( 0, "Cannot save configuration to $file: $!" );
}

=head1 NAME

    RT::Installer - RT's Installer

=head1 SYNOPSYS

    use RT::Installer;
    my $meta = RT::Installer->Meta;

=head1 DESCRIPTION

C<RT::Installer> class provides access to RT Installer Meta

=cut

RT::Base->_ImportOverlays();

1;

