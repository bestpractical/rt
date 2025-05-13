# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2025 Best Practical Solutions, LLC
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

package RT::Record::Role::Scrip;

use strict;
use warnings;

use Role::Basic;
use Devel::GlobalDestruction;

=head1 NAME

RT::Record::Role::Scrip - Common methods for records that support scrips

=head1 DESCRIPTION

This role implements scrip related methods for records including Articles,
Assets, and Tickets.

=head1 REQUIRES

=head2 L<RT::Record::Role>

=cut

with 'RT::Record::Role';

=head1 PROVIDES

=head2 RanTransactionBatch

Acts as a guard around running TransactionBatch scrips.

Should be false until you enter the code that runs TransactionBatch scrips

Accepts an optional argument to indicate that TransactionBatch Scrips should no longer be run on this object.

=cut

sub RanTransactionBatch {
    my $self = shift;
    my $val = shift;

    if ( defined $val ) {
        return $self->{_RanTransactionBatch} = $val;
    } else {
        return $self->{_RanTransactionBatch};
    }

}


=head2 TransactionBatch

Returns an array reference of all transactions created on this ticket during
this ticket object's lifetime or since last application of a batch, or undef
if there were none.

Only works when the C<UseTransactionBatch> config option is set to true.

=cut

sub TransactionBatch {
    my $self = shift;
    return $self->{_TransactionBatch};
}

=head2 ApplyTransactionBatch

Applies scrips on the current batch of transactions and shinks it. Usually
batch is applied when object is destroyed, but in some cases it's too late.

=cut

sub ApplyTransactionBatch {
    my $self = shift;

    my $batch = $self->TransactionBatch;
    return unless $batch && @$batch;

    $self->_ApplyTransactionBatch;

    $self->{_TransactionBatch} = [];
}

sub _ApplyTransactionBatch {
    my $self = shift;

    return if $self->RanTransactionBatch;
    $self->RanTransactionBatch(1);

    my $still_exists = $self->new( RT->SystemUser );
    $still_exists->Load( $self->Id );
    if (not $still_exists->Id) {
        # The object has been removed from the database, but we still
        # have pending TransactionBatch txns for it.  Unfortunately,
        # because it isn't in the DB anymore, attempting to run scrips
        # on it may produce unpredictable results; simply drop the
        # batched transactions.
        $RT::Logger->warning("TransactionBatch was fired on an object that no longer exists; unable to run scrips!  Call ->ApplyTransactionBatch before shredding the object, for consistent results.");
        return;
    }

    my $batch = $self->TransactionBatch;

    my %seen;
    my $types = join ',', grep !$seen{$_}++, grep defined, map $_->__Value('Type'), grep defined, @{$batch};

    require RT::Scrips;
    my $scrips = RT::Scrips->new(RT->SystemUser);
    $scrips->Prepare(
        Stage                     => 'TransactionBatch',
        Object                    => $self,
        $self->RecordType . 'Obj' => $self,
        LookupType                => $self->CustomFieldLookupType,
        TransactionObj            => $batch->[0],
        Type                      => $types,
    );

    # Entry point of the rule system
    my $rules = RT::Ruleset->FindAllRules(
        Stage          => 'TransactionBatch',
        Object         => $self,
        $self->RecordType . 'Obj' => $self,
        TransactionObj => $batch->[0],
        Type           => $types,
    );

    if ($self->{DryRun}) {
        my $fake_txn = RT::Transaction->new( $self->CurrentUser );
        $fake_txn->{scrips} = $scrips;
        $fake_txn->{rules} = $rules;
        push @{$self->{DryRun}}, $fake_txn;
    } else {
        $scrips->Commit;
        RT::Ruleset->CommitRules($rules);
    }
}

sub DESTROY {
    my $self = shift;

    # DESTROY methods need to localize $@, or it may unset it.  This
    # causes $m->abort to not bubble all of the way up.  See perlbug
    # http://rt.perl.org/rt3/Ticket/Display.html?id=17650
    local $@;

    # The following line eliminates reentrancy.
    # It protects against the fact that perl doesn't deal gracefully
    # when an object's refcount is changed in its destructor.
    return if $self->{_Destroyed}++;

    if (in_global_destruction()) {
       unless ($ENV{'HARNESS_ACTIVE'}) {
            warn "Too late to safely run transaction-batch scrips!"
                ." This is typically caused by using objects"
                ." at the top-level of a script which uses the RT API."
               ." Be sure to explicitly undef such objects,"
                ." or put them inside of a lexical scope.";
        }
        return;
    }

    return $self->ApplyTransactionBatch;
}

RT::Base->_ImportOverlays();

1;
