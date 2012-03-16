use strict;
use warnings;

use RT::Test nodata => 1, tests => 376;

my %GROUP;
foreach my $name (qw(A B C D)) {
    my $group = $GROUP{$name} = RT::Group->new( RT->SystemUser );
    my ($status, $msg) = $group->CreateUserDefinedGroup( Name => $name );
    ok $status, "created a group '$name'" or diag "error: $msg";
}

my %USER;
foreach my $name (qw(a b c d)) {
    my $user = $USER{$name} = RT::User->new( RT->SystemUser );
    my ($status, $msg) = $user->Create( Name => $name );
    ok $status, "created an user '$name'" or diag "error: $msg";
}

my %DISABLED;

{
    add_members_ok( A => qw(a b c) );
    check_membership( A => [qw(a b c)] );

    add_members_ok( B => qw(A) );
    add_members_ok( C => qw(B) );
    check_membership( A => [qw(a b c)], B => [qw(A)], C => [qw(B)] );

    del_members_ok( A => 'b' );
    check_membership( A => [qw(a c)], B => [qw(A)], C => [qw(B)] );

    add_members_ok( A => qw(b) );
    add_members_ok( B => qw(b) );
    check_membership( A => [qw(a b c)], B => [qw(A b)], C => [qw(B)] );

    del_members_ok( A => 'b' );
    check_membership( A => [qw(a c)], B => [qw(A b)], C => [qw(B)] );

    random_delete( A => [qw(a c)], B => [qw(A b)], C => [qw(B)] );
}

{
    add_members_ok( A => qw(B C) );
    add_members_ok( B => qw(D) );
    add_members_ok( C => qw(D) );
    add_members_ok( A => qw(D) );
    check_membership( A => [qw(B C D)], B => [qw(D)], C => [qw(D)] );

    del_members_ok( A => qw(D) );
    check_membership( A => [qw(B C)], B => [qw(D)], C => [qw(D)] );
    random_delete( A => [qw(B C)], B => [qw(D)], C => [qw(D)] );
}

{
    add_members_ok( A => qw(B C) );
    add_members_ok( B => qw(d) );
    add_members_ok( C => qw(d) );
    add_members_ok( A => qw(d) );
    check_membership( A => [qw(B C d)], B => [qw(d)], C => [qw(d)] );

    del_members_ok( A => qw(d) );
    check_membership( A => [qw(B C)], B => [qw(d)], C => [qw(d)] );
    random_delete( A => [qw(B C)], B => [qw(d)], C => [qw(d)] );
}

for (1..3) {
    random_delete( random_build() );
}

{
# variations of ruby:
#   A
# / | \
# B | C
# \ | /
#   D
    add_members_ok( A => qw(B C) );
    add_members_ok( B => qw(D) );
    add_members_ok( C => qw(D) );

    # disable B with A -> C -> D active alternative for A->D
    disable_group_ok( 'B' );
    check_cgm_activity( A => [qw(B C)], B => [qw(D)], C => [qw(D)] );

    # disable C, no more active alternative for A->D
    disable_group_ok( 'C' );
    check_cgm_activity( A => [qw(B C)], B => [qw(D)], C => [qw(D)] );

    # add direct active (A->D) link
    add_members_ok( A => qw(D) );
    check_cgm_activity( A => [qw(B C D)], B => [qw(D)], C => [qw(D)] );

    # delete active (A->D) when all alternative are disabled
    del_members_ok( A => 'D' );
    check_cgm_activity( A => [qw(B C)], B => [qw(D)], C => [qw(D)] );

    # enable C that enables A->D
    enable_group_ok( 'C' );
    check_cgm_activity( A => [qw(B C)], B => [qw(D)], C => [qw(D)] );

    # delete (A->B) and add back, B is disabled
    del_members_ok( A => 'B' );
    add_members_ok( A => qw(B) );
    check_cgm_activity( A => [qw(B C)], B => [qw(D)], C => [qw(D)] );

    random_delete( A => [qw(B C)], B => [qw(D)], C => [qw(D)] );

    enable_group_ok( 'B' );
}

{
# variations of triangle
#   A
# /   \
# B -> C
    add_members_ok( A => qw(B C) );
    disable_group_ok( 'B' );

    # add member to disabled group
    add_members_ok( B => qw(C) );
    check_cgm_activity( A => [qw(B C)], B => [qw(C)] );

    random_delete( A => [qw(B C)], B => [qw(C)] );
    enable_group_ok( 'B' );
}

