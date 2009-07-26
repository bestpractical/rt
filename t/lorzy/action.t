use Test::More tests => 7;
use RT::Test;

use strict;
use warnings;

use RT::Model::Queue;
use RT::Model::User;
use RT::Model::Group;
use RT::Model::Ticket;
use RT::Model::ACE;
use RT::CurrentUser;
use Test::Exception;
use RT::Test::Email;

use_ok('RT::Lorzy');
use_ok('LCore');
use_ok('LCore::Level2');
my $l = $RT::Lorzy::LCORE;


my $on_created_lcore = q{
(lambda (ticket transaction)
  (Str.Eq (Native.Invoke transaction "type") "create"))
};
#my $on_created_lcore2 = $l->analze_it("RT.Condition.OnCreate")
    # my $lcore_code = "(RT.Condition.$lorzy_cond ticket transaction)"

#my $auto_reply_lcore = $l->analyze_it(q{(quote (RT.RuleAction.SendEmail (to . ## $self->ticket_obj->role_group("requestor")->member_emails )))});
# (lambda (ticket :RT::Model::Ticket transaction :RT::Model::Transaction context :HASH)
my $auto_reply_lcore = q{
(lambda (ticket transaction context)
  (RT.RuleAction.Run
        (("name"        . "Autoreply To requestors")
         ("template"    . "Autoreply")
         ("context"     . context)
         ("ticket"      . ticket)
         ("transaction" . transaction))))
};

RT::Lorzy::Dispatcher->reset_rules;
#
my $rule = RT::Model::Rule->new( current_user => RT->system_user );
$rule->create( condition_code => $on_created_lcore,
               action_code    => $auto_reply_lcore );

my $queue = RT::Model::Queue->new(current_user => RT->system_user);
my ($queue_id) = $queue->create( name =>  'lorzy');
ok( $queue_id, 'queue created' );

my $ticket = RT::Model::Ticket->new(current_user => RT->system_user );
mail_ok {
lives_ok {
my ($rv, $msg) = $ticket->create( subject => 'lorzy test', queue => $queue->name, requestor => 'foo@localhost' );
};
} { from => qr/lorzy via RT/,
    to => 'foo@localhost',
    subject => qr'AutoReply: lorzy test',
    body => qr/automatically generated/,
};

# Global destruction issues
undef $ticket;
