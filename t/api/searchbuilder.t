
use strict;
use warnings;
use Test::More; 
plan tests => 11;
use RT;
use RT::Test;


{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;

ok (require RT::SearchBuilder);


    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}

{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;

use_ok('RT::Model::QueueCollection');
ok(my $queues = RT::Model::QueueCollection->new($RT::SystemUser), 'Created a queues object');
ok( $queues->find_all_rows(),'unlimited the result set of the queues object');
my $items = $queues->items_array_ref();
my @items = @{$items};

ok($queues->new_item->can('Name'));
my @sorted = sort {lc($a->Name) cmp lc($b->Name)} @items;
ok (@sorted, "We have an array of queues, sorted". join(',',map {$_->Name} @sorted));

ok (@items, "We have an array of queues, raw". join(',',map {$_->Name} @items));
my @sorted_ids = map {$_->id } @sorted;
my @items_ids = map {$_->id } @items;

is ($#sorted, $#items);
is ($sorted[0]->Name, $items[0]->Name);
is ($sorted[-1]->Name, $items[-1]->Name);
is_deeply(\@items_ids, \@sorted_ids, "items_array_ref sorts alphabetically by name");;



    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}

1;