sub random_build {
    my (%GM, %RCGM);

    my @groups = keys %GROUP;

    my $i = 9;
    while ( $i-- ) {
        REPICK:
        my $g = $groups[int rand @groups];
        my @members = (keys %GROUP, keys %USER);
        substract_list(
            \@members,
            $g,
            $GM{$g}? @{$GM{$g}} : (),
            $RCGM{$g}? @{$RCGM{$g}} : (),
        );
        unless ( @members ) {
            substract_list(\@groups, $g);
            die "boo" unless @groups;
            goto REPICK;
        }

        my $m = $members[int rand @members];

        my $error = "($g -> $m) to ". describe_state(%GM);
        diag "going to add $error";

        add_members_ok( $g => $m );
        push @{ $GM{ $g }||=[] }, $m;
        unless ( check_membership( %GM ) ) {
            Test::More::diag("were adding $error") unless $ENV{'TEST_VERBOSE'};
        }

        %RCGM = reverse_gm( gm_to_cgm(%GM) );
    }
    return %GM;
}

sub random_delete {
    my %GM = @_;

    while ( my @groups = keys %GM ) {
        my $g = $groups[ int rand @groups ];
        my $m = $GM{ $g }->[ int rand @{ $GM{ $g } } ];

        my $error = "($g -> $m) from ". describe_state(%GM);
        diag "going to delete $error";

        del_members_ok( $g => $m );
        @{ $GM{ $g } } = grep $_ ne $m, @{ $GM{ $g } };
        delete $GM{ $g } unless @{ $GM{ $g } };

        unless ( check_membership( %GM ) ) {
            Test::More::diag("were deleting $error") unless $ENV{'TEST_VERBOSE'};
        }
    }
}

sub describe_state {
    my %GM = @_;
    return '('. join(
        ', ',
        map { "$_ -> [". join( ' ', @{ $GM{ $_ } } )."]" } sort keys %GM
    ) .')';
}

sub check_membership {
    local $Test::Builder::Level = $Test::Builder::Level + 1;

    my %GM = @_;
    my $res = _check_membership( HasMember => %GM );
    my %CGM = gm_to_cgm(%GM);
    $res &&= _check_membership( HasMemberRecursively => %CGM );
    $res &&= check_cgm_activity( %GM );
    return $res;
}

sub gm_to_cgm {
    my %GM = @_;

    my $flat;
    $flat = sub {
        return unless $GM{ $_[0] };
        return map { $_, $flat->($_) } @{ $GM{ $_[0] } };
    };

    my %CGM;
    $CGM{ $_ } = [ $flat->( $_ ) ] foreach keys %GM;
    return %CGM;
}

sub gm_to_activity {
    my %GM = @_;

    my $flat;
    $flat = sub {
        return if $DISABLED{ $_[0] };
        my @self_ref = $GROUP{$_[0]} && !$DISABLED{$_[0]}? ($_[0]) : ();
        return @self_ref unless $GM{ $_[0] };
        return @self_ref, map { $_, $flat->($_) } @{ $GM{ $_[0] } };
    };

    my %CGM;
    $CGM{ $_ } = [ $flat->( $_ ) ] foreach keys %GROUP;
    return %CGM;
}

sub reverse_gm {
    my %GM = @_;
    my %res = @_;

    foreach my $g ( keys %GM ) {
        push @{ $res{$_}||=[] }, $g foreach @{ $GM{ $g } };
    }
    return %res;
}

sub check_cgm_activity {
    local $Test::Builder::Level = $Test::Builder::Level + 1;

    my %GM = @_;

    my $id_to_name = sub {
        my $p = RT::Principal->new( RT->SystemUser );
        $p->Load($_[0]);
        $p->Object->Name;
    };

    my $data = $RT::Handle->dbh->selectall_arrayref(
        "SELECT GroupId, MemberId FROM CachedGroupMembers WHERE Disabled = 0"
        .' AND GroupId IN ('. join( ', ', map $_->id, values %GROUP, values %USER ) .')'
        .' AND MemberId IN ('. join( ', ', map $_->id, values %GROUP, values %USER ) .')'
    );

    my %got;
    foreach (@$data) {
        my ($g, $m) = (map $id_to_name->($_), @$_);
        push @{ $got{$g} ||= []}, $m;
    }

    my %expected = gm_to_activity( %GM );

    foreach my $hash (\%got, \%expected) {
        foreach ( values %$hash ) {
            my %seen;
            @$_ = sort grep !$seen{$_}++, @$_;
        }
        delete $hash->{$_} foreach grep !@{$hash->{$_}}, keys %$hash;
    }
    use Data::Dumper;
    is_deeply(\%got, \%expected, 'activity of the records is correct')
        or diag Dumper( \%got, \%expected );
}

