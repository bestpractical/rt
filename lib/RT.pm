
use warnings;
use strict;

package RT;

use RT::CurrentUser;

use strict;
use warnings;
use File::Spec ();
use vars qw($Config $System $system_user $Nobody $Handle $Logger);
our $VERSION = '3.7.14';


our $BasePath = '/home/jesse/svk/3.999-DANGEROUS';
our $EtcPath = '/home/jesse/svk/3.999-DANGEROUS/etc';
our $BinPath = '/home/jesse/svk/3.999-DANGEROUS/bin';
our $VarPath = '/home/jesse/svk/3.999-DANGEROUS/var';
our $LocalPath = '/home/jesse/svk/3.999-DANGEROUS/local';
our $LocalEtcPath = '/home/jesse/svk/3.999-DANGEROUS/local/etc';
our $LocalLexiconPath = '/home/jesse/svk/3.999-DANGEROUS/local/po';

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

sub start {
    shift->InitLogging;
}

sub load_config {
    require RT::Config;
    $Config = RT::Config->new();
    $Config->load_configs;
#    require RT::I18N;

    # RT::Essentials mistakenly recommends that WebPath be set to '/'.
    # If the user does that, do what they mean.
    $RT::WebPath = '' if ($RT::WebPath eq '/');

    RT::I18N->Init;
}

sub Config {
    my $self = shift; 
    return $RT::Config ;
}


=head2 Init

L<Connect to the database /connect_to_database>, L<initilizes system objects /InitSystemObjects>,
L<preloads classes /InitClasses> and L<set up logging /InitLogging>.

=cut

sub Init {

#    CheckPerlRequirements();
    #Get a database connection
    InitSystemObjects();
    InitLogging(); 
}

=head2 InitLogging

Create the Logger object and set up signal handlers.

=cut

