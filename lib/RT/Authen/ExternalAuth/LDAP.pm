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

package RT::Authen::ExternalAuth::LDAP;

use Net::LDAP qw(LDAP_SUCCESS LDAP_PARTIAL_RESULTS);
use Net::LDAP::Util qw(ldap_error_name escape_filter_value);
use Net::LDAP::Filter;

use warnings;
use strict;

=head1 NAME

RT::Authen::ExternalAuth::LDAP - LDAP source for RT authentication

=head1 DESCRIPTION

Provides the LDAP implementation for L<RT::Authen::ExternalAuth>.

=head1 SYNOPSIS

    Set($ExternalSettings, {
        # AN EXAMPLE LDAP SERVICE
        'My_LDAP'       =>  {
            'type'                      =>  'ldap',

            'server'                    =>  'server.domain.tld',
            'user'                      =>  'rt_ldap_username',
            'pass'                      =>  'rt_ldap_password',

            'base'                      =>  'ou=Organisational Unit,dc=domain,dc=TLD',
            'filter'                    =>  '(FILTER_STRING)',
            'd_filter'                  =>  '(FILTER_STRING)',

            'group'                     =>  'GROUP_NAME',
            'group_attr'                =>  'GROUP_ATTR',

            'tls'                       =>  { verify => "require", capath => "/path/to/ca.pem" },

            'net_ldap_args'             => [    version =>  3   ],

            'attr_match_list' => [
                'Name',
                'EmailAddress',
            ],
            'attr_map' => {
                'Name' => 'sAMAccountName',
                'EmailAddress' => 'mail',
                'Organization' => 'physicalDeliveryOfficeName',
                'RealName' => 'cn',
                'Gecos' => 'sAMAccountName',
                'WorkPhone' => 'telephoneNumber',
                'Address1' => 'streetAddress',
                'City' => 'l',
                'State' => 'st',
                'Zip' => 'postalCode',
                'Country' => 'co'
            },
        },
    } );

=head1 CONFIGURATION

LDAP-specific options are described here. Shared options
are described in L<RT::Authen::ExternalAuth>.

The example in the L</SYNOPSIS> lists all available options
and they are described below. Note that many of these values
are specific to LDAP, so you should consult your LDAP
documentation for details.

=over 4

=item server

The server hosting the LDAP or AD service.

=item user, pass

The username and password RT should use to connect to the LDAP
server.

If you can bind to your LDAP server anonymously you may be able to omit these
options.  Many servers do not allow anonymous binds, or restrict what information
they can see or how much information they can retrieve.  If your server does not
allow anonymous binds then you must have a service account created for this
component to function.

=item base

The LDAP search base.

=item filter

The filter to use to match RT users. You B<must> specify it
and it B<must> be a valid LDAP filter encased in parentheses.

For example:

    filter => '(objectClass=*)',

=item d_filter

The filter that will only match disabled users. Optional.
B<Must> be a valid LDAP filter encased in parentheses.

For example with Active Directory the following can be used:

    d_filter => '(userAccountControl:1.2.840.113556.1.4.803:=2)'

=item group

Does authentication depend on group membership? What group name?

=item group_attr

What is the attribute for the group object that determines membership?

=item group_scope

What is the scope of the group search? C<base>, C<one> or C<sub>.
Optional; defaults to C<base>, which is good enough for most cases.
C<sub> is appropriate when you have nested groups.

=item group_attr_value

What is the attribute of the user entry that should be matched against
group_attr above? Optional; defaults to C<dn>.

=item tls

Should we try to use TLS to encrypt connections?  Either a scalar, for
simple enabling, or a hash of values to pass to L<Net::LDAP/start_tls>.
By default, L<Net::LDAP> does B<no> certificate validation!  To validate
certificates, pass:

    tls => { verify => 'require',
             cafile => "/etc/ssl/certs/ca.pem",  # Path CA file
           },

=item net_ldap_args

What other args should be passed to Net::LDAP->new($host,@args)?

=back

=cut

