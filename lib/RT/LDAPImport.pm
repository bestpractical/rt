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

package RT::LDAPImport;

use warnings;
use strict;
use base qw(Class::Accessor);
__PACKAGE__->mk_accessors(qw(_ldap _group _users));
use Carp;
use Net::LDAP;
use Net::LDAP::Util qw(escape_filter_value);
use Net::LDAP::Control::Paged;
use Net::LDAP::Constant qw(LDAP_CONTROL_PAGED);
use Data::Dumper;

=head1 NAME

RT::LDAPImport - Import Users from an LDAP store

=head1 SYNOPSIS

In C<RT_SiteConfig.pm>:

    Set($LDAPHost,'my.ldap.host');
    Set($LDAPOptions, [ port    => 636,
                        scheme  => 'ldaps',
                        raw     => qr/(\;binary)/,
                        version => 3,
                        verify  => 'required',
                        cafile  => '/certificate-file/path' ]);
    Set($LDAPUser,'me');
    Set($LDAPPassword,'mypass');
    Set($LDAPBase, 'ou=People,o=Our Place');
    Set($LDAPFilter, '(&(cn = users))');
    Set($LDAPMapping, {Name         => 'uid', # required
                       EmailAddress => 'mail',
                       RealName     => 'cn',
                       WorkPhone    => 'telephoneNumber',
                       Organization => 'departmentName'});
    
    # If you want to sync Groups from LDAP into RT
    
    Set($LDAPGroupBase, 'ou=Groups,o=Our Place');
    Set($LDAPGroupFilter, '(&(cn = Groups))');
    Set($LDAPGroupMapping, {Name               => 'cn',
                            Member_Attr        => 'member',
                            Member_Attr_Value  => 'dn' });

Running the import:

    # Run a test import
    /opt/rt4/sbin/rt-ldapimport --verbose > ldapimport.debug 2>&1
    
    # Run for real, possibly put in cron
    /opt/rt4/sbin/rt-ldapimport --import

=head1 CONFIGURATION

All of the configuration for the importer goes in
your F<RT_SiteConfig.pm> file. Some of these values pass through
to L<Net::LDAP> so you can check there for valid values and more
advanced options.

=over

=item C<< Set($LDAPHost,'our.ldap.host'); >>

Hostname or ldap(s):// uri:

=item C<< Set($LDAPOptions, [ port => 636 ]); >>

This allows you to pass any options supported by the L<Net::LDAP>
new method.

=item C<< Set($LDAPUser, 'uid=foo,ou=users,dc=example,dc=com'); >>

Your LDAP username or DN. If unset, we'll attempt an anonymous bind.

=item C<< Set($LDAPPassword, 'ldap pass'); >>

Your LDAP password.

=item C<< Set($LDAPBase, 'ou=People,o=Our Place'); >>

Base object to search from.

=item C<< Set($LDAPFilter, '(&(cn = users))'); >>

The LDAP search filter to apply (in this case, find all the users).

