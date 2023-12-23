# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2023 Best Practical Solutions, LLC
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

package RT::Authen::ExternalAuth;

=head1 NAME

RT::Authen::ExternalAuth - RT Authentication using External Sources

=head1 DESCRIPTION

This module provides the ability to authenticate RT users against one or
more external data sources at once. It will also allow information about
that user to be loaded from the same, or any other available, source as
well as allowing multiple redundant servers for each method.

The functionality currently supports authentication and information from
LDAP via the Net::LDAP module, and from any data source that an
installed DBI driver is available for.

It is also possible to use cookies set by an alternate application for
Single Sign-On (SSO) with that application.  For example, you may
integrate RT with your own website login system so that once users log
in to your website, they will be automagically logged in to RT when they
access it.

=head1 CONFIGURATION

C<RT::Authen::ExternalAuth> provides a lot of flexibility with many
configuration options.  The following describes these configuration options,
and provides a complete example. As with all RT configuration, you set
these values in C<RT_SiteConfig.pm> or for RT 4.4 or later in a custom
configuration file in the directory C<RT_SiteConfig.d>.

=over 4

=item C<$ExternalAuthPriority>

The order in which the services defined in L</$ExternalSettings> should
be used to authenticate users.  Once the user has been authenticated by
one service, the rest are skipped.

You should remove services you don't use. For example, if you're only
using C<My_LDAP>, remove C<My_MySQL> and C<My_SSO_Cookie>.

    Set($ExternalAuthPriority,  [ 'My_LDAP',
                                  'My_MySQL',
                                  'My_SSO_Cookie'
                                ]
    );

=item C<$ExternalInfoPriority>

When multiple auth services are available, this value defines the order
in which the services defined in L</$ExternalSettings> should be used to
get information about users. This includes C<RealName>, telephone
numbers etc, but also whether or not the user should be considered
disabled.

Once a user record is found, no more services are checked.

You CANNOT use a SSO cookie to retrieve information.

You should remove services you don't use, but you must define
at least one service.

    Set($ExternalInfoPriority,  [ 'My_LDAP',
                                  'My_MySQL',
                                ]
    );

=item C<$AutoCreateNonExternalUsers>

If this is set to 1, then users should be autocreated by RT
as internal users if they fail to authenticate from an
external service. This is useful if you have users outside
your organization who might interface with RT, perhaps by sending
email to a support email address.

=item C<$ExternalSettings>

These are the full settings for each external service as a hash of
hashes.  Note that you may have as many external services as you wish.
They will be checked in the order specified in L</$ExternalAuthPriority>
and L</$ExternalInfoPriority> directives above.

The outer structure is a key with the authentication option (name of
external source). The value is a hash reference with configuration keys
and values, for example:

    Set($ExternalSettings, {
        My_LDAP => {
            type => 'ldap',
            ... other options ...
        },
        My_MySQL => {
            type => 'db',
            ... other options ...
        },
        ... other sources ...
    } );

As shown above, each description should have 'type' defined.
The following types are supported:

=over 4

=item ldap

Authenticate against and sync information with LDAP servers.  See
L<RT::Authen::ExternalAuth::LDAP> for details.

=item db

Authenticate against and sync information with external RDBMS, supported
by Perl's L<DBI> interface. See L<RT::Authen::ExternalAuth::DBI> for
details.

=item cookie

Authenticate by cookie. See L<RT::Authen::ExternalAuth::DBI::Cookie> for
details.

=back

See the modules noted above for configuration options specific to each
type.  The following apply to all types.

=over 4

=item attr_match_list

The list of RT attributes that uniquely identify a user. These values
are used, in order, to find users in the selected authentication
source. Each value specified here must have a mapping in the
L</attr_map> section below. You can remove values you don't expect to
match, but we recommend using C<Name> and C<EmailAddress> at a
minimum. For example:

    'attr_match_list' => [
        'Name',
        'EmailAddress',
    ],

