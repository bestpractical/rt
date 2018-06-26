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

package RT::Test::Apache;
use strict;
use warnings;

my %MODULES = (
    '2.2' => {
        "mod_perl" => [qw(authz_host env alias perl)],
        "fastcgi"  => [qw(authz_host env alias mime fastcgi)],
    },
    '2.4' => {
        "mod_perl" => [qw(mpm_worker authz_core authn_core authz_host env alias perl)],
        "fastcgi"  => [qw(mpm_worker authz_core authn_core authz_host env alias mime fastcgi)],
    },
);

my $apache_module_prefix = $ENV{RT_TEST_APACHE_MODULES};
my $apxs =
     $ENV{RT_TEST_APXS}
  || RT::Test->find_executable('apxs')
  || RT::Test->find_executable('apxs2');

if ($apxs and not $apache_module_prefix) {
    $apache_module_prefix = `$apxs -q LIBEXECDIR`;
    chomp $apache_module_prefix;
}

$apache_module_prefix ||= 'modules';

sub basic_auth {
    my $self = shift;
    my $passwd = File::Spec->rel2abs( File::Spec->catfile(
        't', 'data', 'configs', 'passwords' ) );

    return <<"EOT";
    AuthType Basic
    AuthName "restricted area"
    AuthUserFile $passwd
    Require user root
EOT
}

sub basic_auth_anon {
    my $self = shift;

    return <<"EOT";
    AuthType Basic
    AuthName "restricted area"
    AuthBasicProvider anon

    Anonymous *
    Anonymous_NoUserID On
    Anonymous_MustGiveEmail Off
    Anonymous_VerifyEmail Off

    Require valid-user
EOT
}

sub start_server {
    my ($self, %config) = @_;
    my %tmp = %{$config{tmp}};
    my %info = $self->apache_server_info( %config );

    RT::Test::diag(do {
        open( my $fh, '<', $tmp{'config'}{'RT'} ) or die $!;
        local $/;
        <$fh>
    });

    my $tmpl = File::Spec->rel2abs( File::Spec->catfile(
        't', 'data', 'configs',
        'apache'. $info{'version'} .'+'. $config{variant} .'.conf'
    ) );
    my %opt = (
        listen         => $config{port},
        server_root    => $info{'HTTPD_ROOT'} || $ENV{'HTTPD_ROOT'}
            || Test::More::BAIL_OUT("Couldn't figure out server root"),
        document_root  => $RT::MasonComponentRoot,
        tmp_dir        => "$tmp{'directory'}",
        rt_bin_path    => $RT::BinPath,
        rt_sbin_path   => $RT::SbinPath,
        rt_site_config => $ENV{'RT_SITE_CONFIG'},
        load_modules   => $info{load_modules},
    );
    if (not $config{basic_auth}) {
        $opt{basic_auth} = "";
    } elsif ($config{basic_auth} eq 'anon') {
        $opt{basic_auth} = $self->basic_auth_anon;
    } else {
        $opt{basic_auth} = $self->basic_auth;
    }
    foreach (qw(log pid lock)) {
        $opt{$_ .'_file'} = File::Spec->catfile(
            "$tmp{'directory'}", "apache.$_"
        );
    }

    $tmp{'config'}{'apache'} = File::Spec->catfile(
        "$tmp{'directory'}", "apache.conf"
    );
    $self->process_in_file(
        in      => $tmpl, 
        out     => $tmp{'config'}{'apache'},
        options => \%opt,
    );

    $self->fork_exec($info{'executable'}, '-f', $tmp{'config'}{'apache'});
    my $pid = do {
        my $tries = 15;
        while ( !-s $opt{'pid_file'} ) {
            $tries--;
            last unless $tries;
            sleep 1;
        }
        my $pid_fh;
        unless (-e $opt{'pid_file'} and open($pid_fh, '<', $opt{'pid_file'})) {
            Test::More::BAIL_OUT("Couldn't start apache server, no pid file (unknown error)")
                  unless -e $opt{log_file};

            open my $log, "<", $opt{log_file};
            my $error = do {local $/; <$log>};
            close $log;
            $RT::Logger->error($error) if $error;
            Test::More::BAIL_OUT("Couldn't start apache server!");
        }

        my $pid = <$pid_fh>;
        chomp $pid;
        $pid;
    };

    Test::More::ok($pid, "Started apache server #$pid");
    return $pid;
}

