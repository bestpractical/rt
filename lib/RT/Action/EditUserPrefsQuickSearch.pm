use strict;
use warnings;

package RT::Action::EditUserPrefsQuickSearch;
use base qw/RT::Action::EditUserPrefs/;

sub name {
    return 'QuickSearch';
}

use Jifty::Param::Schema;
use Jifty::Action schema {
    param
      'queues' =>
      label is _('Select queues to be displayed on the "RT at a glance" page'),
      render as 'Checkboxes',
      available are defer {
        my $qs = __PACKAGE__->queues;
        return [
            map {
                { display => $_->description || $_->name, value => $_->name }
              } __PACKAGE__->queues
        ];
      },
      default is defer {
        my $unwanted = __PACKAGE__->user->preferences( __PACKAGE__->name, {} );
        return [
            map  { $_->name }
            grep { !$unwanted->{ $_->name } } __PACKAGE__->queues
        ];
      };
};

sub take_action {
    my $self = shift;
    my $wants = $self->argument_value('queues') || [];
    my %wants = map { $_ => 1 } ref $wants eq 'ARRAY' ? @$wants : $wants;
    my %unwanted =
      map { $_ => 1 } grep { !$wants{$_} } map { $_->name } $self->queues;
    my ( $status, $msg ) =
      $self->user->set_preferences( $self->name, \%unwanted );
    Jifty->log->error($msg) unless $status;

    # Let QueueSummary rebuild the cache
    Jifty->web->session->remove('quick_search_queues');
    $self->report_success;
    return 1;
}

sub queues {
    my $self   = shift;
    my $queues = RT::Model::QueueCollection->new;
    $queues->find_all_rows;
    return
      grep { $_->current_user_has_right('ShowTicket') }
      @{ $queues->items_array_ref };
}

1;
