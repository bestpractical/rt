use strict;
use warnings;

use RT::Test tests => undef;
use RT::Interface::Web;

#my ($baseurl,$m) = RT::Test->started_ok;

# ok $m->login, 'logged in';

use Data::Dumper;

diag "ParseObjectCustomFieldArgs";
{
    my %test1;
    my %test2;
    my %test3;

    my @values = qw( a b c d e f );

    my @ObjectCustomFields = qw( 
        Object-RT::Wicket-44-CustomField:Grouping-123-Snarf
        Object-RT::Wicket-45-CustomField:Grouping-456-Frobnicate
        Object-RT::Ticket-46-CustomField-789-Shizzle
    );

    my @BulkCustomFields = qw( 
        Bulk-Add-CustomField:Grouping-123-Snarf
        Bulk-Delete-CustomField:Grouping-456-Frobnicate
        Bulk-Add-CustomField-789-Shizzle
    );

    # structure returned
    my $test1Values = {
        'RT::Ticket' => { '46' => { '789' => { '' => { 'Shizzle' => 'c' } } } },
        'RT::Wicket' => {
            '45' => { '456' => { 'Grouping' => { 'Frobnicate' => 'b' } } },
            '44' => { '123' => { 'Grouping' => { 'Snarf' => 'a' } } } }
    };

    my $test2Values = {
        '' => {
            '0' => {
                '123' => { 'Grouping' => { 'Snarf' => 'd' } },
                '789' => { '' => { 'Shizzle' => 'f' } },
                '456' => { 'Grouping' => { 'Frobnicate' => 'e' } } 
            } 
        }
    };

    # assemble the union of the two prior test sets
    my $test3Values = { %$test2Values, %$test1Values };

    @test1{@ObjectCustomFields} = @values[0..2];
    @test2{@BulkCustomFields} = @values[3 .. $#values ];
    @test3{@ObjectCustomFields,@BulkCustomFields} = @values;

    # parse Object w/o IncludeBulkUpdate
    my $ref1 = HTML::Mason::Commands::_ParseObjectCustomFieldArgs( \%test1 );
    is_deeply $ref1, $test1Values, 'Object CustomField parsing';

    # parse Bulk w/o IncludeBulkUpdate
    my $ref2 = HTML::Mason::Commands::_ParseObjectCustomFieldArgs( \%test2 );
    is_deeply $ref2, {}, 'ObjectCustomField paring with no Object- fields';

    # parse only Bulk Fields w/ IncludeBulkupdate
    $ref2 = HTML::Mason::Commands::_ParseObjectCustomFieldArgs( \%test2, IncludeBulkUpdate => 1  );
    is_deeply $ref2, $test2Values, 'Bulk CustomField parsing';

    # include both Object and Bulk CustomField args
    my $ref3 = HTML::Mason::Commands::_ParseObjectCustomFieldArgs( \%test3, IncludeBulkUpdate => 1 );
    is_deeply $ref3, $test3Values, 'Object and Bulk CustomField parsing';

    
}

done_testing;