sub apache_server_info {
    my $self = shift;
    my %res = @_;

    my $bin = $res{'executable'} = $ENV{'RT_TEST_APACHE'}
        || $self->find_apache_server
        || Test::More::BAIL_OUT("Couldn't find apache server, use RT_TEST_APACHE");

    Test::More::BAIL_OUT(
        "Couldn't find apache modules directory (set APXS= or RT_TEST_APACHE_MODULES=)"
    ) unless -d $apache_module_prefix;


    RT::Test::diag("Using '$bin' apache executable for testing");

    my $info = `$bin -v`;
    ($res{'version'}) = ($info =~ m{Server\s+version:\s+Apache/(\d+\.\d+)\.});
    Test::More::BAIL_OUT(
        "Couldn't figure out version of the server"
    ) unless $res{'version'};

    $res{'modules'} = [
        map {s/^\s+//; s/\s+$//; $_}
        grep $_ !~ /Compiled in modules/i,
        split /\r*\n/, `$bin -l`
    ];

    Test::More::BAIL_OUT(
        "Unsupported apache version $res{version}"
    ) unless exists $MODULES{$res{version}};

    Test::More::BAIL_OUT(
        "Unsupported apache variant $res{variant}"
    ) unless exists $MODULES{$res{version}}{$res{variant}};

    my @mlist = @{$MODULES{$res{version}}{$res{variant}}};
    if ($res{basic_auth}) {
        push @mlist, "auth_basic", "authz_user";
        push @mlist, $res{basic_auth} eq 'anon' ? "authn_anon" : "authn_file";
    }

    $res{'load_modules'} = '';
    foreach my $mod ( @mlist ) {
        next if grep $_ =~ /^(mod_|)$mod\.c$/, @{ $res{'modules'} };

        my $so_file = $apache_module_prefix."/mod_".$mod.".so";
        Test::More::BAIL_OUT( "Couldn't load $mod module (expected in $so_file)" )
              unless -f $so_file;
        $res{'load_modules'} .=
            "LoadModule ${mod}_module $so_file\n";
    }

    # Apache 2.4 wants to fully-parse a config file when running -V,
    # because the MPM is no longer compiled-in.  Provide a trivial one.
    require File::Temp;
    my $tmp = File::Temp->new;
    my ($mpm) = grep {/^mpm_/} @{$MODULES{$res{version}}{$res{variant}}};
    print $tmp "LoadModule ${mpm}_module $apache_module_prefix/mod_${mpm}.so\n"
        if $mpm;
    print $tmp "ErrorLog /dev/null\n";
    print $tmp "TransferLog /dev/null\n";
    close $tmp;
    $info = `$res{executable} -V -f $tmp`;
    my %opts = ($info =~ m/^\s*-D\s+([A-Z_]+?)(?:="(.*)")$/mg);
    %res = (%res, %opts);
    return %res;
}

sub find_apache_server {
    my $self = shift;
    return $_ foreach grep defined,
        map RT::Test->find_executable($_),
        qw(httpd apache apache2 apache1);
    return undef;
}

sub apache_mpm_type {
    my $self = shift;
    my $apache = $self->find_apache_server;
    my $out = `$apache -l`;
    if ( $out =~ /^\s*(worker|prefork|event|itk)\.c\s*$/m ) {
        return $1;
    }
    return "worker";
}

sub fork_exec {
    my $self = shift;

    RT::Test::__disconnect_rt();
    my $pid = fork;
    unless ( defined $pid ) {
        die "cannot fork: $!";
    } elsif ( !$pid ) {
        exec @_;
        die "can't exec `". join(' ', @_) ."` program: $!";
    } else {
        RT::Test::__reconnect_rt();
        return $pid;
    }
}

sub process_in_file {
    my $self = shift;
    my %args = ( in => undef, options => undef, @_ );

    my $text = RT::Test->file_content( $args{'in'} );
    while ( my ($opt) = ($text =~ /\%\%(.+?)\%\%/) ) {
        my $value = $args{'options'}{ lc $opt };
        die "no value for $opt" unless defined $value;

        $text =~ s/\%\%\Q$opt\E\%\%/$value/g;
    }

    my ($out_fh, $out_conf);
    unless ( $args{'out'} ) {
        ($out_fh, $out_conf) = tempfile();
    } else {
        $out_conf = $args{'out'};
        open( $out_fh, '>', $out_conf )
            or die "couldn't open '$out_conf': $!";
    }
    print $out_fh $text;
    seek $out_fh, 0, 0;

    return ($out_fh, $out_conf);
}

1;