sub InitLogging {

    # We have to set the record separator ($, man perlvar)
    # or Log::Dispatch starts getting
    # really pissy, as some other module we use unsets it.
    $, = '';
    use Log::Dispatch 1.6;

    my %level_to_num = (
        map( { $_ => } 0..7 ),
        debug     => 0,
        info      => 1,
        notice    => 2,
        warning   => 3,
        error     => 4, 'err' => 4,
        critical  => 5, crit  => 5,
        alert     => 6, 
        emergency => 7, emerg => 7,
    );

    unless ( $RT::Logger ) {

        $RT::Logger = Log::Dispatch->new;

        my $stack_from_level;
        if ( $stack_from_level = RT->Config->Get('LogStackTraces') ) {
            # if option has old style '\d'(true) value
            $stack_from_level = 0 if $stack_from_level =~ /^\d+$/;
            $stack_from_level = $level_to_num{ $stack_from_level } || 0;
        } else {
            $stack_from_level = 99; # don't log
        }

        my $simple_cb = sub {
            # if this code throw any warning we can get segfault
            no warnings;
            my %p = @_;

            # skip Log::* stack frames
            my $frame = 0;
            $frame++ while caller($frame) && caller($frame) =~ /^Log::/;
            my ($package, $filename, $line) = caller($frame);

            $p{'message'} =~ s/(?:\r*\n)+$//;
            return "[". gmtime(time) ."] [". $p{'level'} ."]: "
                . $p{'message'} ." ($filename:$line)\n";
        };

        my $syslog_cb = sub {
            # if this code throw any warning we can get segfault
            no warnings;
            my %p = @_;

            my $frame = 0; # stack frame index
            # skip Log::* stack frames
            $frame++ while caller($frame) && caller($frame) =~ /^Log::/;
            my ($package, $filename, $line) = caller($frame);

            # syswrite() cannot take utf8; turn it off here.
            Encode::_utf8_off($p{message});

            $p{message} =~ s/(?:\r*\n)+$//;
            if ($p{level} eq 'debug') {
                return "$p{message}\n";
            } else {
                return "$p{message} ($filename:$line)\n";
            }
        };

        my $stack_cb = sub {
            no warnings;
            my %p = @_;
            return $p{'message'} unless $level_to_num{ $p{'level'} } >= $stack_from_level;
            
            require Devel::StackTrace;
            my $trace = Devel::StackTrace->new( ignore_class => [ 'Log::Dispatch', 'Log::Dispatch::Base' ] );
            return $p{'message'} . $trace->as_string;

            # skip calling of the Log::* subroutins
            my $frame = 0;
            $frame++ while caller($frame) && caller($frame) =~ /^Log::/;
            $frame++ while caller($frame) && (caller($frame))[3] =~ /^Log::/;

            $p{'message'} .= "\nStack trace:\n";
            while( my ($package, $filename, $line, $sub) = caller($frame++) ) {
                $p{'message'} .= "\t$sub(...) called at $filename:$line\n";
            }
            return $p{'message'};
        };

        if ( $Config->Get('LogToFile') ) {
            my ($filename, $logdir) = (
                $Config->Get('LogToFilenamed') || 'rt.log',
                $Config->Get('LogDir') || File::Spec->catdir( $VarPath, 'log' ),
            );
            if ( $filename =~ m![/\\]! ) { # looks like an absolute path.
                ($logdir) = $filename =~ m{^(.*[/\\])};
            }
            else {
                $filename = File::Spec->catfile( $logdir, $filename );
            }

            unless ( -d $logdir && ( ( -f $filename && -w $filename ) || -w $logdir ) ) {
                # localizing here would be hard when we don't have a current user yet
                die "Log file '$filename' couldn't be written or Created.\n RT can't run.";
            }

            require Log::Dispatch::File;
            $RT::Logger->add( Log::Dispatch::File->new
                           ( name=>'file',
                             min_level=> $Config->Get('LogToFile'),
                             filename=> $filename,
                             mode=>'append',
                             callbacks => [ $simple_cb, $stack_cb ],
                           ));
        }
        if ( $Config->Get('LogToScreen') ) {
            require Log::Dispatch::Screen;
            $RT::Logger->add( Log::Dispatch::Screen->new
                         ( name => 'screen',
                           min_level => $Config->Get('LogToScreen'),
                           callbacks => [ $simple_cb, $stack_cb ],
                           stderr => 1,
                         ));
        }
        if ( $Config->Get('LogToSyslog') ) {
            require Log::Dispatch::Syslog;
            $RT::Logger->add(Log::Dispatch::Syslog->new
                         ( name => 'syslog',
                           ident => 'RT',
                           min_level => $Config->Get('LogToSyslog'),
                           callbacks => [ $syslog_cb, $stack_cb ],
                           stderr => 1,
                           $Config->Get('LogToSyslogConf'),
                         ));
        }
    }
}

# Signal handlers
## This is the default handling of warnings and die'ings in the code
## (including other used modules - maybe except for errors catched by
## Mason).  It will log all problems through the standard logging
## mechanism (see above).



sub CheckPerlRequirements {
    if ($^V < 5.008003) {
        die sprintf "RT requires Perl v5.8.3 or newer.  Your current Perl is v%vd\n", $^V; 
    }

    local ($@);
    eval { 
        my $x = ''; 
        my $y = \$x;
        require Scalar::Util; Scalar::Util::weaken($y);
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
and C<$RT::Nobody>.

=cut

sub InitSystemObjects {

    #RT's "nobody user" is a genuine database user. its ID lives here.
    $Nobody = RT::CurrentUser->new(name => 'Nobody');
    Carp::confess "Could not load 'Nobody' User. This usually indicates a corrupt or missing RT database" unless $Nobody->id;


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

sub DatabaseHandle { return $Handle }

=head2 Logger

Returns the logger. See also L</InitLogging>.

=cut

sub Logger { return $Logger }

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
    
    unless ($system_user) { 
        $system_user = new RT::CurrentUser;
    $system_user->load_by_name('RT_System');
    }
    
    return $system_user }

=head2 Nobody

Returns object of Nobody. It's object of L<RT::CurrentUser> class
that represents a user who can own ticket and nothing else. See
also L</InitSystemObjects>.

=cut

sub Nobody { return $Nobody }

=head1 BUGS

Please report them to rt-bugs@fsck.com, if you know what's broken and have at least 
some idea of what needs to be fixed.

If you're not sure what's going on, report them rt-devel@lists.bestpractical.com.

=head1 SEE ALSO

L<RT::StyleGuide>
L<Jifty::DBI>


=cut

1;
