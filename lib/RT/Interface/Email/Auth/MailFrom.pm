package RT::Interface::Email::Auth::MailFrom;
use RT::Interface::Email qw(ParseSenderAddressFromHead CreateUser);

# This is what the ordinary, non-enhanced gateway does at the moment.

sub GetCurrentUser {
    my ($Item, $CurrentUser, $PrivStat) = @_;

    # We don't need to do any external lookups
    my ($Address, $Name) = ParseSenderAddressFromHead($Item->head);
    my $CurrentUser = RT::CurrentUser->new();
    $CurrentUser->LoadByEmail($Address);

    unless ($CurrentUser->Id) {
        $CurrentUser->LoadByName($Address);
    }

    # If still no joy, better make one
    unless ($CurrentUser->Id) {
        $CurrentUser = CreateUser(undef, $Address, $Name, $Item);
    }
    
    return ($CurrentUser, 1);
}

1;
