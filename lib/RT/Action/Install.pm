use strict;
use warnings;

=head1 NAME

RT::Action::Install

=cut

package RT::Action::Install;
use base qw/RT::Action Jifty::Action/;
use UNIVERSAL::require;
use Scalar::Util qw/looks_like_number/;
use Regexp::Common qw/Email::Address/;

use Jifty::Param::Schema;
use Jifty::Action schema {
    param 'start';
    param database_type =>
        label is 'Database type',
        render as 'Select',
        available are defer {
            my %map = (
                mysql  => 'MySQL',
                Pg     => 'PostgreSQL',
                SQLite => 'SQLite',
                Oracle => 'Oracle',
            );

            for ( keys %map ) {
                my $m = 'DBD::' . $_;
                delete $map{$_} unless $m->require;
            }

            [ map { { display => $map{$_}, value => $_ } } keys %map ];
        },
        default is defer { RT->config->get( 'database_type' ) };
    param database_host =>
        label is 'Database host',
        hints is "The domain name of your database server (like 'db.example.com')", #loc
        default is defer {
            RT->config->get('database_host')
        };

    param database_port =>
        label is 'Database port',
        hints is 'Leave empty to use the default value for your database',    #loc
        default is defer { RT->config->get('database_port') };

    param database_name =>
        label is 'Database name',
        default is defer {
            RT->config->get('database_name')
        };
    param database_admin =>
        label is 'DBA username', #loc
        hints is
"Leave this alone to use the default dba username for your database type", #loc
        default is defer {
            my $type = $RT::Installer->{config}{'database_type'};
            return unless $type;
            return 'root' if $type eq 'mysql';
            return 'postgres' if $type eq 'Pg';
            return;
        };
    param database_admin_password =>
        label is 'DBA password',                                #loc
        render as 'Password',
        hints is
"You must provide the dba's password so we can create the RT database and user."; #loc

    param database_user =>
        label is 'Database username for RT',                     #loc
        hints is
'RT will connect to the database using this user.  It will be created for you.'
, #loc
        default is defer { RT->config->get( 'database_user' ) };

    param database_password =>
        label is 'Database password for RT',                     #loc
        render as 'Password',
        hints is 'The password RT should use to connect to the database.';#loc

    param database_require_ssl =>
        label is 'Use SSL?', #loc
        render as 'Radio',
        default is defer { RT->config->get( 'database_require_ssl' ) };

    param rtname =>
        label is 'Site name',
        hints is
'RT will use this string to uniquely identify your installation and looks for it in the subject of emails to decide what ticket a message applies to.  We recommend that you set this to your internet domain. (ex: example.com)', #loc
        default is defer { RT->config->get( 'rtname' ) };

    param minimum_password_length =>
        label is 'Minimum password length', #loc
        default is defer { RT->config->get( 'minimum_password_length' ) };

    param password =>
        label is 'Administrative password',    #loc
        hints is
'RT will create a user called "root" and set this as their password', #loc
        render as 'Password',
        is mandatory;

    param owner_email =>
        label is 'RT Administrator Email',     #loc
        hints is
"When RT can't handle an email message, where should it be forwarded?", #loc
        is mandatory;

    param comment_address =>
        label is 'Comment address',            #loc
        hints is
'the default addresses that will be listed in From: and Reply-To: headers of comment mail.', #loc
        default is defer { RT->config->get( 'comment_address' ) };

    param correspond_address =>
        label is 'Correspond address',    #loc
        hints is
'the default addresses that will be listed in From: and Reply-To: headers of correspondence mail.', #loc
        default is defer { RT->config->get( 'correspond_address' ) };

    param sendmail_path =>
        label is 'Path to sendmail',                       #loc
        hints is 'Where to find your sendmail binary.',    #loc
        default is defer { RT->config->get( 'sendmail_path' ) };
    param web_domain =>
        label is 'Domain name',                            #loc
        hints is
"Don't include http://, just something like 'localhost', 'rt.example.com'"
            ,                                                        #loc
        default is defer { RT->config->get( 'web_domain' ) };
    param web_port =>
        label is 'Web port',                               #loc
        hints is
              'which port your web server will listen to, e.g. 8080',    #loc
        default is defer { RT->config->get( 'web_port' ) };
    param timezone =>
        label is 'Timezone',                                   #loc
        render as 'Select',
        available are defer {
                my %map = ( '' => 'System Default' );
                use DateTime::TimeZone;
                use DateTime;
                my $dt = DateTime->now;
                for my $tz ( DateTime::TimeZone->all_names ) {
                        $dt->set_time_zone($tz);
                        $map{$tz} = $tz . ' ' . $dt->strftime('%z');
                }

                [ map { { display => $map{$_}, value => $_ } }
                      sort keys %map ];
            };
    param 'initdb';
    param 'finish';
};