You should not use items that can map to multiple users (such as a
C<RealName> or building name).

=item attr_map

Mapping of RT attributes on to attributes in the external source.  For
example, an LDAP mapping might look like:

    'attr_map' => {
        'Name'         => 'sAMAccountName',
        'EmailAddress' => 'mail',
        'Organization' => 'physicalDeliveryOfficeName',
        'RealName'     => 'cn',
        ...
    },

The values in the mapping (i.e. the fields in external source, the right hand
side) can be one of the following:

=over 4

=item an attribute/field

External field to use. Only first value is used if field is multivalue(could
happen in LDAP). For example:

    EmailAddress => 'mail',

=item an array reference

The LDAP attributes can also be an arrayref of external fields,
for example:

    WorkPhone => [qw/CompanyPhone Extension/]

which will be concatenated together with a space. First values
of each field are used in case they have multiple values.

=item a subroutine reference

The external field can also be a subroutine reference that does
mapping. E.g.

    YYY => sub {
        my %args = @_;

        return 'XXX' unless $args{external_entry};

        my @values = grep defined && length, $args{external_entry}->get_value('XXX');
        return @values;
    },

The following arguments are passed into the function in a hash:

=over 4

=item external_entry

For type "ldap", it's an instance of L<Net::LDAP::Entry>.  For type "db", it's
a hashref of the result row.

=item mapping

Hash reference of the attr_map value.

=item rt_field and external_field

The currently processed key and value from the mapping.

=back

The subroutine is called in 2 modes: when called with external_entry
specified, it should return value or list of values, otherwise, it should
return the external field list it depends on, so RT could retrieve them at the
beginning.

=back

The keys in the mapping (i.e. the RT fields, the left hand side) may be a user
custom field name prefixed with C<UserCF.>, for example C<< 'UserCF.Employee
Number' => 'employeeId' >>.  Note that this only B<adds> values at the moment,
which on single value CFs will remove any old value first.  Multiple value CFs
may behave not quite how you expect.  If the attribute no longer exists on a
user in external source, it will be cleared on the RT side as well.

You may also prefix any RT custom field name with C<CF.> inside your mapping
to add available values to a Select custom field.  This effectively takes user
attributes in external source and adds the values as selectable options in a
CF.  It does B<not> set a CF value on any RT object (User, Ticket, Queue,
etc).  You might use this to populate a ticket Location CF with all the
locations of your users so that tickets can be associated with the locations
in use.

=back

=back

=head2 Example

    # Use the below LDAP source for both authentication, as well as user
    # information
    Set( $ExternalAuthPriority, ["My_LDAP"] );
    Set( $ExternalInfoPriority, ["My_LDAP"] );

    # Make users created from LDAP Privileged
    Set( $UserAutocreateDefaultsOnLogin, { Privileged => 1 } );

    # Users should still be autocreated by RT as internal users if they
    # fail to exist in an external service; this is so requestors (who
    # are not in LDAP) can still be created when they email in.
    Set($AutoCreateNonExternalUsers, 1);

    # Minimal LDAP configuration; see RT::Authen::ExternalAuth::LDAP for
    # further details and examples
    Set($ExternalSettings, {
        'My_LDAP'       =>  {
            'type'             =>  'ldap',
            'server'           =>  'ldap.example.com',
            # By not passing 'user' and 'pass' we are using an anonymous
            # bind, which some servers to not allow
            'base'             =>  'ou=Staff,dc=example,dc=com',
            'filter'           =>  '(objectClass=inetOrgPerson)',
            # Users are allowed to log in via email address or account
            # name
            'attr_match_list'  => [
                'Name',
                'EmailAddress',
            ],
            # Import the following properties of the user from LDAP upon
            # login
            'attr_map' => {
                'Name'         => 'sAMAccountName',
                'EmailAddress' => 'mail',
                'RealName'     => 'cn',
                'WorkPhone'    => 'telephoneNumber',
                'Address1'     => 'streetAddress',
                'City'         => 'l',
                'State'        => 'st',
                'Zip'          => 'postalCode',
                'Country'      => 'co',
            },
        },
    } );

