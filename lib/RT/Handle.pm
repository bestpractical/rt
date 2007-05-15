# BEGIN BPS TAGGED BLOCK {{{
# 
# COPYRIGHT:
#  
# This software is Copyright (c) 1996-2007 Best Practical Solutions, LLC 
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
# http://www.gnu.org/copyleft/gpl.html.
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
=head1 NAME

  RT::Handle - RT's database handle

=head1 SYNOPSIS

  use RT::Handle;

=head1 DESCRIPTION

=begin testing

ok(require RT::Handle);

=end testing

=head1 METHODS

=cut

package RT::Handle;

use strict;
use vars qw/@ISA/;

eval "use DBIx::SearchBuilder::Handle::". RT->Config->Get('DatabaseType') .";
\@ISA= qw(DBIx::SearchBuilder::Handle::". RT->Config->Get('DatabaseType') .");";

if ($@) {
    die "Unable to load DBIx::SearchBuilder database handle for '". RT->Config->Get('DatabaseType') ."'.".
        "\n".
        "Perhaps you've picked an invalid database type or spelled it incorrectly.".
        "\n". $@;
}

=head2 Connect

Connects to RT's database handle.
Takes nothing. Calls SUPER::Connect with the needed args

=cut

sub Connect {
    my $self = shift;

    if (RT->Config->Get('DatabaseType') eq 'Oracle') {
        $ENV{'NLS_LANG'} = "AMERICAN_AMERICA.AL32UTF8";
        $ENV{'NLS_NCHAR'} = "AL32UTF8";
        
    }

    $self->SUPER::Connect(
			 User => RT->Config->Get('DatabaseUser'),
			 Password => RT->Config->Get('DatabasePassword'),
			);

    $self->dbh->{LongReadLen} = RT->Config->Get('MaxAttachmentSize');
   
}

=head2 BuildDSN

Build the DSN for the RT database. doesn't take any parameters, draws all that
from the config file.

=cut

use File::Spec;

sub BuildDSN {
    my $self = shift;
# Unless the database port is a positive integer, we really don't want to pass it.
    my $db_port = RT->Config->Get('DatabasePort');
    $db_port = undef unless (defined $db_port && $db_port =~ /^(\d+)$/);
    my $db_host = RT->Config->Get('DatabaseHost');
    $db_host = undef unless $db_host;
    my $db_name = RT->Config->Get('DatabaseName');
    my $db_type = RT->Config->Get('DatabaseType');
    $db_name = File::Spec->catfile($RT::VarPath, $db_name)
        if $db_type eq 'SQLite' && !File::Spec->file_name_is_absolute($db_name);


    $self->SUPER::BuildDSN( Host       => $db_host,
			                Database   => $db_name,
                            Port       => $db_port,
                            Driver     => $db_type,
                            RequireSSL => RT->Config->Get('DatabaseRequireSSL'),
                            DisconnectHandleOnDestroy => 1,
                          );
   

}

eval "require RT::Handle_Vendor";
die $@ if ($@ && $@ !~ qr{^Can't locate RT/Handle_Vendor.pm});
eval "require RT::Handle_Local";
die $@ if ($@ && $@ !~ qr{^Can't locate RT/Handle_Local.pm});

1;
