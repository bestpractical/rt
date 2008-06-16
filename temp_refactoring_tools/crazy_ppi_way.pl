
use strict;
use warnings;
use PPI::Document;
use PPI::Dumper;

while ( my $f = shift ) {
    print "processing $f\n";

    my $doc  = PPI::Document->new($f);
    my $subs = $doc->find('PPI::Statement::Sub');
    if ( $subs && @$subs ) {
        process_sub_args($_) foreach @$subs;
        $doc->save($f);
        $doc = PPI::Document->new($f);
    } else {
        print "no subs found in the file\n";
    }

    process_calls($doc);
    $doc->save($f);
}

sub process_calls {
    my $doc = shift;

    #    dumpe($doc);
    my $method_calls = $doc->find(
        sub {
            return 0 unless $_[1]->isa('PPI::Token::Operator') && $_[1] eq '->';
            my $sib = $_[1]->next_sibling;
            return 0 unless $sib && $sib->isa('PPI::Token::Word');
            $sib = $sib->next_sibling;
            return 0 unless $sib && $sib->isa('PPI::Structure::List');
        }
    );
    unless ( $method_calls && @$method_calls ) {
        print "no method calls\n";
        return;
    }
    foreach my $call (@$method_calls) {
        print 'call to ' . $call->next_sibling->literal . "\n";
        my $list = $call->next_sibling->next_sibling;
        next unless $list->find_first('PPI::Statement::Expression');
        foreach my $word ( grep $_->isa('PPI::Token::Word'), $list->find_first('PPI::Statement::Expression')->schildren ) {
            my $sib = $word->snext_sibling;
            next
                unless $sib
                    && $sib->isa('PPI::Token::Operator')
                    && $sib eq '=>';
            next unless $word->literal =~ /[A-Z][a-z]/;
            $word->set_content( low_api( $word->literal ) );

            #            dumpe($word);
        }
    }

    #    dumpe($_->statement) foreach @$method_calls;
}

sub process_sub_args {
    my $sub = shift;

    #    return unless $sub->name eq 'set_from_config';
    print $sub->name . "\n";
    my $block    = $sub->block;
    my @children = $block->schildren;
    foreach my $child (@children) {
        if ( $child->isa('PPI::Statement::Variable') ) {
            next unless $child->type eq 'my';
            my @vars = $child->variables;
            if ( @vars == 1 && $vars[0] eq '%args' ) {
                process_args( $block, $child );
            }
        } else {
            last;
        }
    }
}

sub process_args {
    my ( $sub_block, $args ) = @_;
    my ( $type, $name, $operator, $list ) = $args->schildren;
    unless ( $list && $list->isa('PPI::Structure::List') ) {
        print "is not a list\n";
        return;
    }
    my $expr = $list->find_first('PPI::Statement::Expression');
    unless ($expr) {
        print "couldn't find expression";
        return;
    }
    my @tokens = $expr->tokens;
    my $state  = '';
    my @names;
    while ( my $token = shift @tokens ) {
        next if $token->isa('PPI::Token::Whitespace');
        dumpe($token);
        unless ($state) {
            unless ( $token->isa('PPI::Token::Word') ) {
                if ( $token->isa('PPI::Token::Magic') && $token eq '@_' ) {
                    last;
                }
                print ref($token) . " is not a word, lost\n";
                return;
            }
            if ( $token =~ /[A-Z][a-z]/ ) {
                push @names, $token;
            }
            $state = 'op';
        } elsif ( $state eq 'op' ) {
            if ( $token->isa('PPI::Token::Operator') ) {
                if ( $token eq '=>' ) {
                    $state = 'val';
                } elsif ( $token eq ',' ) {
                    $state = '';
                } else {
                    print ref($token) . " is not a => or ',', lost\n";
                    return;
                }
            } else {
                print ref($token) . " is not an op, lost\n";
            }
        } elsif ( $state eq 'val' ) {
            $state = 'op';
        }
    }
    return unless @names;

    my %convs;
    foreach my $name (@names) {
        $convs{"$name"} = low_api("$name");
        $name->set_content( $convs{"$name"} );
    }
    my $usages = $sub_block->find(
        sub {
            return 0
                unless $_[1]->isa('PPI::Token::Symbol') && $_[1] eq '$args';
            my $sib = $_[1]->next_sibling;
            return 0 unless $sib->isa('PPI::Structure::Subscript');
            return 1;
        }
    );
    unless ( $usages && @$usages ) {
        print "no usages found\n";
        return;
    }
    foreach my $u (@$usages) {
        my $subscript = $u->next_sibling;
        my $quotes    = $subscript->find(
            sub {
                return 1 if $_[1]->isa('PPI::Token::Quote');
                return 0;
            }
        );
        if ( !$quotes || @$quotes != 1 ) {
            print "no quoted string or more then one\n";
            next;
        }
        my $replacement = $convs{ $quotes->[0]->string };
        unless ($replacement) {
            if ( $quotes->[0]->string =~ /[A-Z][a-z]/ ) {
                print "WARNING!!! potential bug\n";
                $replacement = low_api( $quotes->[0]->string );
            } else {
                next;
            }
        }
        $quotes->[0]->set_content( "'" . $replacement . "'" );
    }
}

sub low_api {
    my $v = shift;
    $v =~ s/(?<=[a-z])(?=[A-Z])/_/g;
    return lc $v;
}

sub dumpe {
    PPI::Dumper->new(shift)->print;
}