=cut

use RT::Authen::ExternalAuth::LDAP;
use RT::Authen::ExternalAuth::DBI;

use warnings;
use strict;

sub DoAuth {
    my ($session,$given_user,$given_pass) = @_;

    # Get the prioritised list of external authentication services
    my @auth_services = @{ RT->Config->Get('ExternalAuthPriority') };
    my $settings = RT->Config->Get('ExternalSettings');

    return (0, "ExternalAuthPriority not defined, please check your configuration file.")
        unless @auth_services;

    # This may be used by single sign-on (SSO) authentication mechanisms for bypassing a password check.
    my $success = 0;

    # Should have checked if user is already logged in before calling this function,
    # but just in case, we'll check too.
    return (0, "User already logged in!") if ($session->{'CurrentUser'} && $session->{'CurrentUser'}->Id);

    # For each of those services..
    my ( $matched_field, $matched_username );
    foreach my $service (@auth_services) {

        # Get the full configuration for that service as a hashref
        my $config = $settings->{$service};
        $RT::Logger->debug( "Attempting to use external auth service:",
                            $service);

        # $username will be the final username we decide to check
        # This will not necessarily be $given_user
        my $username = undef;

        #############################################################
        ####################### SSO Check ###########################
        #############################################################
        if ($config->{'type'} eq 'cookie') {
            # Currently, Cookie authentication is our only SSO method
            $username = RT::Authen::ExternalAuth::DBI::GetCookieAuth($config);
        }
        #############################################################

        # If $username is defined, we have a good SSO $username and can
        # safely bypass the password checking later on; primarily because
        # it's VERY unlikely we even have a password to check if an SSO succeeded.
        my $pass_bypass = 0;
        my $field;
        if(defined($username)) {
            $RT::Logger->debug("Pass not going to be checked, attempting SSO");
            $pass_bypass = 1;
        } else {

            # SSO failed and no $user was passed for a login attempt
            # We only don't return here because the next iteration could be an SSO attempt
            unless(defined($given_user)) {
                $RT::Logger->debug("SSO Failed and no user to test with. Nexting");
                next;
            }

            # We don't have an SSO login, so we will be using the credentials given
            # on RT's login page to do our authentication.
            $username = $given_user;

            # Don't continue unless the service works.
            # next unless RT::Authen::ExternalAuth::TestConnection($config);

            # Don't continue unless the $username exists in the external service

            $RT::Logger->debug("Calling UserExists with \$username ($username) and \$service ($service)");
            $field = RT::Authen::ExternalAuth::UserExists( $username, $service ) or next;
            # 1 means no field info, which will fall back to Name
            undef $field if $field && $field eq '1';
        }

        ####################################################################
        ########## Load / Auto-Create ######################################
        ####################################################################
        # We are now sure that we're talking about a valid RT user.
        # If the user already exists, load up their info. If they don't
        # then we need to create the user in RT.

        # Does user already exist internally to RT?
        $session->{'CurrentUser'} = RT::CurrentUser->new();
        my $user = LoadUserObject( Field => $field || 'Name', Value => $username );
        $session->{'CurrentUser'}->Load( $user->Id ) if $user->Id;

        # Unless we have loaded a valid user with a UserID create one.
        unless ($session->{'CurrentUser'}->Id) {
            my $UserObj = RT::User->new($RT::SystemUser);
            my $create = RT->Config->Get('UserAutocreateDefaultsOnLogin')
                || RT->Config->Get('AutoCreate');

            my ( $val, $msg ) = $UserObj->Create( %{ ref($create) ? $create : {} },
                $field ? ( $field => $username ) : ( 'Name' => $username, Gecos => $username, ) );
            unless ($val) {
                $RT::Logger->error( "Couldn't create user $username: $msg" );
                next;
            }
            $RT::Logger->info(  "Autocreated external user",
                                $UserObj->Name,
                                "(",
                                $UserObj->Id,
                                ")");

            $RT::Logger->debug("Loading new user (",
                                                $username,
                                                ") into current session");
            $session->{'CurrentUser'}->Load($UserObj->Id);
        }

        ####################################################################
        ########## Authentication ##########################################
        ####################################################################
        # If we successfully used an SSO service, then authentication
        # succeeded. If we didn't then, success is determined by a password
        # test.
        $success = 0;
        if($pass_bypass) {
            $RT::Logger->debug("Password check bypassed due to SSO method being in use");
            $success = 1;
        } else {
            $RT::Logger->debug("Password validation required for service - Executing...");
            $success = RT::Authen::ExternalAuth::GetAuth($service,$username,$given_pass);
        }

        $RT::Logger->debug("Password Validation Check Result: ",$success);

        # If the password check succeeded then this is our authoritative service
        # and we proceed to user information update and login.
        if ( $success ) {
            $matched_field = $field if $field;
            $matched_username = $username;
            last;
        }
    }

    # If we got here and don't have a user loaded we must have failed to
    # get a full, valid user from an authoritative external source.
    unless ($session->{'CurrentUser'} && $session->{'CurrentUser'}->Id) {
        $session->{'CurrentUser'} = RT::CurrentUser->new;
        return (0, "No User");
    }

    unless($success) {
        $session->{'CurrentUser'} = RT::CurrentUser->new;
        return (0, "Password Invalid");
    }

    # Otherwise we succeeded.
    $RT::Logger->debug("Authentication successful. Now updating user information and attempting login.");

    ####################################################################################################
    ############################### The following is auth-method agnostic ##############################
    ####################################################################################################

    # If we STILL have a completely valid RT user to play with...
    # and therefore password has been validated...
    if ($session->{'CurrentUser'} && $session->{'CurrentUser'}->Id) {

        # Even if we have JUST created the user in RT, we are going to
        # reload their information from an external source. This allows us
        # to be sure that the user the cookie gave us really does exist in
        # the database, but more importantly, UpdateFromExternal will check
        # whether the user is disabled or not which we have not been able to
        # do during auto-create

        # These are not currently used, but may be used in the future.
        my $info_updated = 0;
        my $info_updated_msg = "User info not updated";

        if ( @{ RT->Config->Get('ExternalInfoPriority') } ) {
            # Note that UpdateUserInfo does not care how we authenticated the user
            # It will look up user info from whatever is specified in $RT::ExternalInfoPriority
            ($info_updated,$info_updated_msg) = RT::Authen::ExternalAuth::UpdateUserInfo($matched_username, $matched_field || 'Name');
        }

        # Now that we definitely have up-to-date user information,
        # if the user is disabled, kick them out. Now!
        if ($session->{'CurrentUser'}->UserObj->Disabled) {
            $session->{'CurrentUser'} = RT::CurrentUser->new;
            return (0, "User account disabled, login denied");
        }
    }

    # If we **STILL** have a full user and the session hasn't already been deleted
    # This If/Else is logically unnecessary, but it doesn't hurt to leave it here
    # just in case. Especially to be a double-check to future modifications.
    if ($session->{'CurrentUser'} && $session->{'CurrentUser'}->Id) {

            $RT::Logger->info(  "Successful login for",
                                $session->{'CurrentUser'}->Name,
                                "from",
                                ( RT::Interface::Web::RequestENV('REMOTE_ADDR') || 'UNKNOWN') );
            # Do not delete the session. User stays logged in and
            # autohandler will not check the password again

            my $cu = $session->{CurrentUser};
            RT::Interface::Web::InstantiateNewSession();
            $session->{CurrentUser} = $cu;
    } else {
            # Make SURE the session is purged to an empty user.
            $session->{'CurrentUser'} = RT::CurrentUser->new;
            return (0, "Failed to authenticate externally");
            # This will cause autohandler to request IsPassword
            # which will in turn call IsExternalPassword
    }

    return (1, "Successful login");
}

