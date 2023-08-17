use strict;
use warnings;

use Test::More tests => 4;

use RT::Interface::Web::ReportsRegistry;

# make sure all reports are registered
{
    my $reports = RT::Interface::Web::ReportsRegistry->Reports;
    my @paths   = sort { $a cmp $b } map { $_->{path} } @$reports;

    my $reports_dir = 'share/html/Reports';
    opendir my $dh, $reports_dir or die "Can't open dir $reports_dir: $!";
    my @expected = sort { $a cmp $b }
        map {"/Reports/$_"}
        grep { -f "$reports_dir/$_" && !/index/ } readdir $dh;
    closedir $dh;

    is_deeply( \@paths, \@expected, 'all reports are registered' );
}

# register a report, second time should overwrite the record
{
    my $report = {
        id    => 'my_super_report',
        title => 'Super report',
        path  => 'MySuperReport.html',
    };
    RT::Interface::Web::ReportsRegistry->Register(%$report);

    my $expected = {
        id    => 'my_super_report',
        title => 'Super report',
        path  => '/Reports/MySuperReport.html',
    };
    my $got = get_report_by_id( $report->{id} );
    is_deeply( $got, $expected, 'report is registered' );

    # overwrite the record
    $report->{title} = 'Super-duper report';
    RT::Interface::Web::ReportsRegistry->Register(%$report);

    $got = get_report_by_id( $report->{id} );
    $expected->{title} = 'Super-duper report';
    is_deeply( $got, $expected, 'report is overwritten' );
}

# check ListOfReports in RT::Interface::Web
{
    require RT::Interface::Web;
    my $reports1 = RT::Interface::Web::ReportsRegistry->Reports;
    my $reports2 = HTML::Mason::Commands::ListOfReports();
    is_deeply( $reports1, $reports2,
        'ReportsRegistry->Reports == ListOfReports' );
}

sub get_report_by_id {
    my $id      = shift;
    my $reports = RT::Interface::Web::ReportsRegistry->Reports;
    return ( grep { $_->{id} eq $id } @$reports )[0];
}
