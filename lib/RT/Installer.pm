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
        Widget          => '/Widgets/Form/Select',
        WidgetArguments => {
            Description => 'Database type',
            Values      => [
                grep {
                    my $m = 'DBD::' . $_;
                    $m->require ? 1 : 0
                  } qw/mysql Pg SQLite Oracle/
            ],
            ValuesLabel => {
                mysql  => 'MySQL',                                          #loc
                Pg     => 'PostgreSQL',                                     #loc
                SQLite => 'SQLite',  #loc
                Oracle => 'Oracle',                                         #loc
            },
        },
    },
    DatabaseHost => {
        Widget          => '/Widgets/Form/String',
        WidgetArguments => {
            Description => 'Database host',
            Hints => "The domain name of your database server (like 'db.int.example.com')",       #loc
        },
    },
    DatabasePort => {
        Widget          => '/Widgets/Form/Integer',
        WidgetArguments => {
            Description => 'Database port number',         #loc
            Default     => 1,
            DefaultLabel =>
              'Leave empty to use default value of the RDBMS',              #loc
        },
    },
    DatabaseName => {
        Widget          => '/Widgets/Form/String',
        WidgetArguments => {
            Description => 'Database name', #loc
        },
    },
    DatabaseAdmin => {
        Widget          => '/Widgets/Form/String',
        WidgetArguments => {
            Description => 'DBA of the database',  #loc
            Hints => "The database username of the administrator",
        },
    },
    DatabaseAdminPassword => {
        Widget          => '/Widgets/Form/String',
        WidgetArguments => {
            Description =>
              'DBA password',  #loc
            Hints => "The database password of the administrator",
            Type => 'password',
        },
    },
    DatabaseUser => {
        Widget          => '/Widgets/Form/String',
        WidgetArguments => {
            Description =>
              'The Unix username to use for RT',      #loc
        },
    },
    DatabasePassword => {
        Widget          => '/Widgets/Form/String',
        WidgetArguments => {
            Description =>
              'The Unix password to use for RT',  #loc
              Type => 'password',
        },
    },
    DatabaseRequireSSL => {
        Widget          => '/Widgets/Form/Boolean',
        WidgetArguments => {
            Description => 'Use SSL?',    # loc
        },
    },
    rtname => {
        Widget          => '/Widgets/Form/String',
        WidgetArguments => {
            Description => 'RT Name',                        #loc
        },
    },
    Organization => {
        Widget          => '/Widgets/Form/String',
        WidgetArguments => {
            Description => 'Organization',                  #loc
        },
    },
    MinimumPasswordLength => {
        Widget          => '/Widgets/Form/Integer',
        WidgetArguments => {
            Description => 'Minimum password length',         #loc
        },
    },
    MaxAttachmentSize => {
        Widget          => '/Widgets/Form/Integer',
        WidgetArguments => {
            Description => 'Max attachment size',             #loc
        },
    },
    OwnerEmail => {
        Widget          => '/Widgets/Form/String',
        WidgetArguments => {
            Description => 'Owner email',                   #loc
        },
    },
    CommentAddress => {
        Widget          => '/Widgets/Form/String',
        WidgetArguments => {
            Description => 'Comment address',                #loc
        },
    },
    CorrespondAddress => {
        Widget          => '/Widgets/Form/String',
        WidgetArguments => {
            Description => 'Correspond address',             #loc
        },
    },
    MailCommand => {
        Widget          => '/Widgets/Form/String',
        WidgetArguments => {
            Description => 'Mail command',                   #loc
        },
    },
    SendmailArguments => {
        Widget          => '/Widgets/Form/String',
        WidgetArguments => {
            Description => 'Sendmail arguments',             #loc
        },
    },
    SendmailBounceArguments => {
        Widget          => '/Widgets/Form/String',
        WidgetArguments => {
            Description => 'Sendmail bounce arguments',       #loc
        },
    },
    SendmailPath => {
        Widget          => '/Widgets/Form/String',
        WidgetArguments => {
            Description => 'Sendmail path',                  #loc
        },
    },

);

my $HAS_DATETIME_TZ = eval { require DateTime::TimeZone };

if ($HAS_DATETIME_TZ) {
    $Meta{Timezone} = {
        Widget          => '/Widgets/Form/Select',
        WidgetArguments => {
            Description => 'Timezone',
            Values      => [ '', DateTime::TimeZone->all_names ],
            ValuesLabel => {
                '' => 'System Default',    #loc
            },
        },
    };
}
else {
    $Meta{Timezone} = {
        Widget          => '/Widgets/Form/String',
        WidgetArguments => { Description => 'Timezone', },
    };
}

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
    return File::Spec->catfile($RT::EtcPath, 'RT_SiteConfig.pm');
}

sub SaveConfig {
    my $class = shift;

    my $file = $class->ConfigFile;

    my $content;

    {
        local $/;
        open my $fh, '<', $file or die $!;
        $content = <$fh>;
        $content =~ s/^\s*1;\s*$//m;
    }

    if ( open my $fh, '>', $file  ) {
        for ( keys %{$RT::Installer->{InstallConfig}} ) {
            if (defined $RT::Installer->{InstallConfig}{$_}) {
                # remove obsolete settings we'll add later
                $content =~ s/^\s* Set \s* \( \s* \$$_ .*$//xm;

                $content .= "Set( \$$_, '$RT::Installer->{InstallConfig}{$_}' );\n";
            }
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

1;

