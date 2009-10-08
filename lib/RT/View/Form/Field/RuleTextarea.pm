package RT::View::Form::Field::RuleTextarea;
use warnings;
use strict;
use Jifty::View::Declare;
use base 'Jifty::Web::Form::Field::Textarea';

sub render_widget {
	my $self = shift;
	$self->SUPER::render_widget(@_);
	$self->render_rulebuilder_launcher();
	'';
}

sub render_rulebuilder_launcher {
	Jifty->web->out('
<input type="submit" value="Edit!" onClick="RuleBuilder.load_and_edit_lambda([
    { expression: \'ticket\',
      type: \'RT::Model::Ticket\'
    },
    { expression: \'transaction\',
      type: \'RT::Model::Transaction\'
    }
], \'Bool\', this);"/>


		');


}
1;