=item C<< Set($LDAPMapping... >>

    Set($LDAPMapping, {Name         => 'uid',
                       EmailAddress => 'mail',
                       RealName     => 'cn',
                       WorkPhone    => 'telephoneNumber',
                       Organization => 'departmentName'});

This provides the mapping of attributes in RT to attribute(s) in LDAP.
Only Name is required for RT.

The values in the mapping (i.e. the LDAP fields, the right hand side)
can be one of the following:

=over 4

=item an attribute

LDAP attribute to use. Only first value is used if attribute is
multivalue. For example:

    EmailAddress => 'mail',

=item an array reference

The LDAP attributes can also be an arrayref of LDAP fields,
for example:

    WorkPhone => [qw/CompanyPhone Extension/]

which will be concatenated together with a space. First values
of each attribute are used in case they have multiple values.

=item a subroutine reference

The LDAP attribute can also be a subroutine reference that does
mapping, for example:

    YYY => sub {
        my %args = @_;
        my @values = grep defined && length, $args{ldap_entry}->get_value('XXX');
        return @values;
    },

The subroutine should return value or list of values. The following
arguments are passed into the function in a hash:

=over 4

=item self

Instance of this class.

=item ldap_entry

L<Net::LDAP::Entry> instance that is currently mapped.

=item import

Boolean value indicating whether it's import or a dry run. If it's
dry run (import is false) then function shouldn't change anything.

=item mapping

Hash reference with the currently processed mapping, eg. C<$LDAPMapping>.

=item rt_field and ldap_field

The currently processed key and value from the mapping.

=item result

Hash reference with results of completed mappings for this ldap entry.
This should be used to inject that are not in the mapping, not to inspect.
Mapping is processed in literal order of the keys.

=back

=back

The keys in the mapping (i.e. the RT fields, the left hand side) may be a user
custom field name prefixed with C<UserCF.>, for example C<< 'UserCF.Employee
Number' => 'employeeId' >>.  Note that this only B<adds> values at the moment,
which on single value CFs will remove any old value first.  Multiple value CFs
may behave not quite how you expect.  If the attribute no longer exists on a
user in LDAP, it will be cleared on the RT side as well.

You may also prefix any RT custom field name with C<CF.> inside your mapping to
add available values to a Select custom field.  This effectively takes user
attributes in LDAP and adds the values as selectable options in a CF.  It does
B<not> set a CF value on any RT object (User, Ticket, Queue, etc).  You might
use this to populate a ticket Location CF with all the locations of your users
so that tickets can be associated with the locations in use.

=item C<< Set($LDAPCreatePrivileged, 1); >>

By default users are created as Unprivileged, but you can change this by
setting C<$LDAPCreatePrivileged> to 1.

=item C<< Set($LDAPGroupName,'My Imported Users'); >>

The RT Group new and updated users belong to. By default, all users
added or updated by the importer will belong to the 'Imported from LDAP'
group.

=item C<< Set($LDAPSkipAutogeneratedGroup, 1); >>

Set this to true to prevent users from being automatically
added to the group configured by C<$LDAPGroupName>.

=item C<< Set($LDAPUpdateUsers, 1); >>

By default, existing users are skipped.  If you
turn on LDAPUpdateUsers, we will clobber existing
data with data from LDAP.

=item C<< Set($LDAPUpdateOnly, 1); >>

By default, we create users who don't exist in RT but do
match your LDAP filter and obey C<$LDAPUpdateUsers> for existing
users.  This setting updates existing users, overriding
C<$LDAPUpdateUsers>, but won't create new
users who are found in LDAP but not in RT.

=item C<< Set($LDAPGroupBase, 'ou=Groups,o=Our Place'); >>

Where to search for groups to import.

=item C<< Set($LDAPGroupFilter, '(&(cn = Groups))'); >>

The search filter to apply.

=item C<< Set($LDAPGroupMapping... >>

    Set($LDAPGroupMapping, {Name               => 'cn',
                            Member_Attr        => 'member',
                            Member_Attr_Value  => 'dn' });

A mapping of RT attributes to LDAP attributes to identify group members.
Name will become the name of the group in RT, in this case pulling
from the cn attribute on the LDAP group record returned. Everything
besides C<Member_Attr_Value> is processed according to rules described
in documentation for C<$LDAPMapping> option, so value can be array
or code reference besides scalar.

C<Member_Attr> is the field in the LDAP group record the importer should
look at for group members. These values (there may be multiple members)
will then be compared to the RT user name, which came from the LDAP
user record. See F<t/ldapimport/group-callbacks.t> for a complex example of
using a code reference as value of this option.

C<Member_Attr_Value>, which defaults to 'dn', specifies where on the LDAP
user record the importer should look to compare the member value.
A match between the member field on the group record and this
identifier (dn or other LDAP field) on a user record means the
user will be added to that group in RT.

C<id> is the field in LDAP group record that uniquely identifies
the group. This is optional and shouldn't be equal to mapping for
Name field. Group names in RT must be distinct and you don't need
another unique identifier in common situation. However, when you
rename a group in LDAP, without this option set properly you end
up with two groups in RT.

You can provide a C<Description> key which will be added as the group
description in RT. The default description is 'Imported from LDAP'.

=item C<< Set($LDAPImportGroupMembers, 1); >>

When disabled, the default, LDAP group import expects that all LDAP members
already exist as RT users.  Often the user import stage, which happens before
groups, is used to create and/or update group members by using an
C<$LDAPFilter> which includes a C<memberOf> attribute.

When enabled, by setting to C<1>, LDAP group members are explicitly imported
before membership is synced with RT.  This enables groups-only configurations
to also import group members without specifying a potentially long and complex
C<$LDAPFilter> using C<memberOf>.  It's particularly handy when C<memberOf>
isn't available on user entries.

Note that C<$LDAPFilter> still applies when this option is enabled, so some
group members may be filtered out from the import.

=item C<< Set($LDAPSizeLimit, 1000); >>

You can set this value if your LDAP server has result size limits.

=back

=head1 Mapping Groups Between RT and LDAP

If you are using the importer, you likely want to manage access via
LDAP by putting people in groups like 'DBAs' and 'IT Support', but
also have groups for other non-RT related things. In this case, you
won't want to create all of your LDAP groups in RT. To limit the groups
that get mirrored, construct your C<$LDAPGroupFilter> as an OR (|) with
all of the RT groups you want to mirror from LDAP. For example:

    Set($LDAPGroupBase, 'OU=Groups,OU=Company,DC=COM');
    Set($LDAPGroupFilter, '(|(CN=DBAs)(CN=IT Support))');

The importer will then import only the groups that match. In this case,
import means:

=over

=item * Verifying the group is in AD;

=item * Creating the group in RT if it doesn't exist;

=item * Populating the group with the members identified in AD;

=back

The import script will also issue a warning if a user isn't found in RT,
but this should only happen when testing. When running with --import on,
users are created before groups are processed, so all users (group
members) should exist unless there are inconsistencies in your LDAP configuration.

=head1 Running the Import

Executing C<rt-ldapimport> will run a test that connects to your LDAP server
and prints out a list of the users found. To see more about these users,
and to see more general debug information, include the C<--verbose> flag.

That debug information is also sent to the RT log with the debug level.
Errors are logged to the screen and to the RT log.

Executing C<rt-ldapimport> with the C<--import> flag will cause it to import
users into your RT database. It is recommended that you make a database
backup before doing this. If your filters aren't set properly this could
create a lot of users or groups in your RT instance.

=head1 LDAP Filters

The L<ldapsearch|http://www.openldap.org/software/man.cgi?query=ldapsearch&manpath=OpenLDAP+2.0-Release>
utility in openldap can be very helpful while refining your filters.

=head1 METHODS

=head2 connect_ldap

Relies on the config variables C<$LDAPHost>, C<$LDAPOptions>, C<$LDAPUser>,
and C<$LDAPPassword> being set in your RT Config files.

 Set($LDAPHost,'my.ldap.host');
 Set($LDAPOptions, [ port => 636 ]);
 Set($LDAPUSER,'me');
 Set($LDAPPassword,'mypass');

LDAPUser and LDAPPassword can be blank,
which will cause an anonymous bind.

LDAPHost can be a hostname or an ldap:// ldaps:// uri.

=cut

sub connect_ldap {
    my $self = shift;

    $RT::LDAPOptions = [] unless $RT::LDAPOptions;
    my $ldap = Net::LDAP->new($RT::LDAPHost, @$RT::LDAPOptions);

    $RT::Logger->debug("connecting to $RT::LDAPHost");
    unless ($ldap) {
        $RT::Logger->error("Can't connect to $RT::LDAPHost $@");
        return;
    }

    my $msg;
    if ($RT::LDAPUser) {
        $RT::Logger->debug("binding as $RT::LDAPUser");
        $msg = $ldap->bind($RT::LDAPUser, password => $RT::LDAPPassword);
    } else {
        $RT::Logger->debug("binding anonymously");
        $msg = $ldap->bind;
    }

    if ($msg->code) {
        $RT::Logger->error("LDAP bind failed " . $msg->error);
        return;
    }

    $self->_ldap($ldap);
    return $ldap;

}

=head2 run_user_search

Set up the appropriate arguments for a listing of users.

=cut

sub run_user_search {
    my $self = shift;
    $self->_run_search(
        base   => $RT::LDAPBase,
        filter => $RT::LDAPFilter
    );

}

=head2 _run_search

Executes a search using the provided base and filter.

Will connect to LDAP server using C<connect_ldap>.

Returns an array of L<Net::LDAP::Entry> objects, possibly consolidated from
multiple LDAP pages.

=cut

sub _run_search {
    my $self = shift;
    my $ldap = $self->_ldap||$self->connect_ldap;
    my %args = @_;

    unless ($ldap) {
        $RT::Logger->error("fetching an LDAP connection failed");
        return;
    }

    my %search = (
        base    => $args{base},
        filter  => $args{filter},
        scope   => ($args{scope} || 'sub'),
    );
    my (@results, $page, $cookie);

    if ($RT::LDAPSizeLimit) {
        $page = Net::LDAP::Control::Paged->new( size => $RT::LDAPSizeLimit, critical => 1 );
        $search{control} = $page;
    }

    LOOP: {
        # Start where we left off
        $page->cookie($cookie) if $page and $cookie;

        $RT::Logger->debug("searching with: " . join(' ', map { "$_ => '$search{$_}'" } sort keys %search));

        my $result = $ldap->search( %search );

        if ($result->code) {
            $RT::Logger->error("LDAP search failed " . $result->error);
            last;
        }

        push @results, $result->entries;

        # Short circuit early if we're done
        last if not $result->count
             or $result->count < ($RT::LDAPSizeLimit || 0);

        if ($page) {
            if (my $control = $result->control( LDAP_CONTROL_PAGED )) {
                $cookie = $control->cookie;
            } else {
                $RT::Logger->error("LDAP search didn't return a paging control");
                last;
            }
        }
        redo if $cookie;
    }

    # Let the server know we're abandoning the search if we errored out
    if ($cookie) {
        $RT::Logger->debug("Informing the LDAP server we're done with the result set");
        $page->cookie($cookie);
        $page->size(0);
        $ldap->search( %search );
    }

    $RT::Logger->debug("search found ".scalar @results." objects");
    return @results;
}

=head2 import_users import => 1|0

Takes the results of the search from run_search
and maps attributes from LDAP into C<RT::User> attributes
using C<$LDAPMapping>.
Creates RT users if they don't already exist.

With no arguments, only prints debugging information.
Pass C<--import> to actually change data.

C<$LDAPMapping>> should be set in your C<RT_SiteConfig.pm>
file and look like this.

 Set($LDAPMapping, { RTUserField => LDAPField, RTUserField => LDAPField });

RTUserField is the name of a field on an C<RT::User> object
LDAPField can be a simple scalar and that attribute
will be looked up in LDAP.

It can also be an arrayref, in which case each of the
elements will be evaluated in turn.  Scalars will be
looked up in LDAP and concatenated together with a single
space.

If the value is a sub reference, it will be executed.
The sub should return a scalar, which will be examined.
If it is a scalar, the value will be looked up in LDAP.
If it is an arrayref, the values will be concatenated 
together with a single space.

By default users are created as Unprivileged, but you can change this by
setting C<$LDAPCreatePrivileged> to 1.

=cut

sub import_users {
    my $self = shift;
    my %args = @_;

    $self->_users({});

    my @results = $self->run_user_search;
    return $self->_import_users( %args, users => \@results );
}

sub _import_users {
    my $self = shift;
    my %args = @_;
    my $users = $args{users};

    unless ( @$users ) {
        $RT::Logger->debug("No users found, no import");
        $self->disconnect_ldap;
        return;
    }

    my $mapping = $RT::LDAPMapping;
    return unless $self->_check_ldap_mapping( mapping => $mapping );

    my $done = 0; my $count = scalar @$users;
    while (my $entry = shift @$users) {
        my $user = $self->_build_user_object( ldap_entry => $entry );
        $self->_import_user( user => $user, ldap_entry => $entry, import => $args{import} );
        $done++;
        $RT::Logger->debug("Imported $done/$count users");
    }
    return 1;
}

=head2 _import_user

We have found a user to attempt to import; returns the L<RT::User>
object if it was found (or created), C<undef> if not.

=cut

sub _import_user {
    my $self = shift;
    my %args = @_;

    unless ( $args{user}{Name} ) {
        $RT::Logger->warn("No Name or Emailaddress for user, skipping ".Dumper($args{user}));
        return;
    }
    if ( $args{user}{Name} =~ /^[0-9]+$/) {
        $RT::Logger->debug("Skipping user '$args{user}{Name}', as it is numeric");
        return;
    }

    $RT::Logger->debug("Processing user $args{user}{Name}");
    $self->_cache_user( %args );

    $args{user} = $self->create_rt_user( %args );
    return unless $args{user};

    $self->add_user_to_group( %args );
    $self->add_custom_field_value( %args );
    $self->update_object_custom_field_values( %args, object => $args{user} );

    return $args{user};
}

=head2 _cache_user ldap_entry => Net::LDAP::Entry, [user => { ... }]

Adds the user to a global cache which is used when importing groups later.

Optionally takes a second argument which is a user data object returned by
_build_user_object.  If not given, _cache_user will call _build_user_object
itself.

Returns the user Name.

=cut

sub _cache_user {
    my $self = shift;
    my %args = (@_);
    my $user = $args{user} || $self->_build_user_object( ldap_entry => $args{ldap_entry} );

    $self->_users({}) if not defined $self->_users;

    my $group_map       = $RT::LDAPGroupMapping           || {};
    my $member_attr_val = $group_map->{Member_Attr_Value} || 'dn';
    my $membership_key  = lc $member_attr_val eq 'dn'
                            ? $args{ldap_entry}->dn
                            : $args{ldap_entry}->get_value($member_attr_val);

    # Fallback to the DN if the user record doesn't have a value
    unless (defined $membership_key) {
        $membership_key = $args{ldap_entry}->dn;
        $RT::Logger->warn("User attribute '$member_attr_val' has no value for '$membership_key'; falling back to DN");
    }

    return $self->_users->{lc $membership_key} = $user->{Name};
}

sub _show_user_info {
    my $self = shift;
    my %args = @_;
    my $user = $args{user};
    my $rt_user = $args{rt_user};

    $RT::Logger->debug( "\tRT Field\tRT Value -> LDAP Value" );
    foreach my $key (sort keys %$user) {
        my $old_value;
        if ($rt_user) {
            eval { $old_value = $rt_user->$key() };
            if ($user->{$key} && defined $old_value && $old_value eq $user->{$key}) {
                $old_value = 'unchanged';
            }
        }
        $old_value ||= 'unset';
        $RT::Logger->debug( "\t$key\t$old_value => $user->{$key}" );
    }
    #$RT::Logger->debug(Dumper($user));
}

=head2 _check_ldap_mapping

Returns true is there is an C<LDAPMapping> configured,
returns false, logs an error and disconnects from
ldap if there is no mapping.

=cut

sub _check_ldap_mapping {
    my $self = shift;
    my %args = @_;
    my $mapping = $args{mapping};

    my @rtfields = keys %{$mapping};
    unless ( @rtfields ) {
        $RT::Logger->error("No mapping found, can't import");
        $self->disconnect_ldap;
        return;
    }

    return 1;
}

=head2 _build_user_object

Utility method which wraps C<_build_object> to provide sane
defaults for building users.  It also tries to ensure a Name
exists in the returned object.

=cut

sub _build_user_object {
    my $self = shift;
    my $user = $self->_build_object(
        skip    => qr/(?i)^(?:User)?CF\./,
        mapping => $RT::LDAPMapping,
        @_
    );
    $user->{Name} ||= $user->{EmailAddress};
    return $user;
}

=head2 _build_object

Internal method - a wrapper around L</_parse_ldap_mapping>
that flattens results turning every value into a scalar.

The following:

    [
        [$first_value1, ... ],
        [$first_value2],
        $scalar_value,
    ]

Turns into:

    "$first_value1 $first_value2 $scalar_value"

Arguments are just passed into L</_parse_ldap_mapping>.

=cut

sub _build_object {
    my $self = shift;
    my %args = @_;

    my $res = $self->_parse_ldap_mapping( %args );
    foreach my $value ( values %$res ) {
        @$value = map { ref $_ eq 'ARRAY'? $_->[0] : $_ } @$value;
        $value = join ' ', grep defined && length, @$value;
    }
    return $res;
}

=head3 _parse_ldap_mapping

Internal helper method that maps an LDAP entry to a hash
according to passed arguments. Takes named arguments:

=over 4

=item ldap_entry

L<Net::LDAP::Entry> instance that should be mapped.

=item only

Optional regular expression. If passed then only matching
entries in the mapping will be processed.

=item skip

Optional regular expression. If passed then matching
entries in the mapping will be skipped.

=item mapping

Hash that defines how to map. Key defines position
in the result. Value can be one of the following:

If we're passed a scalar or an array reference then
value is:

    [
        [value1_of_attr1, value2_of_attr1],
        [value1_of_attr2, value2_of_attr2],
    ]

If we're passed a subroutine reference as value or
as an element of array, it executes the code
and returned list is pushed into results array:

    [
        @result_of_function,
    ]

All arguments are passed into the subroutine as well
as a few more. See more in description of C<$LDAPMapping>
option.

=back

Returns hash reference with results, each value is
an array with elements either scalars or arrays as
described above.

=cut

sub _parse_ldap_mapping {
    my $self = shift;
    my %args = @_;

    my $mapping = $args{mapping};

    my %res;
    foreach my $rtfield ( sort keys %$mapping ) {
        next if $args{'skip'} && $rtfield =~ $args{'skip'};
        next if $args{'only'} && $rtfield !~ $args{'only'};

        my $ldap_field = $mapping->{$rtfield};
        my @list = grep defined && length, ref $ldap_field eq 'ARRAY'? @$ldap_field : ($ldap_field);
        unless (@list) {
            $RT::Logger->error("Invalid LDAP mapping for $rtfield, no defined fields");
            next;
        }

        my @values;
        foreach my $e (@list) {
            if (ref $e eq 'CODE') {
                push @values, $e->(
                    %args,
                    self => $self,
                    rt_field => $rtfield,
                    ldap_field => $ldap_field,
                    result => \%res,
                );
            } elsif (ref $e) {
                $RT::Logger->error("Invalid type of LDAP mapping for $rtfield, value is $e");
                next;
            } else {
                # XXX: get_value asref returns undef if there is no such field on
                # the entry, should we warn?
                push @values, grep defined, $args{'ldap_entry'}->get_value( $e, asref => 1 );
            }
        }
        $res{ $rtfield } = \@values;
    }

    return \%res;
}

=head2 create_rt_user

Takes a hashref of args to pass to C<RT::User::Create>
Will try loading the user and will only create a new
user if it can't find an existing user with the C<Name>
or C<EmailAddress> arg passed in.

If the C<$LDAPUpdateUsers> variable is true, data in RT
will be clobbered with data in LDAP.  Otherwise we
will skip to the next user.

If C<$LDAPUpdateOnly> is true, we will not create new users
but we will update existing ones.

=cut

sub create_rt_user {
    my $self = shift;
    my %args = @_;
    my $user = $args{user};

    my $user_obj = $self->_load_rt_user(%args);

    if ($user_obj->Id) {
        my $message = "User $user->{Name} already exists as ".$user_obj->Id;
        if ($RT::LDAPUpdateUsers || $RT::LDAPUpdateOnly) {
            $RT::Logger->debug("$message, updating their data");
            if ($args{import}) {
                my @results = $user_obj->Update( ARGSRef => $user, AttributesRef => [keys %$user] );
                $RT::Logger->debug(join("\n",@results)||'no change');
            } else {
                $RT::Logger->debug("Found existing user $user->{Name} to update");
                $self->_show_user_info( %args, rt_user => $user_obj );
            }
        } else {
            $RT::Logger->debug("$message, skipping");
        }
    } else {
        if ( $RT::LDAPUpdateOnly ) {
            $RT::Logger->debug("User $user->{Name} doesn't exist in RT, skipping");
            return;
        } else {
            if ($args{import}) {
                my ($val, $msg) = $user_obj->Create( %$user, Privileged => $RT::LDAPCreatePrivileged ? 1 : 0 );

                unless ($val) {
                    $RT::Logger->error("couldn't create user_obj for $user->{Name}: $msg");
                    return;
                }
                $RT::Logger->debug("Created user for $user->{Name} with id ".$user_obj->Id);
            } else {
                $RT::Logger->debug( "Found new user $user->{Name} to create in RT" );
                $self->_show_user_info( %args );
                return;
            }
        }
    }

    unless ($user_obj->Id) {
        $RT::Logger->error("We couldn't find or create $user->{Name}. This should never happen");
    }
    return $user_obj;

}

sub _load_rt_user {
    my $self = shift;
    my %args = @_;
    my $user = $args{user};

    my $user_obj = RT::User->new($RT::SystemUser);

    $user_obj->Load( $user->{Name} );
    unless ($user_obj->Id) {
        $user_obj->LoadByEmail( $user->{EmailAddress} );
    }

    return $user_obj;
}

=head2 add_user_to_group

Adds new users to the group specified in the C<$LDAPGroupName>
variable (defaults to 'Imported from LDAP').
You can avoid this if you set C<$LDAPSkipAutogeneratedGroup>.

=cut

sub add_user_to_group {
    my $self = shift;
    my %args = @_;
    my $user = $args{user};

    return if $RT::LDAPSkipAutogeneratedGroup;

    my $group = $self->_group||$self->setup_group;

    my $principal = $user->PrincipalObj;

    if ($group->HasMember($principal)) {
        $RT::Logger->debug($user->Name . " already a member of " . $group->Name);
        return;
    }

    if ($args{import}) {
        my ($status, $msg) = $group->AddMember($principal->Id);
        if ($status) {
            $RT::Logger->debug("Added ".$user->Name." to ".$group->Name." [$msg]");
        } else {
            $RT::Logger->error("Couldn't add ".$user->Name." to ".$group->Name." [$msg]");
        }
        return $status;
    } else {
        $RT::Logger->debug("Would add to ".$group->Name);
        return;
    }
}

=head2 setup_group

Pulls the C<$LDAPGroupName> object out of the DB or
creates it if we need to do so.

=cut

sub setup_group  {
    my $self = shift;
    my $group_name = $RT::LDAPGroupName||'Imported from LDAP';
    my $group = RT::Group->new($RT::SystemUser);

    $group->LoadUserDefinedGroup( $group_name );
    unless ($group->Id) {
        my ($id,$msg) = $group->CreateUserDefinedGroup( Name => $group_name );
        unless ($id) {
            $RT::Logger->error("Can't create group $group_name [$msg]")
        }
    }

    $self->_group($group);
}

=head3 add_custom_field_value

Adds values to a Select (one|many) Custom Field.
The Custom Field should already exist, otherwise
this will throw an error and not import any data.

This could probably use some caching.

=cut

sub add_custom_field_value {
    my $self = shift;
    my %args = @_;
    my $user = $args{user};

    my $data = $self->_build_object(
        %args,
        only => qr/^CF\.(.+)$/i,
        mapping => $RT::LDAPMapping,
    );

    foreach my $rtfield ( keys %$data ) {
        next unless $rtfield =~ /^CF\.(.+)$/i;
        my $cf_name = $1;

        my $cfv_name = $data->{ $rtfield }
            or next;

        my $cf = RT::CustomField->new($RT::SystemUser);
        my ($status, $msg) = $cf->Load($cf_name);
        unless ($status) {
            $RT::Logger->error("Couldn't load CF [$cf_name]: $msg");
            next;
        }

        my $cfv = RT::CustomFieldValue->new($RT::SystemUser);
        $cfv->LoadByCols( CustomField => $cf->id,
                          Name => $cfv_name );
        if ($cfv->id) {
            $RT::Logger->debug("Custom Field '$cf_name' already has '$cfv_name' for a value");
            next;
        }

        if ($args{import}) {
            ($status, $msg) = $cf->AddValue( Name => $cfv_name );
            if ($status) {
                $RT::Logger->debug("Added '$cfv_name' to Custom Field '$cf_name' [$msg]");
            } else {
                $RT::Logger->error("Couldn't add '$cfv_name' to '$cf_name' [$msg]");
            }
        } else {
            $RT::Logger->debug("Would add '$cfv_name' to Custom Field '$cf_name'");
        }
    }

    return;

}

=head3 update_object_custom_field_values

Adds CF values to an object (currently only users).  The Custom Field should
already exist, otherwise this will throw an error and not import any data.

Note that this code only B<adds> values at the moment, which on single value
CFs will remove any old value first.  Multiple value CFs may behave not quite
how you expect.

=cut

sub update_object_custom_field_values {
    my $self = shift;
    my %args = @_;
    my $obj  = $args{object};

    my $data = $self->_build_object(
        %args,
        only => qr/^UserCF\.(.+)$/i,
        mapping => $RT::LDAPMapping,
    );

    foreach my $rtfield ( sort keys %$data ) {
        # XXX TODO: accept GroupCF when we call this from group_import too
        next unless $rtfield =~ /^UserCF\.(.+)$/i;
        my $cf_name = $1;
        my $value = $data->{$rtfield};
        $value = '' unless defined $value;

        my $current = $obj->FirstCustomFieldValue($cf_name);
        $current = '' unless defined $current;

        if (not length $current and not length $value) {
            $RT::Logger->debug("\tCF.$cf_name\tskipping, no value in RT and LDAP");
            next;
        }
        elsif ($current eq $value) {
            $RT::Logger->debug("\tCF.$cf_name\tunchanged => $value");
            next;
        }

        $current = 'unset' unless length $current;
        $RT::Logger->debug("\tCF.$cf_name\t$current => $value");
        next unless $args{import};

        my ($ok, $msg) = $obj->AddCustomFieldValue( Field => $cf_name, Value => $value );
        $RT::Logger->error($obj->Name . ": Couldn't add value '$value' for '$cf_name': $msg")
            unless $ok;
    }
}

=head2 import_groups import => 1|0

Takes the results of the search from C<run_group_search>
and maps attributes from LDAP into C<RT::Group> attributes
using C<$LDAPGroupMapping>.

Creates groups if they don't exist.

Removes users from groups if they have been removed from the group on LDAP.

With no arguments, only prints debugging information.
Pass C<--import> to actually change data.

=cut

sub import_groups {
    my $self = shift;
    my %args = @_;

    my @results = $self->run_group_search;
    unless ( @results ) {
        $RT::Logger->debug("No results found, no group import");
        $self->disconnect_ldap;
        return;
    }

    my $mapping = $RT::LDAPGroupMapping;
    return unless $self->_check_ldap_mapping( mapping => $mapping );

    my $done = 0; my $count = scalar @results;
    while (my $entry = shift @results) {
        my $group = $self->_parse_ldap_mapping(
            %args,
            ldap_entry => $entry,
            skip => qr/^Member_Attr_Value$/i,
            mapping => $mapping,
        );
        foreach my $key ( grep !/^Member_Attr/, keys %$group ) {
            @{ $group->{$key} } = map { ref $_ eq 'ARRAY'? $_->[0] : $_ } @{ $group->{$key} };
            $group->{$key} = join ' ', grep defined && length, @{ $group->{$key} };
        }
        @{ $group->{'Member_Attr'} } = map { ref $_ eq 'ARRAY'? @$_ : $_  } @{ $group->{'Member_Attr'} }
            if $group->{'Member_Attr'};
        $group->{Description} ||= 'Imported from LDAP';
        unless ( $group->{Name} ) {
            $RT::Logger->warn("No Name for group, skipping ".Dumper $group);
            next;
        }
        if ( $group->{Name} =~ /^[0-9]+$/) {
            $RT::Logger->debug("Skipping group '$group->{Name}', as it is numeric");
            next;
        }
        $self->_import_group( %args, group => $group, ldap_entry => $entry );
        $done++;
        $RT::Logger->debug("Imported $done/$count groups");
    }
    return 1;
}

=head3 run_group_search

Set up the appropriate arguments for a listing of users.

=cut

sub run_group_search {
    my $self = shift;

    unless ($RT::LDAPGroupBase && $RT::LDAPGroupFilter) {
        $RT::Logger->warn("Not running a group import, configuration not set");
        return;
    }
    $self->_run_search(
        base   => $RT::LDAPGroupBase,
        filter => $RT::LDAPGroupFilter
    );

}


=head2 _import_group

The user has run us with C<--import>, so bring data in.

=cut

sub _import_group {
    my $self = shift;
    my %args = @_;
    my $group = $args{group};
    my $ldap_entry = $args{ldap_entry};

    $RT::Logger->debug("Processing group $group->{Name}");
    my ($group_obj, $created) = $self->create_rt_group( %args, group => $group );
    return if $args{import} and not $group_obj;
    $self->add_group_members(
        %args,
        name => $group->{Name},
        info => $group,
        group => $group_obj,
        ldap_entry => $ldap_entry,
        new => $created,
    );
    # XXX TODO: support OCFVs for groups too
    return;
}

=head2 create_rt_group

Takes a hashref of args to pass to C<RT::Group::Create>
Will try loading the group and will only create a new
group if it can't find an existing group with the C<Name>
or C<EmailAddress> arg passed in.

If C<$LDAPUpdateOnly> is true, we will not create new groups
but we will update existing ones.

There is currently no way to prevent Group data from being
clobbered from LDAP.

=cut

sub create_rt_group {
    my $self = shift;
    my %args = @_;
    my $group = $args{group};

    my $group_obj = $self->find_rt_group(%args);
    return unless defined $group_obj;

    $group = { map { $_ => $group->{$_} } qw(id Name Description) };

    my $id = delete $group->{'id'};

    my $created;
    if ($group_obj->Id) {
        if ($args{import}) {
            $RT::Logger->debug("Group $group->{Name} already exists as ".$group_obj->Id.", updating their data");
            my @results = $group_obj->Update( ARGSRef => $group, AttributesRef => [keys %$group] );
            $RT::Logger->debug(join("\n",@results)||'no change');
        } else {
            $RT::Logger->debug( "Found existing group $group->{Name} to update" );
            $self->_show_group_info( %args, rt_group => $group_obj );
        }
    } else {
        if ( $RT::LDAPUpdateOnly ) {
            $RT::Logger->debug("Group $group->{Name} doesn't exist in RT, skipping");
            return;
        }

        if ($args{import}) {
            my ($val, $msg) = $group_obj->CreateUserDefinedGroup( %$group );
            unless ($val) {
                $RT::Logger->error("couldn't create group_obj for $group->{Name}: $msg");
                return;
            }
            $created = $val;
            $RT::Logger->debug("Created group for $group->{Name} with id ".$group_obj->Id);

            if ( $id ) {
                my ($val, $msg) = $group_obj->SetAttribute( Name => 'LDAPImport-gid-'.$id, Content => 1 );
                unless ($val) {
                    $RT::Logger->error("couldn't set attribute: $msg");
                    return;
                }
            }

        } else {
            $RT::Logger->debug( "Found new group $group->{Name} to create in RT" );
            $self->_show_group_info( %args );
            return;
        }
    }

    unless ($group_obj->Id) {
        $RT::Logger->error("We couldn't find or create $group->{Name}. This should never happen");
    }
    return ($group_obj, $created);

}

=head3 find_rt_group

Loads groups by Name and by the specified LDAP id. Attempts to resolve
renames and other out-of-sync failures between RT and LDAP.

=cut

sub find_rt_group {
    my $self = shift;
    my %args = @_;
    my $group = $args{group};

    my $group_obj = RT::Group->new($RT::SystemUser);
    $group_obj->LoadUserDefinedGroup( $group->{Name} );
    return $group_obj unless $group->{'id'};

    unless ( $group_obj->id ) {
        $RT::Logger->debug("No group in RT named $group->{Name}. Looking by $group->{id} LDAP id.");
        $group_obj = $self->find_rt_group_by_ldap_id( $group->{'id'} );
        unless ( $group_obj ) {
            $RT::Logger->debug("No group in RT with LDAP id $group->{id}. Creating a new one.");
            return RT::Group->new($RT::SystemUser);
        }

        $RT::Logger->debug("No group in RT named $group->{Name}, but found group by LDAP id $group->{id}. Renaming the group.");
        # $group->Update will take care of the name
        return $group_obj;
    }

    my $attr_name = 'LDAPImport-gid-'. $group->{'id'};
    my $rt_gid = $group_obj->FirstAttribute( $attr_name );
    return $group_obj if $rt_gid;

    my $other_group = $self->find_rt_group_by_ldap_id( $group->{'id'} );
    if ( $other_group ) {
        $RT::Logger->debug("Group with LDAP id $group->{id} exists, as well as group named $group->{Name}. Renaming both.");
    }
    elsif ( grep $_->Name =~ /^LDAPImport-gid-/, @{ $group_obj->Attributes->ItemsArrayRef } ) {
        $RT::Logger->debug("No group in RT with LDAP id $group->{id}, but group $group->{Name} has id. Renaming the group and creating a new one.");
    }
    else {
        $RT::Logger->debug("No group in RT with LDAP id $group->{id}, but group $group->{Name} exists and has no LDAP id. Assigning the id to the group.");
        if ( $args{import} ) {
            my ($status, $msg) = $group_obj->SetAttribute( Name => $attr_name, Content => 1 );
            unless ( $status ) {
                $RT::Logger->error("Couldn't set attribute: $msg");
                return undef;
            }
            $RT::Logger->debug("Assigned $group->{id} LDAP group id to $group->{Name}");
        }
        else {
            $RT::Logger->debug( "Group $group->{'Name'} gets LDAP id $group->{id}" );
        }

        return $group_obj;
    }

    # rename existing group to move it out of our way
    {
        my ($old, $new) = ($group_obj->Name, $group_obj->Name .' (LDAPImport '. time . ')');
        if ( $args{import} ) {
            my ($status, $msg) = $group_obj->SetName( $new );
            unless ( $status ) {
                $RT::Logger->error("Couldn't rename group from $old to $new: $msg");
                return undef;
            }
            $RT::Logger->debug("Renamed group $old to $new");
        }
        else {
            $RT::Logger->debug( "Group $old to be renamed to $new" );
        }
    }

    return $other_group || RT::Group->new($RT::SystemUser);
}

=head3 find_rt_group_by_ldap_id

Loads an RT::Group by the ldap provided id (different from RT's internal group
id)

=cut

sub find_rt_group_by_ldap_id {
    my $self = shift;
    my $id = shift;

    my $groups = RT::Groups->new( RT->SystemUser );
    $groups->LimitToUserDefinedGroups;
    my $attr_alias = $groups->Join( FIELD1 => 'id', TABLE2 => 'Attributes', FIELD2 => 'ObjectId' );
    $groups->Limit( ALIAS => $attr_alias, FIELD => 'ObjectType', VALUE => 'RT::Group' );
    $groups->Limit( ALIAS => $attr_alias, FIELD => 'Name', VALUE => 'LDAPImport-gid-'. $id );
    return $groups->First;
}


=head3 add_group_members

Iterate over the list of values in the C<Member_Attr> LDAP entry.
Look up the appropriate username from LDAP.
Add those users to the group.
Remove members of the RT Group who are no longer members
of the LDAP group.

=cut

sub add_group_members {
    my $self = shift;
    my %args = @_;
    my $group = $args{group};
    my $groupname = $args{name};
    my $ldap_entry = $args{ldap_entry};

    $RT::Logger->debug("Processing group membership for $groupname");

    my $members = $args{'info'}{'Member_Attr'};
    unless (defined $members) {
        $RT::Logger->warn("No members found for $groupname in Member_Attr");
        return;
    }

    if ($RT::LDAPImportGroupMembers) {
        $RT::Logger->debug("Importing members of group $groupname");
        my @entries;
        my $attr = lc($RT::LDAPGroupMapping->{Member_Attr_Value} || 'dn');

        # Lookup each DN's full entry, or...
        if ($attr eq 'dn') {
            @entries = grep defined, map {
                my @results = $self->_run_search(
                    scope   => 'base',
                    base    => $_,
                    filter  => $RT::LDAPFilter,
                );
                $results[0]
            } @$members;
        }
        # ...or find all the entries in a single search by attribute.
        else {
            # I wonder if this will run into filter length limits? -trs, 22 Jan 2014
            my $members = join "", map { "($attr=" . escape_filter_value($_) . ")" } @$members;
            @entries = $self->_run_search(
                base   => $RT::LDAPBase,
                filter => "(&$RT::LDAPFilter(|$members))",
            );
        }
        $self->_import_users(
            import  => $args{import},
            users   => \@entries,
        ) or $RT::Logger->debug("Importing group members failed");
    }

    my %rt_group_members;
    if ($args{group} and not $args{new}) {
        my $user_members = $group->UserMembersObj( Recursively => 0);

        # find members who are Disabled too so we don't try to add them below
        $user_members->FindAllRows;

        while ( my $member = $user_members->Next ) {
            $rt_group_members{$member->Name} = $member;
        }
    } elsif (not $args{import}) {
        $RT::Logger->debug("No group in RT, would create with members:");
    }

    my $users = $self->_users;
    foreach my $member (@$members) {
        my $username;
        if (exists $users->{lc $member}) {
            next unless $username = $users->{lc $member};
        } else {
            my $attr    = lc($RT::LDAPGroupMapping->{Member_Attr_Value} || 'dn');
            my $base    = $attr eq 'dn' ? $member : $RT::LDAPBase;
            my $scope   = $attr eq 'dn' ? 'base'  : 'sub';
            my $filter  = $attr eq 'dn'
                            ? $RT::LDAPFilter
                            : "(&$RT::LDAPFilter($attr=" . escape_filter_value($member) . "))";
            my @results = $self->_run_search(
                base   => $base,
                scope  => $scope,
                filter => $filter,
            );
            unless ( @results ) {
                $users->{lc $member} = undef;
                $RT::Logger->error("No user found for $member who should be a member of $groupname");
                next;
            }
            my $ldap_user = shift @results;
            $username = $self->_cache_user( ldap_entry => $ldap_user );
        }
        if ( delete $rt_group_members{$username} ) {
            $RT::Logger->debug("\t$username\tin RT and LDAP");
            next;
        }
        $RT::Logger->debug($group ? "\t$username\tin LDAP, adding to RT" : "\t$username");
        next unless $args{import};

        my $rt_user = RT::User->new($RT::SystemUser);
        my ($res,$msg) = $rt_user->Load( $username );
        unless ($res) {
            $RT::Logger->warn("Unable to load $username: $msg");
            next;
        }
        ($res,$msg) = $group->AddMember($rt_user->PrincipalObj->Id);
        unless ($res) {
            $RT::Logger->warn("Failed to add $username to $groupname: $msg");
        }
    }

    for my $username (sort keys %rt_group_members) {
        $RT::Logger->debug("\t$username\tin RT, not in LDAP, removing");
        next unless $args{import};

        my ($res,$msg) = $group->DeleteMember($rt_group_members{$username}->PrincipalObj->Id);
        unless ($res) {
            $RT::Logger->warn("Failed to remove $username to $groupname: $msg");
        }
    }
}

=head2 _show_group

Show debugging information about the group record we're going to import
when the groups reruns us with C<--import>.

=cut

sub _show_group {
    my $self = shift;
    my %args = @_;
    my $group = $args{group};

    my $rt_group = RT::Group->new($RT::SystemUser);
    $rt_group->LoadUserDefinedGroup( $group->{Name} );

    if ( $rt_group->Id ) {
        $RT::Logger->debug( "Found existing group $group->{Name} to update" );
        $self->_show_group_info( %args, rt_group => $rt_group );
    } else {
        $RT::Logger->debug( "Found new group $group->{Name} to create in RT" );
        $self->_show_group_info( %args );
    }
}

sub _show_group_info {
    my $self = shift;
    my %args = @_;
    my $group = $args{group};
    my $rt_group = $args{rt_group};

    $RT::Logger->debug( "\tRT Field\tRT Value -> LDAP Value" );
    foreach my $key (sort keys %$group) {
        my $old_value;
        if ($rt_group) {
            eval { $old_value = $rt_group->$key() };
            if ($group->{$key} && defined $old_value && $old_value eq $group->{$key}) {
                $old_value = 'unchanged';
            }
        }
        $old_value ||= 'unset';
        $RT::Logger->debug( "\t$key\t$old_value => $group->{$key}" );
    }
}


=head3 disconnect_ldap

Disconnects from the LDAP server.

Takes no arguments, returns nothing.

=cut

sub disconnect_ldap {
    my $self = shift;
    my $ldap = $self->_ldap;
    return unless $ldap;

    $ldap->unbind;
    $ldap->disconnect;
    $self->_ldap(undef);
    return;
}

RT::Base->_ImportOverlays();

1;