sub GetAuth {

    my ($service, $username, $password) = @_;

    my $config = RT->Config->Get('ExternalSettings')->{$service};
    $RT::Logger->debug( "Trying external auth service:",$service);

    my $base            = $config->{'base'};
    my $filter          = $config->{'filter'};
    my $group           = $config->{'group'};
    my $group_attr      = $config->{'group_attr'};
    my $group_attr_val  = $config->{'group_attr_value'} || 'dn';
    my $group_scope     = $config->{'group_scope'} || 'base';
    my $attr_map        = $config->{'attr_map'};
    my @attrs           = ('dn');

    # Make sure we fetch the user attribute we'll need for the group check
    push @attrs, $group_attr_val
        unless lc $group_attr_val eq 'dn';

    # Empty parentheses as filters cause Net::LDAP to barf.
    # We take care of this by using Net::LDAP::Filter, but
    # there's no harm in fixing this right now.
    undef $filter if defined $filter and $filter eq "()";

    # Now let's get connected
    my $ldap = _GetBoundLdapObj($config);
    return 0 unless ($ldap);

    $filter = Net::LDAP::Filter->new(   '(&(' .
                                        $attr_map->{'Name'} .
                                        '=' .
                                        escape_filter_value($username) .
                                        ')' .
                                        $filter .
                                        ')'
                                    );

    $RT::Logger->debug( "LDAP Search === ",
                        "Base:",
                        $base,
                        "== Filter:",
                        $filter->as_string,
                        "== Attrs:",
                        join(',',@attrs));

    my $ldap_msg = $ldap->search(   base   => $base,
                                    filter => $filter,
                                    attrs  => \@attrs);

    unless ($ldap_msg->code == LDAP_SUCCESS || $ldap_msg->code == LDAP_PARTIAL_RESULTS) {
        $RT::Logger->debug( "search for",
                            $filter->as_string,
                            "failed:",
                            ldap_error_name($ldap_msg->code),
                            $ldap_msg->code);
        # Didn't even get a partial result - jump straight to the next external auth service
        return 0;
    }

    unless ($ldap_msg->count == 1) {
        $RT::Logger->info(  $service,
                            "AUTH FAILED:",
                            $username,
                            "User not found or more than one user found");
        # We got no user, or too many users.. jump straight to the next external auth service
        return 0;
    }

    my $ldap_entry = $ldap_msg->first_entry;
    my $ldap_dn    = $ldap_entry->dn;

    $RT::Logger->debug( "Found LDAP DN:",
                        $ldap_dn);

    # THIS bind determines success or failure on the password.
    $ldap_msg = $ldap->bind($ldap_dn, password => $password);

    unless ($ldap_msg->code == LDAP_SUCCESS) {
        $RT::Logger->info(  $service,
                            "AUTH FAILED",
                            $username,
                            "(can't bind:",
                            ldap_error_name($ldap_msg->code),
                            $ldap_msg->code,
                            ")");
        # Could not bind to the LDAP server as the user we found with the password
        # we were given, therefore the password must be wrong so we fail and
        # jump straight to the next external auth service
        return 0;
    }

    # The user is authenticated ok, but is there an LDAP Group to check?
    if ($group) {
        my $group_val = lc $group_attr_val eq 'dn'
                            ? $ldap_dn
                            : $ldap_entry->get_value($group_attr_val);

        # Fallback to the DN if the user record doesn't have a value
        unless (defined $group_val) {
            $group_val = $ldap_dn;
            $RT::Logger->debug("Attribute '$group_attr_val' has no value; falling back to '$group_val'");
        }

        # We only need the dn for the actual group since all we care about is existence
        @attrs  = qw(dn);
        $filter = Net::LDAP::Filter->new("(${group_attr}=" . escape_filter_value($group_val) . ")");

        $RT::Logger->debug( "LDAP Search === ",
                            "Base:",
                            $group,
                            "== Scope:",
                            $group_scope,
                            "== Filter:",
                            $filter->as_string,
                            "== Attrs:",
                            join(',',@attrs));

        $ldap_msg = $ldap->search(  base   => $group,
                                    filter => $filter,
                                    attrs  => \@attrs,
                                    scope  => $group_scope);

        # And the user isn't a member:
        unless ($ldap_msg->code == LDAP_SUCCESS ||
                $ldap_msg->code == LDAP_PARTIAL_RESULTS) {
            $RT::Logger->critical(  "Search for",
                                    $filter->as_string,
                                    "failed:",
                                    ldap_error_name($ldap_msg->code),
                                    $ldap_msg->code);

            # Fail auth - jump to next external auth service
            return 0;
        }

        unless ($ldap_msg->count == 1) {
            $RT::Logger->debug(
                "LDAP group membership check returned",
                $ldap_msg->count, "results"
            );
            $RT::Logger->info(  $service,
                                "AUTH FAILED:",
                                $username);

            # Fail auth - jump to next external auth service
            return 0;
        }
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
    my $base            = $config->{'base'};
    my $filter          = $config->{'filter'};

    # Get the list of unique attrs we need
    my @attrs = values(%{$config->{'attr_map'}});

    # This is a bit confusing and probably broken. Something to revisit..
    my $filter_addition = ($key && $value) ? "(". $key . "=". escape_filter_value($value) .")" : "";
    if(defined($filter) && ($filter ne "()")) {
        $filter = Net::LDAP::Filter->new(   "(&" .
                                            $filter .
                                            $filter_addition .
                                            ")"
                                        );
    } else {
        $RT::Logger->debug( "LDAP Filter invalid or not present.");
    }

    unless (defined($base)) {
        $RT::Logger->critical(  (caller(0))[3],
                                "LDAP baseDN not defined");
        # Drop out to the next external information service
        return ($found, %params);
    }

    # Get a Net::LDAP object based on the config we provide
    my $ldap = _GetBoundLdapObj($config);

    # Jump to the next external information service if we can't get one,
    # errors should be logged by _GetBoundLdapObj so we don't have to.
    return ($found, %params) unless ($ldap);

    # Do a search for them in LDAP
    $RT::Logger->debug( "LDAP Search === ",
                        "Base:",
                        $base,
                        "== Filter:",
                        $filter->as_string,
                        "== Attrs:",
                        join(',',@attrs));

    my $ldap_msg = $ldap->search(base   => $base,
                                 filter => $filter,
                                 attrs  => \@attrs);

    # If we didn't get at LEAST a partial result, just die now.
    if ($ldap_msg->code != LDAP_SUCCESS and
        $ldap_msg->code != LDAP_PARTIAL_RESULTS) {
        $RT::Logger->critical(  (caller(0))[3],
                                ": Search for ",
                                $filter->as_string,
                                " failed: ",
                                ldap_error_name($ldap_msg->code),
                                $ldap_msg->code);
        # $found remains as 0

        # Drop out to the next external information service
        $ldap_msg = $ldap->unbind();
        if ($ldap_msg->code != LDAP_SUCCESS) {
            $RT::Logger->critical(  (caller(0))[3],
                                    ": Could not unbind: ",
                                    ldap_error_name($ldap_msg->code),
                                    $ldap_msg->code);
        }
        undef $ldap;
        undef $ldap_msg;
        return ($found, %params);

    } else {
        # If there's only one match, we're good; more than one and
        # we don't know which is the right one so we skip it.
        if ($ldap_msg->count == 1) {
            my $entry = $ldap_msg->first_entry();
            foreach my $key (keys(%{$config->{'attr_map'}})) {
                # XXX TODO: This legacy code wants to be removed since modern
                # configs will always fall through to the else and the logic is
                # weird even if you do have the old config.
                if ($RT::LdapAttrMap and $RT::LdapAttrMap->{$key} eq 'dn') {
                    $params{$key} = $entry->dn();
                } else {
                    $params{$key} =
                      ($entry->get_value($config->{'attr_map'}->{$key}))[0];
                }
            }
            $found = 1;
        } else {
            # Drop out to the next external information service
            $ldap_msg = $ldap->unbind();
            if ($ldap_msg->code != LDAP_SUCCESS) {
                $RT::Logger->critical(  (caller(0))[3],
                                        ": Could not unbind: ",
                                        ldap_error_name($ldap_msg->code),
                                        $ldap_msg->code);
            }
            undef $ldap;
            undef $ldap_msg;
            return ($found, %params);
        }
    }
    $ldap_msg = $ldap->unbind();
    if ($ldap_msg->code != LDAP_SUCCESS) {
        $RT::Logger->critical(  (caller(0))[3],
                                ": Could not unbind: ",
                                ldap_error_name($ldap_msg->code),
                                $ldap_msg->code);
    }

    undef $ldap;
    undef $ldap_msg;

    return ($found, %params);
}

sub UserExists {
    my ($username,$service) = @_;
   $RT::Logger->debug("UserExists params:\nusername: $username , service: $service");
    my $config              = RT->Config->Get('ExternalSettings')->{$service};

    my $base                = $config->{'base'};
    my $filter              = $config->{'filter'};

    # While LDAP filters must be surrounded by parentheses, an empty set
    # of parentheses is an invalid filter and will cause failure
    # This shouldn't matter since we are now using Net::LDAP::Filter below,
    # but there's no harm in doing this to be sure
    undef $filter if defined $filter and $filter eq "()";

    if (defined($config->{'attr_map'}->{'Name'})) {
        # Construct the complex filter
        $filter = Net::LDAP::Filter->new(           '(&' .
                                                    $filter .
                                                    '(' .
                                                    $config->{'attr_map'}->{'Name'} .
                                                    '=' .
                                                    escape_filter_value($username) .
                                                    '))'
                                        );
    }

    my $ldap = _GetBoundLdapObj($config);
    return unless $ldap;

    my @attrs = values(%{$config->{'attr_map'}});

    # Check that the user exists in the LDAP service
    $RT::Logger->debug( "LDAP Search === ",
                        "Base:",
                        $base,
                        "== Filter:",
                        ($filter ? $filter->as_string : ''),
                        "== Attrs:",
                        join(',',@attrs));

    my $user_found = $ldap->search( base    => $base,
                                    filter  => $filter,
                                    attrs   => \@attrs);

    if($user_found->count < 1) {
        # If 0 or negative integer, no user found or major failure
        $RT::Logger->debug( "User Check Failed :: (",
                            $service,
                            ")",
                            $username,
                            "User not found");
        return 0;
    } elsif ($user_found->count > 1) {
        # If more than one result returned, die because we the username field should be unique!
        $RT::Logger->debug( "User Check Failed :: (",
                            $service,
                            ")",
                            $username,
                            "More than one user with that username!");
        return 0;
    }
    undef $user_found;

    # If we havent returned now, there must be a valid user.
    return 1;
}

sub UserDisabled {

    my ($username,$service) = @_;

    # FIRST, check that the user exists in the LDAP service
    unless(UserExists($username,$service)) {
        $RT::Logger->debug("User (",$username,") doesn't exist! - Assuming not disabled for the purposes of disable checking");
        return 0;
    }

    my $config          = RT->Config->Get('ExternalSettings')->{$service};
    my $base            = $config->{'base'};
    my $filter          = $config->{'filter'};
    my $d_filter        = $config->{'d_filter'};
    my $search_filter;

    # While LDAP filters must be surrounded by parentheses, an empty set
    # of parentheses is an invalid filter and will cause failure
    # This shouldn't matter since we are now using Net::LDAP::Filter below,
    # but there's no harm in doing this to be sure
    undef $filter   if defined $filter   and $filter eq "()";
    undef $d_filter if defined $d_filter and $d_filter eq "()";

    unless ($d_filter) {
        # If we don't know how to check for disabled users, consider them all enabled.
        $RT::Logger->debug("No d_filter specified for this LDAP service (",
                            $service,
                            "), so considering all users enabled");
        return 0;
    }

    if (defined($config->{'attr_map'}->{'Name'})) {
        # Construct the complex filter
        $search_filter = Net::LDAP::Filter->new(   '(&' .
                                                    $filter .
                                                    $d_filter .
                                                    '(' .
                                                    $config->{'attr_map'}->{'Name'} .
                                                    '=' .
                                                    escape_filter_value($username) .
                                                    '))'
                                                );
    } else {
        $RT::Logger->debug("You haven't specified an LDAP attribute to match the RT \"Name\" attribute for this service (",
                            $service,
                            "), so it's impossible look up the disabled status of this user (",
                            $username,
                            ") so I'm just going to assume the user is not disabled");
        return 0;

    }

    my $ldap = _GetBoundLdapObj($config);
    next unless $ldap;

    # We only need the UID for confirmation now,
    # the other information would waste time and bandwidth
    my @attrs = ('uid');

    $RT::Logger->debug( "LDAP Search === ",
                        "Base:",
                        $base,
                        "== Filter:",
                        ($search_filter ? $search_filter->as_string : ''),
                        "== Attrs:",
                        join(',',@attrs));

    my $disabled_users = $ldap->search(base   => $base,
                                       filter => $search_filter,
                                       attrs  => \@attrs);
    # If ANY results are returned,
    # we are going to assume the user should be disabled
    if ($disabled_users->count) {
        undef $disabled_users;
        return 1;
    } else {
        undef $disabled_users;
        return 0;
    }
}
# {{{ sub _GetBoundLdapObj

sub _GetBoundLdapObj {

    # Config as hashref
    my $config = shift;

    # Figure out what's what
    my $ldap_server     = $config->{'server'};
    my $ldap_user       = $config->{'user'};
    my $ldap_pass       = $config->{'pass'};
    my $ldap_tls        = $config->{'tls'};
    $ldap_tls = $ldap_tls ? {} : undef unless ref $ldap_tls;
    my $ldap_args       = $config->{'net_ldap_args'};

    my $ldap = new Net::LDAP($ldap_server, @$ldap_args);

    unless ($ldap) {
        $RT::Logger->critical(  (caller(0))[3],
                                ": Cannot connect to",
                                $ldap_server);
        return undef;
    }

    if ($ldap_tls) {
        # Thanks to David Narayan for the fault tolerance bits
        eval { $ldap->start_tls( %{$ldap_tls} ); };
        if ($@) {
            $RT::Logger->critical(  (caller(0))[3],
                                    "Can't start TLS: ",
                                    $@);
            return;
        }

    }

    my $msg = undef;

    if (($ldap_user) and ($ldap_pass)) {
        $msg = $ldap->bind($ldap_user, password => $ldap_pass);
    } elsif (($ldap_user) and ( ! $ldap_pass)) {
        $msg = $ldap->bind($ldap_user);
    } else {
        $msg = $ldap->bind;
    }

    unless ($msg->code == LDAP_SUCCESS) {
        $RT::Logger->critical(  (caller(0))[3],
                                "Can't bind:",
                                ldap_error_name($msg->code),
                                $msg->code);
        return undef;
    } else {
        return $ldap;
    }
}

# }}}

RT::Base->_ImportOverlays();

1;
