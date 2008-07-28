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

package RT::Installer;
use strict;
use warnings;

require UNIVERSAL::require;
my %Meta = (
    DatabaseType => {
        widget          => '/Widgets/Form/Select',
        widget_arguments => {
            description => 'Database type',    # loc
            default      => 0,
            values      => [
                grep {
                    my $m = 'DBD::' . $_;
                    $m->require ? 1 : 0
                  } qw/mysql Pg SQLite Oracle/
            ],
            values_label => {
                mysql  => 'MySQL',             #loc
                Pg     => 'PostgreSQL',        #loc
                SQLite => 'SQLite',            #loc
                Oracle => 'Oracle',            #loc
            },
        },
    },
    DatabaseHost => {
        widget          => '/Widgets/Form/String',
        widget_arguments => {
            description  => 'Database host',                          #loc
            default      => 1,
            default_label => "Keep 'localhost' if you're not sure",    #loc
            hints =>
              "The domain name of your database server (like 'db.example.com')."
            ,                                                         #loc
        },
    },
    DatabasePort => {
        widget          => '/Widgets/Form/Integer',
        widget_arguments => {
            description => 'Database port',                           #loc
            default     => 1,
            default_label =>
              'Leave empty to use the default value for your database',    #loc
        },
    },
    DatabaseName => {
        widget          => '/Widgets/Form/String',
        widget_arguments => {
            description => 'Database name',                                #loc
        },
    },
    DatabaseAdmin => {
        widget          => '/Widgets/Form/String',
        widget_arguments => {
            default => 1,
            hints =>
"Leave this alone to use the default dba username for your database type"
            ,                                                              #loc
            description  => 'DBA username',                                # loc
            default_label => '',
        },
    },
    DatabaseAdminPassword => {
        widget          => '/Widgets/Form/String',
        widget_arguments => {
            description  => 'DBA password',                                #loc
            default_label => "The DBA's database password",                 #loc
            type         => 'password',
            hints =>
"You must provide the dba's password so we can create the RT database and user.",
        },
    },
    DatabaseUser => {
        widget          => '/Widgets/Form/String',
        widget_arguments => {
            description => 'Database username for RT',                     #loc
            hints =>
'RT will connect to the database using this user.  It will be created for you.'
            ,                                                              #loc
        },
    },
    DatabasePassword => {
        widget          => '/Widgets/Form/String',
        widget_arguments => {
            description => 'Database password for RT',                     #loc
            type        => 'password',
            hints => 'The password RT should use to connect to the database.',
        },
    },
    DatabaseRequireSSL => {
        widget          => '/Widgets/Form/Boolean',
        widget_arguments => {
            description => 'Use SSL?',                                     # loc
        },
    },
    rtname => {
        widget          => '/Widgets/Form/String',
        widget_arguments => {
            description => 'Site name',                                    #loc
            hints =>
'RT will use this string to uniquely identify your installation and looks for it in the subject of emails to decide what ticket a message applies to.  We recommend that you set this to your internet domain. (ex: example.com)' #loc
        },
    },
    MinimumPasswordLength => {
        widget          => '/Widgets/Form/Integer',
        widget_arguments => {
            description => 'Minimum password length',    #loc
        },
    },
    Password => {
        widget          => '/Widgets/Form/String',
        widget_arguments => {
            description => 'Administrative password',    #loc
            hints =>
'RT will create a user called "root" and set this as their password'
            ,                                            #loc
            type => 'password',
        },
    },
    OwnerEmail => {
        widget          => '/Widgets/Form/String',
        widget_arguments => {
            description => 'RT Administrator Email',     #loc
            hints =>
"When RT can't handle an email message, where should it be forwarded?"
            ,                                            #loc
        },
    },
    comment_address => {
        widget          => '/Widgets/Form/String',
        widget_arguments => {
            description => 'Comment address',            #loc
            hints =>
'the default addresses that will be listed in From: and Reply-To: headers of comment mail.' #loc
        },
    },
    correspond_address => {
        widget          => '/Widgets/Form/String',
        widget_arguments => {
            description => 'Correspond address',    #loc
            hints =>
'the default addresses that will be listed in From: and Reply-To: headers of correspondence mail.' #loc
        },
    },
    SendmailPath => {
        widget          => '/Widgets/Form/String',
        widget_arguments => {
            hints       => 'Where to find your sendmail binary.',    #loc
            description => 'Path to sendmail',                       #loc
        },
    },
    WebDomain => {
        widget          => '/Widgets/Form/String',
        widget_arguments => {
            description => 'Domain name',                            #loc
            hints =>
"Don't include http://, just something like 'localhost', 'rt.example.com'"
            ,                                                        #loc
        },
    },
    WebPort => {
        widget          => '/Widgets/Form/Integer',
        widget_arguments => {
            description => 'Web port',                               #loc
            hints =>
              'which port your web server will listen to, e.g. 8080',    #loc
        },
    },

);

