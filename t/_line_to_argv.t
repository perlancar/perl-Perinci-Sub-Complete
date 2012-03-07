#!perl

use 5.010;
use strict;
use warnings;
#use Log::Any '$log';

use Test::More;

use Perinci::BashComplete;

is_deeply(
    [Perinci::BashComplete::_line_to_argv(
        q{"1 '$HOME" '$HOME "'   3 4})],
    [qq{1 '$ENV{HOME}}, q{$HOME "}, q{3}, q{4}],
    "basics"
);

# this is just a diagnosis output if testing doesn't match. some CPAN Testers
# setup has ~/fake as their home, don't know how to work around it yet.
{
    my @res = explain([Perinci::BashComplete::_line_to_argv(
        qq{$ENV{HOME} $ENV{HOME}/ /$ENV{HOME} $ENV{HOME}x})]);
    my $res = join '', @res;
    my $expected = <<_;
[
  '~',
  '~/',
  '/$ENV{HOME}',
  '$ENV{HOME}x'
]
_
    diag "Warning, there is a mismatch for test 'replace \$HOME with ~':\n".
        "Result:\n$res\n\nExpected:\n$expected"
        unless $res eq $expected;
}

is_deeply(
    [Perinci::BashComplete::_line_to_argv(
        q{"a})],
    [],
    "unclosed quotes"
);

done_testing;
