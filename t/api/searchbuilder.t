
use strict;
use warnings;
use RT;
use RT::Test tests => 19;


{

ok (require RT::SearchBuilder);


}

{

use_ok('RT::Queues');
ok(my $queues = RT::Queues->new(RT->SystemUser), 'Created a queues object');
ok( $queues->UnLimit(),'Unlimited the result set of the queues object');
my $items = $queues->ItemsArrayRef();
my @items = @{$items};

ok($queues->RecordClass->_Accessible('Name','read'));
my @sorted = sort {lc($a->Name) cmp lc($b->Name)} @items;
ok (@sorted, "We have an array of queues, sorted". join(',',map {$_->Name} @sorted));

ok (@items, "We have an array of queues, raw". join(',',map {$_->Name} @items));
my @sorted_ids = map {$_->id } @sorted;
my @items_ids = map {$_->id } @items;

is ($#sorted, $#items);
is ($sorted[0]->Name, $items[0]->Name);
is ($sorted[-1]->Name, $items[-1]->Name);
is_deeply(\@items_ids, \@sorted_ids, "ItemsArrayRef sorts alphabetically by name");



}

#20767: CleanSlate doesn't clear RT::SearchBuilder's flags for handling Disabled columns
{
  my $items;

  ok(my $queues = RT::Queues->new(RT->SystemUser), 'Created a queues object');
  ok( $queues->UnLimit(),'Unlimited the result set of the queues object');

  # sanity check
  is( $queues->{'handled_disabled_column'} => undef, 'handled_disabled_column IS NOT set' );
  is( $queues->{'find_disabled_rows'}      => undef, 'find_disabled_rows IS NOT set ' );

  $queues->LimitToDeleted;

  # sanity check
  ok( $queues->{'handled_disabled_column'}, 'handled_disabled_column IS set' );
  ok( $queues->{'find_disabled_rows'},      'find_disabled_rows IS set ' );

  $queues->CleanSlate;

  # these fail without the overloaded CleanSlate method
  is( $queues->{'handled_disabled_column'} => undef, 'handled_disabled_column IS NOT set' );
  is( $queues->{'find_disabled_rows'}      => undef, 'find_disabled_rows IS NOT set ' );
}