sub UpdateUserInfo {
    my $username = shift;
    my $field    = shift || 'Name';

    # Prepare for the worst...
    my $found           = 0;
    my $updated         = 0;
    my $msg             = "User NOT updated";

    my $user_disabled   = RT::Authen::ExternalAuth::UserDisabled($username);

    my $UserObj = LoadUserObject( Field => $field, Value => $username, );

    # If user is disabled, set the RT::Principal to disabled and return out of the function.
    # I think it's a waste of time and energy to update a user's information if they are disabled
    # and it could be a security risk if they've updated their external information with some
    # carefully concocted code to try to break RT - worst case scenario, but they have been
    # denied access after all, don't take any chances.

    # If someone gives me a good enough reason to do it,
    # then I'll update all the info for disabled users

    if ($user_disabled) {
        unless ( $UserObj->Disabled ) {
            # Make sure principal is disabled in RT
            my ($val, $message) = $UserObj->SetDisabled(1);
            # Log what has happened
            $RT::Logger->info("User marked as DISABLED (",
                                $username,
                                ") per External Service",
                                "($val, $message)\n");
            $msg = "User Disabled";
        }

        return ($updated, $msg);
    }

    # Make sure principal is not disabled in RT
    if ( $UserObj->Disabled ) {
        my ($val, $message) = $UserObj->SetDisabled(0);
        unless ( $val ) {
            $RT::Logger->error("Failed to enable user ($username) per External Service: ".($message||''));
            return ($updated, "Failed to enable");
        }

        $RT::Logger->info("User ($username) was disabled, marked as ENABLED ",
                        "per External Service",
                        "($val, $message)\n");
    }

    # Update their info from external service using the username as the lookup key
    # CanonicalizeUserInfo will work out for itself which service to use
    # Passing it a service instead could break other RT code
    my %args = ($field => $username);
    $UserObj->CanonicalizeUserInfo(\%args);

    # For each piece of information returned by CanonicalizeUserInfo,
    # run the Set method for that piece of info to change it for the user
    my @results = $UserObj->Update(
        ARGSRef         => \%args,
        AttributesRef   => [ grep { !/^(?:User)?CF\./ } keys %args ],
    );
    $RT::Logger->debug("UPDATED user $username: $_")
        for @results;

    AddCustomFieldValue( %args );
    $UserObj->UpdateObjectCustomFieldValues( %args );

    # Confirm update success
    $updated = 1;
    $RT::Logger->debug( "UPDATED user (",
                        $username,
                        ") from External Service\n");
    $msg = 'User updated';

    return ($updated, $msg);
}