my $HAS_DATETIME_TZ = eval { require DateTime::TimeZone };

if ($HAS_DATETIME_TZ) {
    $Meta{Timezone} = {
        widget          => '/Widgets/Form/Select',
        widget_arguments => {
            description => 'Timezone',                                   #loc
            Callback    => sub {
                my $ret;
                $ret->{Values} = [ '', DateTime::TimeZone->all_names ];

                my $has_datetime = eval { require DateTime };
                if ($has_datetime) {
                    my $dt = DateTime->now;
                    for my $tz ( DateTime::TimeZone->all_names ) {
                        $dt->set_time_zone($tz);
                        $ret->{ValuesLabel}{$tz} =
                          $tz . ' ' . $dt->strftime('%z');
                    }
                }
                $ret->{ValuesLabel}{''} = 'System Default';    #loc

                return $ret;
            },
        },
    };
}
else {
    $Meta{Timezone} = {
        widget          => '/Widgets/Form/String',
        widget_arguments => {
            description => 'Timezone',                         #loc
        },
    };
}

sub meta {
    my $class = shift;
    my $type  = shift;
    return $Meta{$type} if $type;
    return \%Meta;
}

sub current_value {
    my $class = shift;
    my $type  = shift;
    $type = $class if !ref $class && $class && $class ne 'RT::Installer';

    return undef unless $type;
    return $RT::Installer
      && exists $RT::Installer->{InstallConfig}{$type}
      ? $RT::Installer->{InstallConfig}{$type}
      : scalar RT->config->get($type);
}

sub current_values {
    my $class = shift;
    my @types = @_;
    push @types, $class if !ref $class && $class && $class ne 'RT::Installer';

    return { map { $_ => current_value($_) } @types };
}

sub config_file {
    require File::Spec;
    return File::Spec->catfile( $RT::EtcPath, 'RT_SiteConfig.pm' );
}

sub save_config {
    my $class = shift;

    my $file = $class->config_file;

    my $content;

    {
        local $/;
        open my $fh, '<', $file or die $!;
        $content = <$fh>;
        $content =~ s/^\s*1;\s*$//m;
    }

    # make organization the same as rtname
    $RT::Installer->{InstallConfig}{organization} =
      $RT::Installer->{InstallConfig}{rtname};

    if ( open my $fh, '>', $file ) {
        for ( keys %{ $RT::Installer->{InstallConfig} } ) {

            # we don't want to store root's password in config.
            next if $_ eq 'Password';

            $RT::Installer->{InstallConfig}{$_} = ''
              unless defined $RT::Installer->{InstallConfig}{$_};

            # remove obsolete settings we'll add later
            $content =~ s/^\s* set \s* \( \s* \$$_ .*$//xm;

            $content .= "set( \$$_, '$RT::Installer->{InstallConfig}{$_}' );\n";
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
    my $meta = RT::Installer->meta;

=head1 DESCRIPTION

C<RT::Installer> class provides access to RT Installer Meta

=cut

1;

