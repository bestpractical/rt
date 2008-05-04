use inc::Module::Install;
RTx('RT-FM');
name('RTFM');
version_from('lib/RT/FM.pm');
license('GPL version 2');
requires(
    RT                => '3.004002',
    Text::WikiFormat  => 0,
    Tree::Simple      => 0,
    HTML::TreeBuilder => 0,
    Time::ParseDate   => 0,
    HTML::FormatText  => 0,
);
auto_install();

my ($lp) = ($INC{'RT.pm'} =~ /^(.*)[\\\/]/);
my $lib_path = join( ' ', "$RT::LocalPath/lib", $lp );
my $sbin_path = $RT::SbinPath || "$RT::BasePath/sbin" || "/opt/rt3/sbin";
my $bin_path = $RT::BinPath || "$RT::BasePath/bin" || "/opt/rt3/bin";

substitute(
    {
        RT_LIB_PATH  => $lib_path,
        RT_BIN_PATH  => $bin_path,
        RT_SBIN_PATH => $sbin_path,
    },
    qw(t/utils.pl),
);

WriteAll();
