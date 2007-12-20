
use strict;
use warnings;
use RT::Test; use Test::More; 
plan tests => 11;
use RT;



{

ok (require RT::SearchBuilder);


}

{

use_ok('RT::Model::QueueCollection');
ok(my $queues = RT::Model::QueueCollection->new(current_user => RT->system_user), 'Created a queues object');
ok( $queues->find_all_rows(),'unlimited the result set of the queues object');
my $items = $queues->items_array_ref();
my @items = @{$items};

ok($queues->new_item->can('name'));
my @sorted = sort {lc($a->name) cmp lc($b->name)} @items;
ok (@sorted, "We have an array of queues, sorted". join(',',map {$_->name} @sorted));

ok (@items, "We have an array of queues, raw". join(',',map {$_->name} @items));
my @sorted_ids = map {$_->id } @sorted;
my @items_ids = map {$_->id } @items;

is ($#sorted, $#items);
is ($sorted[0]->name, $items[0]->name);
is ($sorted[-1]->name, $items[-1]->name);
is_deeply(\@items_ids, \@sorted_ids, "items_array_ref sorts alphabetically by name");;



}

1;
