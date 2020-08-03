use strict;
use warnings;

use RT::Test nodb => 1, tests => undef;

my $html = <<'EOF';
<html>
  <head>
    <title>Test HTML</title>
  </head>
  <body>
  <p>This is a top-level paragraph.</p>
  <blockquote>
    <p>This is a first-level quoted paragraph</p>
    <blockquote>
      <p>This is a second-level quoted paragraph</p>
      <p>So is this</p>
    </blockquote>
    <p>Back to first-level</p>
  </blockquote>
  <p>Back to top-level</p>
  </body>
</html>
EOF

my $expected = <<'EOF';
This is a top-level paragraph.

> This is a first-level quoted paragraph

>> This is a second-level quoted paragraph

>> So is this

> Back to first-level

Back to top-level
EOF

my $expected_links = <<'EOF';
This is a top-level paragraph.

> This is a first-level quoted paragraph

> This is a second-level quoted paragraph

> So is this

> Back to first-level

Back to top-level

EOF

my $expected_html2text = <<'EOF';
This is a top-level paragraph.
> This is a first-level quoted paragraph
>> This is a second-level quoted paragraph
>> So is this
> Back to first-level
Back to top-level
EOF

# Lynx messes up; no way to preserve quoting. :(
my $expected_lynx = <<'EOF';
This is a top-level paragraph.

This is a first-level quoted paragraph

This is a second-level quoted paragraph

So is this

Back to first-level

Back to top-level
EOF

sub test_conversion
{
    my ($converter, $expected) = @_;
  SKIP: {
      if ($converter ne 'core' && !RT::Test->find_executable($converter)) {
          skip "Skipping $converter: Not installed", 1;
          return;
      }
      RT->Config->Set(HTMLFormatter => $converter);
      my $text = RT::Interface::Email::ConvertHTMLToText($html);
      is($text, $expected, "Got expected HTML->text conversion using $converter");
    }
}

# Set environment variable to force creation of a new
# formatter each time.
$ENV{HARNESS_ACTIVE} = 1;

test_conversion('w3m', "$expected\n");  # w3m adds a blank line at the end
test_conversion('elinks', $expected);
test_conversion('links', $expected);
test_conversion('html2text', $expected_html2text);
test_conversion('lynx', $expected_lynx);
test_conversion('core', "Test HTML\n\n$expected\n");  # core adds title and blank line
done_testing();
1;
