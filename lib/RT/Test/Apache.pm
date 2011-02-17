package RT::Test::Apache;
use strict;
use warnings;

my $apache_module_prefix;
my $apxs =
     $ENV{RT_TEST_APXS}
  || RT::Test->find_executable('apxs')
  || RT::Test->find_executable('apxs2');

if ($apxs) {
    $apache_module_prefix = `$apxs -q LIBEXECDIR`;
    chomp $apache_module_prefix;
}

$apache_module_prefix ||= 'modules';

sub start_server {
    my ($self, $variant, $port, $tmp) = @_;
    my %tmp = %$tmp;
    my %info = $self->apache_server_info( variant => $variant );

    RT::Test::diag(do {
        open my $fh, '<', $tmp{'config'}{'RT'};
        local $/;
        <$fh>
    });

    my $tmpl = File::Spec->rel2abs( File::Spec->catfile(
        't', 'data', 'configs',
        'apache'. $info{'version'} .'+'. $variant .'.conf'
    ) );
    my %opt = (
        listen         => $port,
        server_root    => $info{'HTTPD_ROOT'} || $ENV{'HTTPD_ROOT'}
            || Test::More::BAIL_OUT("Couldn't figure out server root"),
        document_root  => $RT::MasonComponentRoot,
        tmp_dir        => "$tmp{'directory'}",
        rt_bin_path    => $RT::BinPath,
        rt_sbin_path   => $RT::SbinPath,
        rt_site_config => $ENV{'RT_SITE_CONFIG'},
    );
    foreach (qw(log pid lock)) {
        $opt{$_ .'_file'} = File::Spec->catfile(
            "$tmp{'directory'}", "apache.$_"
        );
    }
    {
        my $method = 'apache_'.$variant.'_server_options';
        $self->$method( \%info, \%opt );
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
        my $tries = 10;
        while ( !-e $opt{'pid_file'} ) {
            $tries--;
            last unless $tries;
            sleep 1;
        }
        Test::More::BAIL_OUT("Couldn't start apache server, no pid file")
            unless -e $opt{'pid_file'};
        open my $pid_fh, '<', $opt{'pid_file'}
            or Test::More::BAIL_OUT("Couldn't open pid file: $!");
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

    RT::Test::diag("Using '$bin' apache executable for testing");

    my $info = `$bin -V`;
    ($res{'version'}) = ($info =~ m{Server\s+version:\s+Apache/(\d+\.\d+)\.});
    Test::More::BAIL_OUT(
        "Couldn't figure out version of the server"
    ) unless $res{'version'};

    my %opts = ($info =~ m/^\s*-D\s+([A-Z_]+?)(?:="(.*)")$/mg);
    %res = (%res, %opts);

    $res{'modules'} = [
        map {s/^\s+//; s/\s+$//; $_}
        grep $_ !~ /Compiled in modules/i,
        split /\r*\n/, `$bin -l`
    ];

    return %res;
}

sub apache_mod_perl_server_options {
    my $self = shift;
    my %info = %{ shift() };
    my $current = shift;

    my %required_modules = (
        '2.2' => [qw(authz_host env alias perl)],
    );
    my @mlist = @{ $required_modules{ $info{'version'} } };

    $current->{'load_modules'} = '';
    foreach my $mod ( @mlist ) {
        next if grep $_ =~ /^(mod_|)$mod\.c$/, @{ $info{'modules'} };

        $current->{'load_modules'} .=
            "LoadModule ${mod}_module $apache_module_prefix/mod_${mod}.so\n";
    }
    return;
}

sub apache_fastcgi_server_options {
    my $self = shift;
    my %info = %{ shift() };
    my $current = shift;

    my %required_modules = (
        '2.2' => [qw(authz_host env alias mime fastcgi)],
    );
    my @mlist = @{ $required_modules{ $info{'version'} } };

    $current->{'load_modules'} = '';
    foreach my $mod ( @mlist ) {
        next if grep $_ =~ /^(mod_|)$mod\.c$/, @{ $info{'modules'} };

        $current->{'load_modules'} .=
            "LoadModule ${mod}_module $apache_module_prefix/mod_${mod}.so\n";
    }
    return;
}

sub find_apache_server {
    my $self = shift;
    return $_ foreach grep defined,
        map RT::Test->find_executable($_),
        qw(httpd apache apache2 apache1);
    return undef;
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
        open $out_fh, '>', $out_conf
            or die "couldn't open '$out_conf': $!";
    }
    print $out_fh $text;
    seek $out_fh, 0, 0;

    return ($out_fh, $out_conf);
}

1;
