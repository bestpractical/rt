#line 1 "inc/Module/Install/RTx.pm - /usr/local/share/perl/5.8.7/Module/Install/RTx.pm"
package Module::Install::RTx;
use Module::Install::Base; @ISA = qw(Module::Install::Base);

$Module::Install::RTx::VERSION = '0.11';

use strict;
use FindBin;
use File::Glob ();
use File::Basename ();

sub RTx {
    my ($self, $name) = @_;
    my $RTx = 'RTx';
    $RTx = $1 if $name =~ s/^(\w+)-//;
    my $fname = $name;
    $fname =~ s!-!/!g;

    $self->name("$RTx-$name")
        unless $self->name;
    $self->abstract("RT $name Extension")
        unless $self->abstract;
    $self->version_from (-e "$name.pm" ? "$name.pm" : "lib/$RTx/$fname.pm")
        unless $self->version;

    my @prefixes = (qw(/opt /usr/local /home /usr /sw ));
    my $prefix = $ENV{PREFIX};
    @ARGV = grep { /PREFIX=(.*)/ ? (($prefix = $1), 0) : 1 } @ARGV;

    if ($prefix) {
        $RT::LocalPath = $prefix;
        $INC{'RT.pm'} = "$RT::LocalPath/lib/RT.pm";
    }
    else {
        local @INC = (
            @INC,
            $ENV{RTHOME} ? ($ENV{RTHOME}, "$ENV{RTHOME}/lib") : (),
            map {( "$_/rt3/lib", "$_/lib/rt3", "$_/lib" )} grep $_, @prefixes
        );
        until ( eval { require RT; $RT::LocalPath } ) {
            warn "Cannot find the location of RT.pm that defines \$RT::LocalPath in: @INC\n";
            $_ = $self->prompt("Path to your RT.pm:") or exit;
            push @INC, $_, "$_/rt3/lib", "$_/lib/rt3";
        }
    }

    my $lib_path = File::Basename::dirname($INC{'RT.pm'});
    print "Using RT configurations from $INC{'RT.pm'}:\n";

    $RT::LocalVarPath	||= $RT::VarPath;
    $RT::LocalPoPath	||= $RT::LocalLexiconPath;
    $RT::LocalHtmlPath	||= $RT::MasonComponentRoot;

    my %path;
    my $with_subdirs = $ENV{WITH_SUBDIRS};
    @ARGV = grep { /WITH_SUBDIRS=(.*)/ ? (($with_subdirs = $1), 0) : 1 } @ARGV;
    my %subdirs = map { $_ => 1 } split(/\s*,\s*/, $with_subdirs);

    foreach (qw(bin etc html po sbin var)) {
        next unless -d "$FindBin::Bin/$_";
        next if %subdirs and !$subdirs{$_};
        $self->no_index( directory => $_ );

        no strict 'refs';
        my $varname = "RT::Local" . ucfirst($_) . "Path";
        $path{$_} = ${$varname} || "$RT::LocalPath/$_";
    }

    $path{$_} .= "/$name" for grep $path{$_}, qw(etc po var);
    my $args = join(', ', map "q($_)", %path);
    $path{lib} = "$RT::LocalPath/lib" unless %subdirs and !$subdirs{'lib'};
    print "./$_\t=> $path{$_}\n" for sort keys %path;

    if (my @dirs = map { (-D => $_) } grep $path{$_}, qw(bin html sbin)) {
        my @po = map { (-o => $_) } grep -f, File::Glob::bsd_glob("po/*.po");
        $self->postamble(<< ".") if @po;
lexicons ::
\t\$(NOECHO) \$(PERL) -MLocale::Maketext::Extract::Run=xgettext -e \"xgettext(qw(@dirs @po))\"
.
    }

    my $postamble = << ".";
install ::
\t\$(NOECHO) \$(PERL) -MExtUtils::Install -e \"install({$args})\"
.

    if ($path{var} and -d $RT::MasonDataDir) {
        my ($uid, $gid) = (stat($RT::MasonDataDir))[4, 5];
        $postamble .= << ".";
\t\$(NOECHO) chown -R $uid:$gid $path{var}
.
    }

    my %has_etc;
    if (File::Glob::bsd_glob("$FindBin::Bin/etc/schema.*")) {
        # got schema, load factory module
        $has_etc{schema}++;
        $self->load('RTxFactory');
        $self->postamble(<< ".");
factory ::
\t\$(NOECHO) \$(PERL) -Ilib -I"$lib_path" -Minc::Module::Install -e"RTxFactory(qw($RTx $name))"

dropdb ::
\t\$(NOECHO) \$(PERL) -Ilib -I"$lib_path" -Minc::Module::Install -e"RTxFactory(qw($RTx $name drop))"

.
    }
    if (File::Glob::bsd_glob("$FindBin::Bin/etc/acl.*")) {
        $has_etc{acl}++;
    }
    if (-e 'etc/initialdata') {
        $has_etc{initialdata}++;
    }

    $self->postamble("$postamble\n");
    if (%subdirs and !$subdirs{'lib'}) {
        $self->makemaker_args(
            PM => { "" => "" },
        )
    }
    else {
        $self->makemaker_args( INSTALLSITELIB => "$RT::LocalPath/lib" );
    }

    if (%has_etc) {
        $self->load('RTxInitDB');
        print "For first-time installation, type 'make initdb'.\n";
        my $initdb = '';
        $initdb .= <<"." if $has_etc{schema};
\t\$(NOECHO) \$(PERL) -Ilib -I"$lib_path" -Minc::Module::Install -e"RTxInitDB(qw(schema))"
.
        $initdb .= <<"." if $has_etc{acl};
\t\$(NOECHO) \$(PERL) -Ilib -I"$lib_path" -Minc::Module::Install -e"RTxInitDB(qw(acl))"
.
        $initdb .= <<"." if $has_etc{initialdata};
\t\$(NOECHO) \$(PERL) -Ilib -I"$lib_path" -Minc::Module::Install -e"RTxInitDB(qw(insert))"
.
        $self->postamble("initdb ::\n$initdb\n");
        $self->postamble("initialize-database ::\n$initdb\n");
    }
}

sub RTxInit {
    unshift @INC, substr(delete($INC{'RT.pm'}), 0, -5) if $INC{'RT.pm'};
    require RT;
    RT::LoadConfig();
    RT::ConnectToDatabase();

    die "Cannot load RT" unless $RT::Handle and $RT::DatabaseType;
}

1;

__END__

#line 221

#line 242