sub GetAuth {

    # Request a username/password check from the specified service
    # This is only valid for non-SSO services.

    my ($service,$username,$password) = @_;

    my $success = 0;

    # Get the full configuration for that service as a hashref
    my $config = RT->Config->Get('ExternalSettings')->{$service};

    # And then act accordingly depending on what type of service it is.
    # Right now, there is only code for DBI and LDAP non-SSO services
    if ($config->{'type'} eq 'db') {
        $success = RT::Authen::ExternalAuth::DBI::GetAuth($service,$username,$password);
        $RT::Logger->debug("DBI password validation result:",$success);
    } elsif ($config->{'type'} eq 'ldap') {
        $success = RT::Authen::ExternalAuth::LDAP::GetAuth($service,$username,$password);
        $RT::Logger->debug("LDAP password validation result:",$success);
    }

    return $success;
}

sub UserExists {

    # Request a username/password check from the specified service
    # This is only valid for non-SSO services.

    my ($username,$service) = @_;

    my $success = 0;

    # Get the full configuration for that service as a hashref
    my $config = RT->Config->Get('ExternalSettings')->{$service};

    # And then act accordingly depending on what type of service it is.
    # Right now, there is only code for DBI and LDAP non-SSO services
    if ($config->{'type'} eq 'db') {
        $success = RT::Authen::ExternalAuth::DBI::UserExists($username,$service);
    } elsif ($config->{'type'} eq 'ldap') {
        $success = RT::Authen::ExternalAuth::LDAP::UserExists($username,$service);
    }

    return $success;
}

