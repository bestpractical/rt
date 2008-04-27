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

my $HAS_DATETIME_TZ = eval { require DateTime::TimeZonse };

if ($HAS_DATETIME_TZ) {
    $Meta{TimeZone} = {
        Widget          => '/Widgets/Form/Select',
        WidgetArguments => {
            Description => 'TimeZone',
            Values      => [ '', DateTime::TimeZone->all_names ],
            ValuesLabel => {
                '' => 'System Default',    #loc
            },
        },
    };
}
else {
    $Meta{TimeZone} = {
        Widget          => '/Widgets/Form/String',
        WidgetArguments => { Description => 'TimeZone', },
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

