use strict;
use warnings;
use RT::Test tests => undef;

my ( $url, $m ) = RT::Test->started_ok;
ok( $m->login(), 'logged in' );

$m->follow_link_ok({text => 'About me'});
$m->submit_form_ok({ with_fields => { Lang => 'ja'} },
               "Change to Japanese");
$m->text_contains(Encode::decode("UTF-8","Langは「(値なし)」から「'ja'」に変更されました"));
$m->text_contains(Encode::decode("UTF-8","実名"), "Page content is japanese");

# we only changed one field, and it wasn't the default, so this feedback is
# spurious and annoying
$m->content_lacks("That is already the current value");

# change back to English
$m->submit_form_ok({ with_fields => { Lang => 'en_us'} },
               "Change back to english");

$m->text_contains("Lang changed from 'ja' to 'en_us'");
$m->text_contains("Real Name", "Page content is english");

# Check for a lack of spurious updates
$m->content_lacks("That is already the current value");

# Ensure that we can change the language back to the default.
$m->submit_form_ok({ with_fields => { Lang => 'ja'} },
                   "Back briefly to Japanese");
$m->text_contains(Encode::decode("UTF-8","Langは「'en_us'」から「'ja'」に変更されました"));
$m->text_contains(Encode::decode("UTF-8","実名"), "Page content is japanese");
$m->submit_form_ok({ with_fields => { Lang => ''} },
                   "And set to the default");
$m->text_contains("Lang changed from 'ja' to (no value)");
$m->text_contains("Real Name", "Page content is english");

diag('Testing Timezone');
{
    my $form = $m->form_with_fields('Timezone');
    ok( $form, 'found form with Timezone field' );
    my $input = $form->find_input('Timezone');
    ok( $input, 'Timezone select is on the page' );

    my @options = $input->possible_values;
    ok( scalar @options > 300,                          'Timezone select has 300+ options' );
    ok( ( grep { $_ eq 'UTC' } @options ),              'UTC is an option' );
    ok( ( grep { $_ eq 'America/New_York' } @options ), 'America/New_York is an option' );
    ok( ( grep { $_ eq 'Asia/Shanghai' } @options ),    'Asia/Shanghai is an option' );

    # Labels should include UTC offset in +HHMM format
    my @labels = $input->value_names;
    my %label_for;
    @label_for{@options} = @labels;
    is( $label_for{'UTC'}, 'UTC +0000', 'UTC label shows +0000' );
    like(
        $label_for{'America/New_York'},
        qr/America\/New_York -0[45]00$/,
        'America/New_York label shows -0400 or -0500'
    );
    is( $label_for{'Asia/Shanghai'}, 'Asia/Shanghai +0800', 'Asia/Shanghai label shows +0800' );

    $m->submit_form_ok( { with_fields => { Timezone => 'America/Chicago' } }, 'Set timezone to America/Chicago' );
    $m->text_contains( 'Timezone changed', 'Timezone change confirmed' );

    $m->submit_form_ok( { with_fields => { Timezone => '' } }, 'Reset timezone to system default' );
    $m->text_contains( 'Timezone changed', 'Timezone reset confirmed' );
}

done_testing;
