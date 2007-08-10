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

package RT::Ticket;

my @LockTypes = qw(Auto Take Hard);

sub Locked {
    my $ticket = shift;
    my $lock = $ticket->FirstAttribute('RT_Lock');
    if($lock) {
        my $duration = time() - $lock->Content->{'Timestamp'};
        my $expiry = RT->Config->Get('LockExpiry');
        if($expiry) {
            unless($duration < $expiry) {
                $ticket->DeleteAttribute('RT_Lock');
                undef $lock;
            }
        }
    }
    return $lock;
}

sub Lock {
    my $ticket = shift;
    my $type = shift || 'Auto';

    if ( my $lock = $ticket->Locked() ) {
        return undef if $lock->Content->{'User'} != $ticket->CurrentUser->id;
        my $LockType = $lock->Content->{'Type'};
        my $priority;
        my $LockPriority;
        for(my $i = 0; $i < scalar @LockTypes; $i++) {
            $priority = $i if (lc $LockTypes[$i]) eq (lc $type);
            $LockPriority = $i if (lc $LockTypes[$i]) eq (lc $LockType);
        }
        return undef if $priority <= $LockPriority;
    }
    $ticket->Unlock($type);    #Remove any existing locks (because this one has greater priority)
    $ticket->SetAttribute(
        Name    => 'RT_Lock',
        Content => {
            User      => $ticket->CurrentUser->id,
            Timestamp => time(),
            Type => $type,
            Ticket => $ticket->id
        }
    );
}


sub Unlock {
    my $ticket = shift;
    my $type = shift || 'Auto';

    my $lock = $ticket->RT::Ticket::Locked();
    return (undef, "This ticket was not locked.") unless $lock;
    return (undef, "You cannot unlock a ticket locked by another user.") unless $lock->Content->{User} ==  $ticket->CurrentUser->id;
    
    my $LockType = $lock->Content->{'Type'};
    my $priority;
    my $LockPriority;
    for(my $i = 0; $i < scalar @LockTypes; $i++) {
        $priority = $i if (lc $LockTypes[$i]) eq (lc $type);
        $LockPriority = $i if (lc $LockTypes[$i]) eq (lc $LockType);
    }
    return (undef, "There is a lock with a higher priority on this ticket.") if $priority < $LockPriority;
    my $duration = time() - $lock->Content->{'Timestamp'};
    $ticket->DeleteAttribute('RT_Lock');
    return ($duration, "You have unlocked this ticket.");
}


sub BreakLock {
    my $ticket = shift;
    return $ticket->DeleteAttribute('RT_Lock');
}


