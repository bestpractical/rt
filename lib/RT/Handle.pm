# BEGIN LICENSE BLOCK
# 
# Copyright (c) 1996-2003 Jesse Vincent <jesse@bestpractical.com>
# 
# (Except where explictly superceded by other copyright notices)
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
# Unless otherwise specified, all modifications, corrections or
# extensions to this work which alter its source code become the
# property of Best Practical Solutions, LLC when submitted for
# inclusion in the work.
# 
# 
# END LICENSE BLOCK
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

eval "use DBIx::SearchBuilder::Handle::$RT::DatabaseType;
\@ISA= qw(DBIx::SearchBuilder::Handle::$RT::DatabaseType);";
#TODO check for errors here.

=head2 Connect

Connects to RT's database handle.
Takes nothing. Calls SUPER::Connect with the needed args

=cut

sub Connect {
my $self=shift;


    if ($RT::DatabaseType eq 'Oracle') {
        $ENV{'NLS_LANG'} = ".UTF8";
    }

    $self->SUPER::Connect(
			 User => $RT::DatabaseUser,
			 Password => $RT::DatabasePassword,
			);
   
}

=item BuildDSN

Build the DSN for the RT database. doesn't take any parameters, draws all that
from the config file.

=cut


sub BuildDSN {
    my $self = shift;
# Unless the database port is a positive integer, we really don't want to pass it.
$RT::DatabasePort = undef unless (defined $RT::DatabasePort && $RT::DatabasePort =~ /^(\d+)$/);
$RT::DatabaseHost = undef unless (defined $RT::DatabaseHost && $RT::DatabaseHost ne '');


    $self->SUPER::BuildDSN(Host => $RT::DatabaseHost, 
			 Database => $RT::DatabaseName, 
			 Port => $RT::DatabasePort,
			 Driver => $RT::DatabaseType,
			 RequireSSL => $RT::DatabaseRequireSSL,
             DisconnectHandleOnDestroy => 1
			);
   

}

eval "require RT::Handle_Vendor";
die $@ if ($@ && $@ !~ qr{^Can't locate RT/Handle_Vendor.pm});
eval "require RT::Handle_Local";
die $@ if ($@ && $@ !~ qr{^Can't locate RT/Handle_Local.pm});

1;
