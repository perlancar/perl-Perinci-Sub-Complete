#!perl

use 5.010;
use strict;
use warnings;
#use Log::Any '$log';

use Complete::Bash qw(parse_cmdline);
use Complete::Getopt::Long;
use Monkey::Patch::Action qw(patch_package);
use Perinci::Examples qw();
use Perinci::Sub::Complete qw(complete_cli_arg);
use Perinci::Sub::Normalize qw(normalize_function_metadata);
use Test::More 0.98;

my $meta0 = normalize_function_metadata({
    v => 1.1,
    args => {
        arg1 => {schema=>"str"},
    },
});

my $meta = normalize_function_metadata(
    $Perinci::Examples::SPEC{test_completion});

# note that the way arg name and aliases are translated to option name (e.g.
# 'body_len.max' -> 'body-len-max', 'help' -> 'help-arg') should be tested in
# Perinci::Sub::Args::Argv.

test_complete(
    name        => 'arg name (no dash)',
    args        => {meta=>$meta0},
    comp_line0  => 'CMD ^',
    result      => [qw(--arg1 --help -? -h)],
);
test_complete(
    name        => 'arg name 2 (dash)',
    args        => {meta=>$meta},
    comp_line0  => 'CMD -^',
    result      => {completion=>
                        [qw(--a1 --a2 --a3 --arg0 --f0 --f1 --help --i0 --i1
                            --i2 --s1 --s1b --s2 --s3 -? -h)],
                    escmode=>'option'},
);
test_complete(
    name        => 'arg name 3 (sole completion)',
    args        => {meta=>$meta},
    comp_line0  => 'CMD --a1^',
    result      => {completion=>
                        [qw(--a1)],
                    escmode=>'option'},
);
test_complete(
    name        => 'arg name 3 (unknown option)',
    args        => {meta=>$meta},
    comp_line0  => 'CMD --foo^',
    result      => {completion=>
                        [qw()],
                    escmode=>'option'},
);

test_complete(
    name        => 'arg value (schema)',
    args        => {meta=>$meta},
    comp_line0  => 'CMD --s1 ap^',
    result      => [qw(apple apricot)],
);
test_complete(
    name        => 'arg value (spec "completion")',
    args        => {meta=>$meta},
    comp_line0  => 'CMD --s2 a^',
    result      => ["aa".."az"],
);
test_complete(
    name        => 'arg value, pos',
    args        => {meta=>$meta},
    comp_line0  => 'CMD ^',
    result      => [sort(
        qw(--a1 --a2 --a3 --arg0 --f0 --f1 --help --i0 --i1
           --i2 --s1 --s1b --s2 --s3 -? -h),
        1..99)],
);
test_complete(
    name        => 'arg value, pos + greedy',
    args        => {meta=>$meta},
    comp_line0  => 'CMD 2 ^',
    result      => [
        qw(--a1 --a2 --a3 --arg0 --f0 --f1 --help --i0 --i1
           --i2 --s1 --s1b --s2 --s3 -? -h),
        'apple', 'apricot', 'banana', 'grape', 'grapefruit', 'green grape',
        'red date', 'red grape'],
);

test_complete(
    name        => 'custom completion (option value for function arg)',
    args        => {meta=>$meta0, completion=>sub{["a"]}},
    comp_line0  => 'CMD --arg1 ^',
    result      => [qw/a/],
);
test_complete(
    name        => 'custom completion (option value for common option)',
    args        => {meta=>$meta0, common_opts=>{c1=>{getopt=>'c1=s'}},
                    completion=>sub{["a"]}},
    comp_line0  => 'CMD --c1 ^',
    result      => [qw/a/],
);
test_complete(
    name        => 'custom completion (option value, unknown option)',
    args        => {meta=>$meta0, completion=>sub{["a"]}},
    comp_line0  => 'CMD --foo ^',
    result      => [qw/--arg1 --help -? -h a/],
);
test_complete(
    name        => 'custom completion (positional cli arg with no matching function arg)',
    args        => {meta=>$meta0, completion=>sub{["a"]}},
    comp_line0  => 'CMD ^',
    result      => [qw/--arg1 --help -? -h a/],
);
test_complete(
    name        => 'custom completion (positional cli arg for non-greedy arg)',
    args        => {meta=>$meta, completion=>sub{["a"]}},
    comp_line0  => 'CMD x^',
    result      => [qw/a/],
);
test_complete(
    name        => 'custom completion (positional cli arg for greedy arg)',
    args        => {meta=>$meta, completion=>sub{["a"]}},
    comp_line0  => 'CMD x y^',
    result      => [qw/a/],
);

DONE_TESTING:
done_testing;

sub test_complete {
    my (%args) = @_;

    subtest +($args{name} // $args{comp_line0}) => sub {

        # we don't want compgl's default completion completing
        # files/users/env/etc.
        my $handle = patch_package(
            'Complete::Getopt::Long', '_default_completion', 'replace', sub{[]},
        );

        # $args{comp_line0} contains comp_line with '^' indicating where
        # comp_point should be, the caret will be stripped. this is more
        # convenient than counting comp_point manually.
        my $comp_line  = $args{comp_line0};
        defined ($comp_line) or die "BUG: comp_line0 not defined";
        my $comp_point = index($comp_line, '^');
        $comp_point >= 0 or
            die "BUG: comp_line0 should contain ^ to indicate where comp_point is";
        $comp_line =~ s/\^//;

        my ($words, $cword) = @{ parse_cmdline($comp_line, $comp_point, '=') };
        shift @$words; $cword--; # strip program name

        my $copts = {help => {getopt=>'help|h|?', handler=>sub{}}};

        my $res = complete_cli_arg(
            words=>$words, cword=>$cword, common_opts=>$copts,
            %{$args{args}});
        is_deeply($res, $args{result}, "result") or diag explain($res);

        done_testing();
    };
}
