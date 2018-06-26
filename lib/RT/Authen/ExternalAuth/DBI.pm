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

package RT::Authen::ExternalAuth::DBI;

use DBI;
use RT::Authen::ExternalAuth::DBI::Cookie;
use RT::Util;

use warnings;
use strict;

=head1 NAME

RT::Authen::ExternalAuth::DBI - External database source for RT authentication

=head1 DESCRIPTION

Provides the database implementation for L<RT::Authen::ExternalAuth>.

=head1 SYNOPSIS

    Set($ExternalSettings, {
        'My_MySQL'   =>  {
            'type'                      =>  'db',

            'dbi_driver'                =>  'DBI_DRIVER',

            'server'                    =>  'server.domain.tld',
            'port'                      =>  'DB_PORT',
            'user'                      =>  'DB_USER',
            'pass'                      =>  'DB_PASS',

            'database'                  =>  'DB_NAME',
            'table'                     =>  'USERS_TABLE',
            'u_field'                   =>  'username',
            'p_field'                   =>  'password',

            # Example of custom hashed password check
            # (See below for security concerns with this implementation)
            #'p_check'                   =>  sub {
            #    my ($hash_from_db, $password) = @_;
            #    return $hash_from_db eq function($password);
            #},

            'p_enc_pkg'                 =>  'Crypt::MySQL',
            'p_enc_sub'                 =>  'password',
            'p_salt'                    =>  'SALT',

            'd_field'                   =>  'disabled',
            'd_values'                  =>  ['0'],

            'attr_match_list' =>  [
                'Gecos',
                'Name',
            ],
            'attr_map' => {
                'Name'           => 'username',
                'EmailAddress'   => 'email',
                'Gecos'          => 'userID',
            },
        },
    } );

=head1 CONFIGURATION

DBI-specific options are described here. Shared options
are described in L<RT::Authen::ExternalAuth>.

The example in the L</SYNOPSIS> lists all available options
and they are described below. See the L<DBI> module for details
on debugging connection issues.

=over 4

=item dbi_driver

The name of the Perl DBI driver to use (e.g. mysql, Pg, SQLite).

=item server

The server hosting the database.

=item port

The port to use to connect on (e.g. 3306).

=item user

The database user for the connection.

=item pass

The password for the database user.

=item database

The database name.

=item table

The database table containing the user information to check against.

=item u_field

The field in the table that holds usernames

=item p_field

The field in the table that holds passwords

=item p_check

Optional.  An anonymous subroutine definition used to check the (presumably
hashed) passed from the database with the password entered by the user logging
in.  The subroutine should return true on success and false on failure.  The
configuration options C<p_enc_pkg> and C<p_enc_sub> will be ignored when
C<p_check> is defined.

An example, where C<FooBar()> is some external hashing function:

    p_check => sub {
        my ($hash_from_db, $password) = @_;
        return $hash_from_db eq FooBar($password);
    },

Importantly, the C<p_check> subroutine allows for arbitrarily complex password
checking unlike C<p_enc_pkg> and C<p_enc_sub>.

Please note, the use of the C<eq> operator in the C<p_check> example above
introduces a timing sidechannel vulnerability. (It was left there for clarity
of the example.) There is a comparison function available in RT that is
hardened against timing attacks. The comparison from the above example could
be re-written with it like this:

    p_check => sub {
        my ($hash_from_db, $password) = @_;
        return RT::Util::constant_time_eq($hash_from_db, FooBar($password));
    },

=item p_enc_pkg, p_enc_sub

The Perl package and subroutine used to encrypt passwords from the
database. For example, if the passwords are stored using the MySQL
v3.23 "PASSWORD" function, then you will need the L<Crypt::MySQL>
C<password> function, but for the MySQL4+ password you will need
L<Crypt::MySQL>'s C<password41>. Alternatively, you could use
L<Digest::MD5> C<md5_hex> or any other encryption subroutine you can
load in your Perl installation.

=item p_salt

If p_enc_sub takes a salt as a second parameter then set it here.