sub UserDisabled {

    my $username = shift;
    my $user_disabled = 0;

    my @info_services = @{ RT->Config->Get('ExternalInfoPriority') };

    # For each named service in the list
    # Check to see if the user is found in the external service
    # If not found, jump to next service
    # If found, check to see if user is considered disabled by the service
    # Then update the user's info in RT and return
    foreach my $service (@info_services) {

        # Get the external config for this service as a hashref
        my $config = RT->Config->Get('ExternalSettings')->{$service};

        # If it's a DBI config:
        if ($config->{'type'} eq 'db') {

            unless(RT::Authen::ExternalAuth::DBI::UserExists($username,$service)) {
                $RT::Logger->debug("User (",
                                    $username,
                                    ") doesn't exist in service (",
                                    $service,
                                    ") - Cannot update information - Skipping...");
                next;
            }
            $user_disabled = RT::Authen::ExternalAuth::DBI::UserDisabled($username,$service);

        } elsif ($config->{'type'} eq 'ldap') {

            unless(RT::Authen::ExternalAuth::LDAP::UserExists($username,$service)) {
                $RT::Logger->debug("User (",
                                    $username,
                                    ") doesn't exist in service (",
                                    $service,
                                    ") - Cannot update information - Skipping...");
                next;
            }
            $user_disabled = RT::Authen::ExternalAuth::LDAP::UserDisabled($username,$service);

        }

    }
    return $user_disabled;
}

sub AddCustomFieldValue {
    my %args = @_;

    foreach my $rtfield ( keys %args ) {
        next unless $rtfield =~ /^CF\.(.+)$/i;
        my $cf_name = $1;

        my $cfv_name = $args{$rtfield} or next;

        my $cf = RT::CustomField->new($RT::SystemUser);
        my ( $status, $msg ) = $cf->Load($cf_name);
        unless ($status) {
            $RT::Logger->error("Couldn't load CF [$cf_name]: $msg");
            next;
        }

        my $cfv = RT::CustomFieldValue->new($RT::SystemUser);
        $cfv->LoadByCols(
            CustomField => $cf->id,
            Name        => $cfv_name
        );
        if ( $cfv->id ) {
            $RT::Logger->debug("Custom Field '$cf_name' already has '$cfv_name' for a value");
            next;
        }

        ( $status, $msg ) = $cf->AddValue( Name => $cfv_name );
        if ($status) {
            $RT::Logger->debug("Added '$cfv_name' to Custom Field '$cf_name' [$msg]");
        }
        else {
            $RT::Logger->error("Couldn't add '$cfv_name' to '$cf_name' [$msg]");
        }
    }

    return;
}

sub LoadUserObject {
    my %args = (
        Field => 'Name',
        Value => undef,
        @_
    );
    my ( $ret, $msg );

    my $user = RT::User->new( RT->SystemUser );
    if ( my ($cf_name) = $args{'Field'} =~ /^UserCF\.(.+)$/i ) {
        ( $ret, $msg ) = $user->LoadByCustomFieldValue(
            CustomField => $cf_name,
            Value       => $args{'Value'},
        );
    }
    else {
        # No user CF, normal load
        ( $ret, $msg ) = $user->LoadByCols( $args{'Field'}, $args{'Value'} );
    }

    RT->Logger->debug( "Unable to load user " . $args{'Value'} . " from field " . $args{'Field'} ) unless $ret;
    return $user;
}

RT::Base->_ImportOverlays();

1;