sub _check_membership {
    local $Test::Builder::Level = $Test::Builder::Level + 1;

    my $method = shift;
    my %GM = @_;

    my $not_ok = 0;
    foreach my $gname ( keys %GROUP ) {
        foreach my $mname ( grep $gname ne $_, keys %USER, keys %GROUP ) {
            my $ok;
            if ( $GM{$gname} && grep $mname eq $_, @{$GM{$gname}} ) {
                #note "checking ($gname -> $mname) for presence";
                unless ( $GROUP{$gname}->$method( ($USER{$mname}||$GROUP{$mname})->PrincipalObj ) ) {
                    $not_ok = 1;
                    note "Group $gname has no member $mname, but should";
                }
            } else {
                #note "checking ($gname -> $mname) for absence";
                if ( $GROUP{$gname}->$method( ($USER{$mname}||$GROUP{$mname})->PrincipalObj ) ) {
                    $not_ok = 1;
                    note "Group $gname has member $mname, but should not";
                }
            }
        }
    }
    return ok !$not_ok, "$method is ok";
}

sub add_members_ok {
    my ($g, @members) = @_;
    foreach my $m (@members) {
        my ($status, $msg) = $GROUP{$g}->AddMember( ($USER{$m}||$GROUP{$m})->PrincipalId );
        ok $status, $msg;
    }
}
sub del_members_ok {
    my ($g, @members) = @_;
    foreach my $m (@members) {
        my ($status, $msg) = $GROUP{$g}->DeleteMember( ($USER{$m}||$GROUP{$m})->PrincipalId );
        ok $status, $msg;
    }
}

sub dump_gm {
    my ($G, $M) = @_;
    my $dbh = $RT::Handle->dbh;

    my $gm_id = sub {
        my ($G, $M) = @_;
        return ($dbh->selectrow_array(
            "SELECT id FROM GroupMembers WHERE GroupId = $G AND MemberId = $M"
        ))[0] || 0;
    };
    my $cgm_id = sub {
        my ($G, $M) = @_;
        return ($dbh->selectrow_array(
            "SELECT id FROM CachedGroupMembers WHERE GroupId = $G AND MemberId = $M"
        ))[0] || 0;
    };
    my $anc = sub {
        my $M = shift;
        return @{$dbh->selectcol_arrayref(
            "SELECT GroupId FROM CachedGroupMembers WHERE MemberId = $M"
        )};
    };
    my $des = sub {
        my $G = shift;
        return @{$dbh->selectcol_arrayref(
            "SELECT MemberId FROM CachedGroupMembers WHERE GroupId = $G"
        )};
    };
    my $anc_des_pairs = sub {
        my ($G,$M) = @_;

        foreach my $A ( $anc->($G) ) {
            foreach my $D ( $des->($M) ) {
                next unless my $id = $cgm_id->($A, $D);
                diag "\t($A,$D) (#$id)(GM#". $gm_id->($A, $D).")";
            }
        }
    };

    my $id;
    diag "Dumping GM ($G, $M) (#". $gm_id->($G, $M) .')';
    diag "CGM ($G, $M) (#". $cgm_id->($G, $M) .')';
    diag "An($G): ". join ',', map "$_ (GM#". $gm_id->($_, $G) .")", $anc->($G);
    diag "De($M): ". join ',', map "$_ (GM#". $gm_id->($M, $_) .")", $des->($M);
    diag "(An($G), De($M)): ";
    $anc_des_pairs->($G, $M);
}

sub disable_group_ok {
    my $g = shift;
    my ($status, $msg) = $GROUP{ $g }->SetDisabled(1);
    ok $status, "disabled group '$g'" or diag "error: $msg";
    $DISABLED{$g} = $GROUP{ $g }->Disabled;
}
sub enable_group_ok {
    my $g = shift;
    my ($status, $msg) = $GROUP{ $g }->SetDisabled(0);
    ok $status, "enabled group '$g'" or diag "error: $msg";
    $DISABLED{$g} = $GROUP{ $g }->Disabled;
}

sub substract_list {
    my $list = shift;
    foreach my $e ( @_ ) {
        @$list = grep $_ ne $e, @$list;
    }
}
