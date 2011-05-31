#!perl

use 5.010;
use strict;
use warnings;
#use Log::Any '$log';

use File::Which qw(which);
use Test::More;
use Sub::Spec::BashComplete qw(bash_complete_spec_arg);

plan skip_all => "bash is not available on this system" unless which("bash");

my $arg_complete = sub {
    my (%args) = @_;
    [qw(apple apricot cherry cranberry)];
};

my $spec = {
    args => {
        bool1 => [bool    => {}],
        bool2 => ["bool*" => {}],
        str1  => ["str*"  => {arg_complete=>$arg_complete}],
        str2  => [str     => {in=>[qw/foo bar baz str/]}],
    },
};

test_complete(
    spec        => $spec,
    comp_line   => 'CMD ',
    comp_point0 => '    ^',
    result      => [qw(--help -h -? --bool1 --nobool1 --bool2 --nobool2 --str1 --str2)],
);
test_complete(
    spec        => $spec,
    comp_line   => 'CMD -',
    comp_point0 => '     ^',
    result      => [qw(--help -h -? --bool1 --nobool1 --bool2 --nobool2 --str1 --str2)],
);
test_complete(
    spec        => $spec,
    comp_line   => 'CMD --',
    comp_point0 => '      ^',
    result      => [qw(--help --bool1 --nobool1 --bool2 --nobool2 --str1 --str2)],
);
test_complete(
    spec        => $spec,
    comp_line   => 'CMD --b',
    comp_point0 => '      ^',
    result      => [qw(--help --bool1 --nobool1 --bool2 --nobool2 --str1 --str2)],
);
test_complete(
    spec        => $spec,
    comp_line   => 'CMD --b',
    comp_point0 => '       ^',
    result      => [qw(--bool1 --bool2)],
);
test_complete(
    spec        => $spec,
    comp_line   => 'CMD --x',
    comp_point0 => '       ^',
    result      => [qw()],
);
test_complete(
    spec        => $spec,
    comp_line   => 'CMD --bool1',
    comp_point0 => '           ^',
    result      => [qw(--bool1)],
);
test_complete(
    name        => 'no longer complete mentioned arg',
    spec        => $spec,
    comp_line   => 'CMD --bool1 ',
    comp_point0 => '            ^',
    result      => [qw(--bool2 --nobool2 --str1 --str2)],
);
test_complete(
    name        => 'complete arg value',
    spec        => $spec,
    comp_line   => 'CMD --bool1 --str2 ',
    comp_point0 => '                   ^',
    result      => [qw(foo bar baz str)],
);
test_complete(
    name        => 'complete arg name instead of value when user type -',
    spec        => $spec,
    comp_line   => 'CMD --bool1 --str2 -',
    comp_point0 => '                    ^',
    result      => [qw(--bool2 --nobool2 --str1 --str2)],
);
test_complete(
    name        => 'complete arg value (spec "in")',
    spec        => $spec,
    comp_line   => 'CMD --bool1 --str2 ba',
    comp_point0 => '                     ^',
    result      => [qw(bar baz)],
);
test_complete(
    name        => 'complete arg value (spec "arg_complete")',
    spec        => $spec,
    comp_line   => 'CMD --str1 ',
    comp_point0 => '           ^',
    result      => [qw(apple apricot cherry cranberry)],
);
test_complete(
    name        => 'complete arg value (spec "arg_complete")',
    spec        => $spec,
    comp_line   => 'CMD --str1 app',
    comp_point0 => '             ^',
    result      => [qw(apple apricot)],
);
test_complete(
    name        => 'complete arg value (spec "arg_complete")',
    spec        => $spec,
    comp_line   => 'CMD --str1 apx',
    comp_point0 => '              ^',
    result      => [qw()],
);
test_complete(
    name        => 'complete arg value (opts "arg_sub")',
    spec        => $spec,
    opts        => {arg_sub=>{str1=>sub {qw(a b c)}}},
    comp_line   => 'CMD --str1 ',
    comp_point0 => '           ^',
    result      => [qw(a b c)],
);
test_complete(
    name        => 'complete arg value (opts "arg_sub", not found)',
    spec        => $spec,
    opts        => {arg_sub=>{str2=>sub {qw(a b c)}}},
    comp_line   => 'CMD --str1 ',
    comp_point0 => '           ^',
    result      => [qw(apple apricot cherry cranberry)],
);
test_complete(
    name        => 'complete arg value (opts "args_sub")',
    spec        => $spec,
    opts        => {args_sub=>sub {qw(a b c)}},
    comp_line   => 'CMD --str1 ',
    comp_point0 => '           ^',
    result      => [qw(a b c)],
);