=item d_field, d_values

The field and values in the table that determines if a user should
be disabled. For example, if the field is 'user_status' and the values
are ['0','1','2','disabled'] then the user will be disabled if their
user_status is set to '0','1','2' or the string 'disabled'.
Otherwise, they will be considered enabled.

=back

=cut

sub GetAuth {

    my ($service, $username, $password) = @_;

    my $config = RT->Config->Get('ExternalSettings')->{$service};
    $RT::Logger->debug( "Trying external auth service:",$service);

    my $db_table        = $config->{'table'};
    my $db_u_field      = $config->{'u_field'};
    my $db_p_field          = $config->{'p_field'};
    my $db_p_check      = $config->{'p_check'};
    my $db_p_enc_pkg    = $config->{'p_enc_pkg'};
    my $db_p_enc_sub    = $config->{'p_enc_sub'};
    my $db_p_salt       = $config->{'p_salt'};

    # Set SQL query and bind parameters
    my $query = "SELECT $db_u_field,$db_p_field FROM $db_table WHERE $db_u_field=?";
    my @params = ($username);

    # Uncomment this to trace basic DBI information and drop it in a log for debugging
    # DBI->trace(1,'/tmp/dbi.log');

    # Get DBI handle object (DBH), do SQL query, kill DBH
    my $dbh = _GetBoundDBIObj($config);
    return 0 unless $dbh;

    my $results_hashref = $dbh->selectall_hashref($query,$db_u_field,{},@params);
    $dbh->disconnect();

    my $num_users_returned = scalar keys %$results_hashref;
    if($num_users_returned != 1) { # FAIL
        # FAIL because more than one user returned. Users MUST be unique!
        if ((scalar keys %$results_hashref) > 1) {
            $RT::Logger->info(  $service,
                                "AUTH FAILED",
                                $username,
                                "More than one user with that username!");
        }

        # FAIL because no users returned. Users MUST exist!
        if ((scalar keys %$results_hashref) < 1) {
            $RT::Logger->info(  $service,
                                "AUTH FAILED",
                                $username,
                                "User not found in database!");
        }

            # Drop out to next external authentication service
            return 0;
    }

    # Get the user's password from the database query result
    my $pass_from_db = $results_hashref->{$username}->{$db_p_field};

    if ( $db_p_check ) {
        unless ( ref $db_p_check eq 'CODE' ) {
            $RT::Logger->error( "p_check for $service is not a code" );
            return 0;
        }
        my $check = 0;
        local $@;
        eval {
            $check = $db_p_check->( $pass_from_db, $password );
            1;
        } or do {
            $RT::Logger->error( "p_check for $service failed: $@" );
            return 0;
        };
        unless ( $check ) {
            $RT::Logger->info(
                "$service AUTH FAILED for $username: Password Incorrect (via p_check)"
            );
        } else {
            $RT::Logger->info(  (caller(0))[3],
                                "External Auth OK (",
                                $service,
                                "):",
                                $username);
        }
        return $check;
    }

    # This is the encryption package & subroutine passed in by the config file
    $RT::Logger->debug( "Encryption Package:",
                        $db_p_enc_pkg);
    $RT::Logger->debug( "Encryption Subroutine:",
                        $db_p_enc_sub);

    # Use config info to auto-load the perl package needed for password encryption
    # Jump to next external authentication service on failure
    $db_p_enc_pkg->require or do {
        $RT::Logger->error("AUTH FAILED, Couldn't Load Password Encryption Package. Error: $@");
        return 0;
    };

    my $encrypt = $db_p_enc_pkg->can($db_p_enc_sub);
    if (defined($encrypt)) {
        # If the package given can perform the subroutine given, then use it to compare the
        # password given with the password pulled from the database.
        # Jump to the next external authentication service if they don't match
        if(defined($db_p_salt)) {
            $RT::Logger->debug("Using salt:",$db_p_salt);
            unless (RT::Util::constant_time_eq(${encrypt}->($password,$db_p_salt), $pass_from_db)) {
                $RT::Logger->info(  $service,
                                    "AUTH FAILED",
                                    $username,
                                    "Password Incorrect");
                return 0;
            }
        } else {
            unless (RT::Util::constant_time_eq(${encrypt}->($password), $pass_from_db)) {
                $RT::Logger->info(  $service,
                                    "AUTH FAILED",
                                    $username,
                                    "Password Incorrect");
                return 0;
            }
        }
    } else {
        # If the encryption package can't perform the request subroutine,
        # dump an error and jump to the next external authentication service.
        $RT::Logger->error($service,
                            "AUTH FAILED",
                            "The encryption package you gave me (",
                            $db_p_enc_pkg,
                            ") does not support the encryption method you specified (",
                            $db_p_enc_sub,
                            ")");
            return 0;
    }

    # Any other checks you want to add? Add them here.

    # If we've survived to this point, we're good.
    $RT::Logger->info(  (caller(0))[3],
                        "External Auth OK (",
                        $service,
                        "):",
                        $username);

    return 1;
}