my @available_database_types = grep {
    my $m = 'DBD::' . $_;
    $m->require ? 1 : 0
} qw/mysql Pg SQLite Oracle/;

sub validate_database_type {
    my $self = shift;
    return $self->validation_ok('database_type') unless $self->has_argument(
            'database_type' );

    my $type = shift;

    unless ( grep { $_ eq $type } @available_database_types ) {
        return $self->validation_error( database_type =>
              "invalid database_type, valid types are @available_database_types"
        );
    }

    return $self->validation_ok('database_type');
}

sub validate_database_port {
    my $self = shift;
    return $self->validation_ok('database_port') unless $self->has_argument(
        'database_port' );

    my $port = shift;

    if ( $port && !looks_like_number( $port ) ) {
        return $self->validation_error( database_port =>
              'invalid database_port, should be a number or nothing' ); #loc
    }

    return $self->validation_ok('database_port');
}


sub validate_sendmail_path {
    my $self = shift;
    return $self->validation_ok('sendmail_path') unless $self->has_argument(
        'sendmail_path' );

    my $path = shift;

    if ( -e $path ) {
        return $self->validation_ok( 'sendmail_path' );
    }
    else {
        return $self->validation_error(
            sendmail_path => "the path seems not exist." );
    }
}

sub _validate_email {
    my $self = shift;
    my $param = shift;
    my $email = shift;

    return $self->validation_ok($param) unless $email && $self->has_argument( $param );

    if ( $email =~ /^$RE{Email}{Address}$/ ) {
        return $self->validation_ok( $param );
    }
    else {
        return $self->validation_error(
            $param => "This does not look like a proper e-mail address." );
    }
}

sub validate_owner_email {
    my $self = shift;
    my $email = shift;
    return $self->_validate_email( owner_email => $email );
}

sub validate_correspond_address {
    my $self = shift;
    my $email = shift;
    return $self->_validate_email( correspond_address => $email );
}

sub validate_comment_address {
    my $self = shift;
    my $email = shift;
    return $self->_validate_email( comment_address => $email );
}

=head2 take_action

=cut

sub take_action {
    my $self = shift;

    for my $arg ( $self->argument_names ) {
        if ( $self->has_argument( 'start' ) ) {
            $RT::Installer->{config} = {};
            last;
        }
        elsif ( $self->has_argument('initdb') ) {
### TODO finish this

            last;
        }
        elsif ( $self->has_argument('finish') ) {

            RT->install_mode(0);
            RT->init_system_objects();
            RT->init();
            my $root = RT::Model::User->new( RT->system_user );
            $root->load('root');
            $root->set_password( $RT::Installer->{config}{password} );
            last;
        }

        if ( $self->has_argument( $arg ) ) {
            $RT::Installer->{config}{$arg} = $self->argument_value($arg);
        }
    }

    $self->report_success if not $self->result->failure;

    return 1;
}

=head2 report_success

=cut

sub report_success {
    my $self = shift;

    # Your success message here
    $self->result->message('Success');
}

1;

