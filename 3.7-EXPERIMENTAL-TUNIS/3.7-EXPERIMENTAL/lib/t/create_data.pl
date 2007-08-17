#!@PERL@ -w
use strict;

use Test::More qw/no_plan/;
use Text::Lorem;
use RT;
RT::LoadConfig;
RT::Init;

#### Generate some number of RT accounts.  Come up with random
#### usernames if requested, otherwise use provided ones.  Take
#### $subdomain argument so that we can generate customer accounts,
#### etc.  Group memberships should also be provided.

=head2 create_users

=over 4

This subroutine creates a number of RT users, if they don't already
exist, and places them in the specified group.  It also creates the
group if it needs to.  Returns a ref to a list containing the user
objects.

If a list of names is specified, users with those names are created.
Otherwise, it will make names up, checking to be sure that a user with
the random name does not yet exist.  Each user will have an email
address in "example.com".

Takes a hash of the following arguments:
number => How many users to create.  Default is 1.
names => A ref to a list of usernames to use.  Optional.
subdomain => The subdomain of example.com which should be used for
    email addresses.
group => The name of the group these users should belong to.  Creates
    the group if it does not yet exist.
privileged => Whether the users should be able to be granted rights.
    Default is 1.
attributes => a ref to a list of hashrefs containing the arguments for 
    any unsupported attribute we should add to the user (for example, a 
    user saved search.)

=back

=cut

sub create_users {
    my %ARGS = (number => 1,
		subdomain => undef,
		privileged => 1,
		@_);
    my $lorem = Text::Lorem->new();
    my @users_returned;

    my @usernames;
    my $anon;
    if ($ARGS{'users'}) {
	@usernames = @{$ARGS{'users'}};
	$anon = 0;
    } else {
	@usernames = split(/\s+/, $lorem->words($ARGS{'number'}));
	$anon = 1;
    }

    my $domain = 'example.com';
    $domain = $ARGS{'subdomain'} . ".$domain" if $ARGS{'subdomain'};

    foreach my $user (@usernames) {
	my $user_obj = RT::User->new($RT::SystemUser);
	$user_obj->Load($user);
	if ($user_obj->Id() && !$anon) {
	    # Use this user; assume we know what we're doing.  Don't
	    # modify it, other than adding it to any group specified.
	    push(@users_returned, $user_obj);
	} elsif ($user_obj->Id()) {
	    # Oops.  Get a different username and stick it on the back
	    # of the list.
	    append(@users, $lorem->words(1));
	} else {
	    $user_obj->Create(Name => $user,
			      Password => $user."pass",
			      EmailAddress => $user.'@'.$domain,
			      RealName => "$user ipsum",
			      Privileged => $ARGS{'privileged'},
			      );
	    push(@users_returned, $user_obj);
	}
    }

    # Now we have our list of users.  Did we have groups to add them
    # to?

    if ($ARGS{'groups'}) {
	my @groups = @{$ARGS{'groups'}};
	foreach my $group (@groups) {
	    my $group_obj = RT::Group->new();
	    $group_obj->LoadUserDefinedGroup($group);
	    unless ($group_obj->Id()) {
		# Create it.
		$group_obj->CreateUserDefinedGroup(
				Name => $group,
				Description => "lorem defined group $group",
						   );
	    }
	    foreach (@users_returned) {
		$group_obj->AddMember($_->Id);
	    }
	}
    }

    # Do we have attributes to apply to the users?
    if ($ARGS{'attributes'}) {
	foreach my $attrib (@{$ARGS{'attributes'}}) {
	    my %attr_args = %{$attrib};
	    foreach (@users_returned) {
		$_->AddAttribute(%attr_args);
	    }
	}
    }

    # Return our list of users.
    return \@users_returned;
}

#### Generate any RT groups.  These ought to be named, by function.
#### The group names should be given either as part of user creation,
#### or as a name with a number of subgroups which should be members.


#### Generate some queues.  Users/groups who have permissions on
#### queues need to be specified on this point.  Permissions can be
#### specified by role, e.g. "client" or "staffmember" or "admin" for
#### each queue.  If the queue should have anything special like a
#### custom field, say so here.


#### Generate some tickets and transactions.