sub CanonicalizeUserInfo {

    my ($service, $key, $value) = @_;

    my $found = 0;
    my %params = (Name         => undef,
                  EmailAddress => undef,
                  RealName     => undef);

    # Load the config
    my $config = RT->Config->Get('ExternalSettings')->{$service};

    # Figure out what's what
    my $table      = $config->{'table'};

    unless ($table) {
        $RT::Logger->critical(  (caller(0))[3],
                                "No table given");
        # Drop out to the next external information service
        return ($found, %params);
    }

    unless ($key && $value){
        $RT::Logger->critical(  (caller(0))[3],
                                " Nothing to look-up given");
        # Drop out to the next external information service
        return ($found, %params);
    }

    # "where" refers to WHERE section of SQL query
    my ($where_key,$where_value) = ("@{[ $key ]}",$value);

    # Get the list of unique attrs we need
    my %db_attrs = map {$_ => 1} values(%{$config->{'attr_map'}});
    my @attrs = keys(%db_attrs);
    my $fields = join(',',@attrs);
    my $query = "SELECT $fields FROM $table WHERE $where_key=?";
    my @bind_params = ($where_value);

    # Uncomment this to trace basic DBI throughput in a log
    # DBI->trace(1,'/tmp/dbi.log');
    my $dbh = _GetBoundDBIObj($config);
    my $results_hashref = $dbh->selectall_hashref($query,$key,{},@bind_params);
    $dbh->disconnect();

    if ((scalar keys %$results_hashref) != 1) {
        # If returned users <> 1, we have no single unique user, so prepare to die
        my $death_msg;

            if ((scalar keys %$results_hashref) == 0) {
            # If no user...
                $death_msg = "No User Found in External Database!";
        } else {
            # If more than one user...
            $death_msg = "More than one user found in External Database with that unique identifier!";
        }

        # Log the death
        $RT::Logger->info(  (caller(0))[3],
                            "INFO CHECK FAILED",
                            "Key: $key",
                            "Value: $value",
                            $death_msg);

        # $found remains as 0

        # Drop out to next external information service
        return ($found, %params);
    }

    # We haven't dropped out, so DB search must have succeeded with
    # exactly 1 result. Get the result and set $found to 1
    my $result = $results_hashref->{$value};

    # Use the result to populate %params for every key we're given in the config
    foreach my $key (keys(%{$config->{'attr_map'}})) {
        $params{$key} = ($result->{$config->{'attr_map'}->{$key}})[0];
    }

    $found = 1;

    return ($found, %params);
}

