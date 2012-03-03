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

is_deeply(
    [Perinci::BashComplete::_line_to_argv(
        qq{$ENV{HOME} $ENV{HOME}/ /$ENV{HOME} $ENV{HOME}x})],
    [q{~}, q{~/}, qq{/$ENV{HOME}}, qq{$ENV{HOME}x}],
    "replace \$HOME with ~"
);

is_deeply(
    [Perinci::BashComplete::_line_to_argv(
        q{"a})],
    [],
    "unclosed quotes"
);

done_testing;