my $spec2 = {
    args => {
        str1  => ["str*"  => {arg_pos=>0, in=>[qw/a b c d/]}],
        str2  => [str     => {arg_pos=>1, in=>[qw/e f g h/]}],
        str3  => [str     => {arg_pos=>2, in=>[qw/i j k l/]}],
    },
};
test_complete(
    name        => 'complete arg value, arg_pos (1)',
    spec        => $spec2,
    comp_line   => 'CMD ',
    comp_point0 => '    ^',
    result      => [qw(a b c d)],
);
test_complete(
    name        => 'complete arg value, arg_pos (1b)',
    spec        => $spec2,
    comp_line   => 'CMD a',
    comp_point0 => '     ^',
    result      => [qw(a)],
);
test_complete(
    name        => 'complete arg value, arg_pos (2)',
    spec        => $spec2,
    comp_line   => 'CMD a ',
    comp_point0 => '      ^',
    result      => [qw(e f g h)],
);
test_complete(
    name        => 'complete arg value, arg_pos (2b)',
    spec        => $spec2,
    comp_line   => 'CMD a f',
    comp_point0 => '       ^',
    result      => [qw(f)],
);
test_complete(
    name        => 'complete arg value, arg_pos (3)',
    spec        => $spec2,
    comp_line   => 'CMD a e ',
    comp_point0 => '        ^',
    result      => [qw(i j k l)],
);
test_complete(
    name        => 'complete arg value, arg_pos (3b)',
    spec        => $spec2,
    comp_line   => 'CMD a e j',
    comp_point0 => '         ^',
    result      => [qw(j)],
);
test_complete(
    name        => 'complete arg value, arg_pos mixed with --opt',
    spec        => $spec2,
    comp_line   => 'CMD a e -',
    comp_point0 => '         ^',
    result      => [qw(--str3)],
);

test_complete(
    name        => 'custom_completer (decline)',
    spec        => $spec2,
    opts        => {custom_completer=>sub {return [undef] }},
    comp_line   => 'CMD a e -',
    comp_point0 => '         ^',
    result      => [qw(--str3)],
);
test_complete(
    name        => 'custom_completer',
    spec        => $spec2,
    opts        => {custom_completer=>sub {return ["-a", "-b"]}},
    comp_line   => 'CMD a e -',
    comp_point0 => '         ^',
    result      => [qw(-a -b)],
);

# XXX test ENV
# XXX test fallback arg value to file
done_testing();

sub test_complete {
    my (%args) = @_;
    #$log->tracef("args=%s", \%args);

    my $line  = $args{comp_line};
    my $point = index($args{comp_point0}, '^');

    my $name = $args{name} // "";
    my $name2 = $line;
    substr($name2, $point, $point) = '^';
    if ($name) {
        $name = "$name (q($name2))";
    } else {
        $name = "q($name2)";
    }

    # XXX test supplying via opts->{words} & opts->{cword}
    local $ENV{COMP_LINE}  = $line;
    local $ENV{COMP_POINT} = $point;

    my @res = bash_complete_spec_arg($args{spec}, $args{opts});
    is_deeply(\@res, $args{result}, "$name (result)") or explain(\@res);
}