sub UserExists {

    my ($username,$service) = @_;
    my $config              = RT->Config->Get('ExternalSettings')->{$service};
    my $table                   = $config->{'table'};
    my $u_field             = $config->{'u_field'};
    my $query               = "SELECT $u_field FROM $table WHERE $u_field=?";
    my @bind_params         = ($username);

    # Uncomment this to do a basic trace on DBI information and log it
    # DBI->trace(1,'/tmp/dbi.log');

    # Get DBI Object, do the query, disconnect
    my $dbh = _GetBoundDBIObj($config);
    my $results_hashref = $dbh->selectall_hashref($query,$u_field,{},@bind_params);
    $dbh->disconnect();

    my $num_of_results = scalar keys %$results_hashref;

    if ($num_of_results > 1) {
        # If more than one result returned, die because we the username field should be unique!
        $RT::Logger->debug( "Disable Check Failed :: (",
                            $service,
                            ")",
                            $username,
                            "More than one user with that username!");
        return 0;
    } elsif ($num_of_results < 1) {
        # If 0 or negative integer, no user found or major failure
        $RT::Logger->debug( "Disable Check Failed :: (",
                            $service,
                            ")",
                            $username,
                            "User not found");
        return 0;
    }

    # Number of results is exactly one, so we found the user we were looking for
    return 1;
}

sub UserDisabled {

    my ($username,$service) = @_;

    # FIRST, check that the user exists in the DBI service
    unless(UserExists($username,$service)) {
        $RT::Logger->debug("User (",$username,") doesn't exist! - Assuming not disabled for the purposes of disable checking");
        return 0;
    }

    # Get the necessary config info
    my $config              = RT->Config->Get('ExternalSettings')->{$service};
    my $table                   = $config->{'table'};
    my $u_field             = $config->{'u_field'};
    my $disable_field       = $config->{'d_field'};
    my $disable_values_list = $config->{'d_values'};

    unless ($disable_field) {
        # If we don't know how to check for disabled users, consider them all enabled.
        $RT::Logger->debug("No d_field specified for this DBI service (",
                            $service,
                            "), so considering all users enabled");
        return 0;
    }

    my $query = "SELECT $u_field,$disable_field FROM $table WHERE $u_field=?";
    my @bind_params = ($username);

    # Uncomment this to do a basic trace on DBI information and log it
    # DBI->trace(1,'/tmp/dbi.log');

    # Get DBI Object, do the query, disconnect
    my $dbh = _GetBoundDBIObj($config);
    my $results_hashref = $dbh->selectall_hashref($query,$u_field,{},@bind_params);
    $dbh->disconnect();

    my $num_of_results = scalar keys %$results_hashref;

    if ($num_of_results > 1) {
        # If more than one result returned, die because we the username field should be unique!
        $RT::Logger->debug( "Disable Check Failed :: (",
                            $service,
                            ")",
                            $username,
                            "More than one user with that username! - Assuming not disabled");
        # Drop out to next service for an info check
        return 0;
    } elsif ($num_of_results < 1) {
        # If 0 or negative integer, no user found or major failure
        $RT::Logger->debug( "Disable Check Failed :: (",
                            $service,
                            ")",
                            $username,
                            "User not found - Assuming not disabled");
        # Drop out to next service for an info check
        return 0;
    } else {
        # otherwise all should be well

        # $user_db_disable_value = The value for "disabled" returned from the DB
        my $user_db_disable_value = $results_hashref->{$username}->{$disable_field};

        # For each of the values in the (list of values that we consider to mean the user is disabled)..
        foreach my $disable_value (@{$disable_values_list}){
            $RT::Logger->debug( "DB Disable Check:",
                                "User's Val is $user_db_disable_value,",
                                "Checking against: $disable_value");

            # If the value from the DB matches a value from the list, the user is disabled.
            if ($user_db_disable_value eq $disable_value) {
                return 1;
            }
        }

        # If we've not returned yet, the user can't be disabled
        return 0;
    }
    $RT::Logger->crit("It is seriously not possible to run this code.. what the hell did you do?!");
    return 0;
}

