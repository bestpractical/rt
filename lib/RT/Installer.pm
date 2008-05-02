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
            Description => 'Type of the database where RT will store its data',
            Values      => [
                grep {
                    my $m = 'DBD::' . $_;
                    $m->require ? 1 : 0
                  } qw/mysql Pg SQLite Oracle/
            ],
            ValuesLabel => {
                mysql  => 'MySQL',                                          #loc
                Pg     => 'PostgreSQL',                                     #loc
                SQLite => 'SQLite (for experiments and development only)',  #loc
                Oracle => 'Oracle',                                         #loc
            },
        },
    },
    DatabaseHost => {
        Widget          => '/Widgets/Form/String',
        WidgetArguments => {
            Description => 'The domain name of your database server',       #loc
        },
    },
    DatabasePort => {
        Widget          => '/Widgets/Form/Integer',
        WidgetArguments => {
            Description => 'Port number database server listen to',         #loc
            Default     => 1,
            DefaultLabel =>
              'Leave empty to use default value of the RDBMS',              #loc
        },
    },
    DatabaseName => {
        Widget          => '/Widgets/Form/String',
        WidgetArguments => {
            Description => 'Name of the database',                          #loc
        },
    },
    DatabaseAdmin => {
        Widget          => '/Widgets/Form/String',
        WidgetArguments => {
            Description => 'DBA of the database',  #loc
        },
    },
    DatabaseAdminPassword => {
        Widget          => '/Widgets/Form/String',
        WidgetArguments => {
            Description =>
              'DBA password of the database',  #loc
            Type => 'password',
        },
    },
    DatabaseUser => {
        Widget          => '/Widgets/Form/String',
        WidgetArguments => {
            Description =>
              'The name of the user RT will use to connect to the DB',      #loc
        },
    },
    DatabasePassword => {
        Widget          => '/Widgets/Form/String',
        WidgetArguments => {
            Description =>
              'Password of the above user RT will use to connect to the DB'
            ,                                                               #loc
            Type => 'password',
        },
    },
    DatabaseRequireSSL => {
        Widget          => '/Widgets/Form/Boolean',
        WidgetArguments => {
            Description => 'Connecting DB requires SSL',    # loc
        },
    },
    rtname => {
        Widget          => '/Widgets/Form/String',
        WidgetArguments => {
            Description => 'rtname',                        #loc
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
            Description => 'MinimumPasswordLength',         #loc
        },
    },
    MaxAttachmentSize => {
        Widget          => '/Widgets/Form/Integer',
        WidgetArguments => {
            Description => 'MaxAttachmentSize',             #loc
        },
    },
    OwnerEmail => {
        Widget          => '/Widgets/Form/String',
        WidgetArguments => {
            Description => 'OwnderEmail',                   #loc
        },
    },
    CommentAddress => {
        Widget          => '/Widgets/Form/String',
        WidgetArguments => {
            Description => 'CommentAddress',                #loc
        },
    },
    CorrespondAddress => {
        Widget          => '/Widgets/Form/String',
        WidgetArguments => {
            Description => 'CorrespondAddress',             #loc
        },
    },
    MailCommand => {
        Widget          => '/Widgets/Form/String',
        WidgetArguments => {
            Description => 'MailCommand',                   #loc
        },
    },
    SendmailArguments => {
        Widget          => '/Widgets/Form/String',
        WidgetArguments => {
            Description => 'SendmailArguments',             #loc
        },
    },
    SendmailBounceArguments => {
        Widget          => '/Widgets/Form/String',
        WidgetArguments => {
            Description => 'SendmailBounceArguments',       #loc
        },
    },
    SendmailPath => {
        Widget          => '/Widgets/Form/String',
        WidgetArguments => {
            Description => 'SendmailPath',                  #loc
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

=head1 NAME

    RT::Installer - RT's Installer

=head1 SYNOPSYS

    use RT::Installer;
    my $meta = RT::Installer->Meta;

=head1 DESCRIPTION

C<RT::Installer> class provides access to RT Installer Meta

=cut

1;