sub GetCookieAuth {

    $RT::Logger->debug( (caller(0))[3],
                        "Checking Browser Cookies for an Authenticated User");

    # Get our cookie and database info...
    my $config = shift;

    my $username = undef;
    my $cookie_name = $config->{'name'};

    my $cookie_value = RT::Authen::ExternalAuth::DBI::Cookie::GetCookieVal($cookie_name);

    unless($cookie_value){
        return $username;
    }

    # The table mapping usernames to the Username Match Key
    my $u_table     = $config->{'u_table'};
    # The username field in that table
    my $u_field     = $config->{'u_field'};
    # The field that contains the Username Match Key
    my $u_match_key = $config->{'u_match_key'};

    # The table mapping cookie values to the Cookie Match Key
    my $c_table     = $config->{'c_table'};
    # The cookie field in that table - The same as the cookie name if unspecified
    my $c_field     = $config->{'c_field'};
    # The field that connects the Cookie Match Key
    my $c_match_key = $config->{'c_match_key'};

    # These are random characters to assign as table aliases in SQL
    # It saves a lot of garbled code later on
    my $u_table_alias = "u";
    my $c_table_alias = "c";

    # $tables will be passed straight into the SQL query
    # I don't see this as a security issue as only the admin may modify the config file anyway
    my $tables;

    # If the tables are the same, then the aliases should be the same
    # and the match key becomes irrelevant. Ensure this all works out
    # fine by setting both sides the same. In either case, set an
    # appropriate value for $tables.
    if ($u_table eq $c_table) {
            $u_table_alias  = $c_table_alias;
            $u_match_key    = $c_match_key;
            $tables         = "$c_table $c_table_alias";
    } else {
            $tables = "$c_table $c_table_alias, $u_table $u_table_alias";
    }

    my $select_fields = "$u_table_alias.$u_field";
    my $where_statement = "$c_table_alias.$c_field = ? AND $c_table_alias.$c_match_key = $u_table_alias.$u_match_key";

    my $query = "SELECT $select_fields FROM $tables WHERE $where_statement";
    my @params = ($cookie_value);

    # Use this if you need to debug the DBI SQL process
    # DBI->trace(1,'/tmp/dbi.log');

    my $dbh = _GetBoundDBIObj(RT->Config->Get('ExternalSettings')->{$config->{'db_service_name'}});
    my $query_result_arrayref = $dbh->selectall_arrayref($query,{},@params);
    $dbh->disconnect();

    # The log messages say it all here...
    my $num_rows = scalar @$query_result_arrayref;
    if ($num_rows < 1) {
        $RT::Logger->info(  "AUTH FAILED",
                            $cookie_name,
                            "Cookie value not found in database.",
                            "User passed an authentication token they were not given by us!",
                            "Is this nefarious activity?");
    } elsif ($num_rows > 1) {
        $RT::Logger->error( "AUTH FAILED",
                            $cookie_name,
                            "Cookie's value is duplicated in the database! This should not happen!!");
    } else {
        $username = $query_result_arrayref->[0][0];
    }

    if ($username) {
        $RT::Logger->debug( "User (",
                            $username,
                            ") was authenticated by a browser cookie");
    } else {
        $RT::Logger->debug( "No user was authenticated by browser cookie");
    }

    return $username;

}


# {{{ sub _GetBoundDBIObj

sub _GetBoundDBIObj {

    # Config as hashref.
    my $config = shift;

    # Extract the relevant information from the config.
    my $db_server     = $config->{'server'};
    my $db_user       = $config->{'user'};
    my $db_pass       = $config->{'pass'};
    my $db_database   = $config->{'database'};
    my $db_port       = $config->{'port'};
    my $dbi_driver    = $config->{'dbi_driver'};

    # Use config to create a DSN line for the DBI connection
    my $dsn;
    if ( $dbi_driver eq 'SQLite' ) {
        $dsn = "dbi:$dbi_driver:$db_database";
    }
    else {
        $dsn = "dbi:$dbi_driver:database=$db_database;host=$db_server;port=$db_port";
    }

    # Now let's get connected
    my $dbh = DBI->connect($dsn, $db_user, $db_pass,{RaiseError => 1, AutoCommit => 0 })
            or die $DBI::errstr;

    # If we didn't die, return the DBI object handle
    # and hope it's treated sensibly and correctly
    # destroyed by the calling code
    return $dbh;
}

# }}}

RT::Base->_ImportOverlays();

1;
