#!perl

use 5.010;
use strict;
use warnings;
#use Log::Any '$log';

use File::Which qw(which);
use Perinci::Sub::Complete qw(shell_complete_arg);
use Test::More 0.98;

plan skip_all => "bash is not available on this system" unless which("bash");

my $meta = _normalize_meta({
    v => 1.1,
    args => {
        bool1 => {
            schema=>'bool',
        },
        bool2 => {
            schema=>'bool*',
            req => 1,
        },
        str1  => {
            schema => ["str*" => {}],
            completion => sub {
                my (%args) = @_;
                [qw(apple apricot cherry cranberry)];
            }
        },
        str2  => {
            schema => [str => {
                in=>[qw/foo bar baz str/],
            }],
        },
    },
});

test_complete(
    name        => 'complete arg name',
    args        => {meta=>$meta},
    comp_line   => 'CMD ',
    comp_point0 => '    ^',
    result      => [qw(--bool1 --bool2 --help --nobool1 --nobool2
                       --str1 --str2 -? -h)],
);
test_complete(
    name        => 'complete arg name 2',
    args        => {meta=>$meta},
    comp_line   => 'CMD -',
    comp_point0 => '     ^',
    result      => [qw(--bool1 --bool2 --help --nobool1 --nobool2
                       --str1 --str2 -? -h)],
);
test_complete(
    name        => 'complete arg name 3',
    args        => {meta=>$meta},
    comp_line   => 'CMD --',
    comp_point0 => '      ^',
    result      => [qw(--bool1 --bool2 --help --nobool1 --nobool2
                       --str1 --str2)],
);
test_complete(
    name        => 'complete arg name 4',
    args        => {meta=>$meta},
    comp_line   => 'CMD --b',
    comp_point0 => '      ^',
    result      => [qw(--bool1 --bool2 --help --nobool1 --nobool2
                       --str1 --str2)],
);
test_complete(
    name        => 'complete arg name 5',
    args        => {meta=>$meta},
    comp_line   => 'CMD --b',
    comp_point0 => '       ^',
    result      => [qw(--bool1 --bool2)],
);
test_complete(
    name        => 'complete arg name 6',
    args        => {meta=>$meta},
    comp_line   => 'CMD --x',
    comp_point0 => '       ^',
    result      => [qw()],
);
test_complete(
    name        => 'complete arg name 7',
    args        => {meta=>$meta},
    comp_line   => 'CMD --bool1',
    comp_point0 => '           ^',
    result      => [qw(--bool1)],
);
test_complete(
    name        => 'no longer complete mentioned arg',
    args        => {meta=>$meta},
    comp_line   => 'CMD --bool1 ',
    comp_point0 => '            ^',
    result      => [qw(--bool2 --help --nobool2 --str1 --str2 -? -h)],
);
test_complete(
    name        => 'no longer complete mentioned arg (2)',
    args        => {meta=>$meta},
    comp_line   => 'CMD --nobool1 ',
    comp_point0 => '              ^',
    result      => [qw(--bool2 --help --nobool2 --str1 --str2 -? -h)],
);
test_complete(
    name        => 'no longer complete mentioned arg (3)',
    args        => {meta=>$meta},
    comp_line   => 'CMD --str1 1 --nobool1 ',
    comp_point0 => '                       ^',
    result      => [qw(--bool2 --help --nobool2 --str2 -? -h)],
);
test_complete(
    name        => 'no longer complete mentioned common opts',
    args        => {meta=>$meta},
    comp_line   => 'CMD --bool1 --nobool2 --help ',
    comp_point0 => '                             ^',
    result      => [qw(--str1 --str2)],
);
test_complete(
    name        => 'no longer complete mentioned common opts (2)',
    args        => {meta=>$meta},
    comp_line   => 'CMD --bool1 --nobool2 -h ',
    comp_point0 => '                         ^',
    result      => [qw(--str1 --str2)],
);
test_complete(
    name        => 'complete arg value',
    args        => {meta=>$meta},
    comp_line   => 'CMD --bool1 --str2 ',
    comp_point0 => '                   ^',
    result      => [qw(bar baz foo str)],
);
test_complete(
    name        => 'complete arg value (2)',
    args        => {meta=>$meta},
    comp_line   => 'CMD --bool1 --str2=f',
    comp_point0 => '                    ^',
    result      => [qw(foo)],
);
test_complete(
    name        => 'complete arg name instead of value when user type -',
    args        => {meta=>$meta},
    comp_line   => 'CMD --bool1 -',
    comp_point0 => '             ^',
    result      => [qw(--bool2 --help --nobool2 --str1 --str2 -? -h)],
);
test_complete(
    name        => 'complete arg value (spec "in")',
    args        => {meta=>$meta},
    comp_line   => 'CMD --bool1 --str2 ba',
    comp_point0 => '                     ^',
    result      => [qw(bar baz)],
);
test_complete(
    name        => 'complete arg value (spec "completion")',
    args        => {meta=>$meta},
    comp_line   => 'CMD --str1 ',
    comp_point0 => '           ^',
    result      => [qw(apple apricot cherry cranberry)],
);
test_complete(
    name        => 'complete arg value (spec "completion") (2)',
    args        => {meta=>$meta},
    comp_line   => 'CMD --str1 app',
    comp_point0 => '             ^',
    result      => [qw(apple apricot)],
);
test_complete(
    name        => 'complete arg value (spec "completion") (3)',
    args        => {meta=>$meta},
    comp_line   => 'CMD --str1 apx',
    comp_point0 => '              ^',
    result      => [qw()],
);
test_complete(
    name        => 'complete arg value (arg "custom_arg_completer" HoCode)',
    args        => {meta=>$meta,
                    custom_arg_completer => {str1=>sub {[qw/a b c/]}}},
    comp_line   => 'CMD --str1 ',
    comp_point0 => '           ^',
    result      => [qw(a b c)],
);
test_complete(
    name        => 'complete arg value (arg "custom_arg_completer" HoCode,'.
        ' no match)',
    args        => {meta=>$meta,
                    custom_arg_completer => {str2=>sub {[qw(a b c)]}}},
    comp_line   => 'CMD --str1 ',
    comp_point0 => '           ^',
    result      => [qw(apple apricot cherry cranberry)],
);
test_complete(
    name        => 'complete arg value (opts "custom_arg_completer" code)',
    args        => {meta=>$meta,
                    custom_arg_completer => sub {[qw(a b c)]}},
    comp_line   => 'CMD --str1 ',
    comp_point0 => '           ^',
    result      => [qw(a b c)],
);

my $meta2 = _normalize_meta({
    v => 1.1,
    args => {
        str1  => {
            schema => ["str*" => {}],
            completion=>sub{[qw/a b c d/]},
            pos => 0,
        },
        str2  => {
            schema => ['str' => {in=>[qw/e f g h/]}],
            pos => 1,
        },
        str3  => {
            schema => [str => {in=>[qw/i j k l/]}],
            pos => 2,
        },
    },
});

test_complete(
    name        => 'complete arg value, pos (1)',
    args        => {meta=>$meta2},
    comp_line   => 'CMD ',
    comp_point0 => '    ^',
    result      => [qw(a b c d)],
);
test_complete(
    name        => 'complete arg value, arg_pos (1b)',
    args        => {meta=>$meta2},
    comp_line   => 'CMD a',
    comp_point0 => '     ^',
    result      => [qw(a)],
);
test_complete(
    name        => 'complete arg value, arg_pos (2)',
    args        => {meta=>$meta2},
    comp_line   => 'CMD a ',
    comp_point0 => '      ^',
    result      => [qw(e f g h)],
);
test_complete(
    name        => 'complete arg value, arg_pos (2b)',
    args        => {meta=>$meta2},
    comp_line   => 'CMD a f',
    comp_point0 => '       ^',
    result      => [qw(f)],
);
test_complete(
    name        => 'complete arg value, arg_pos (3)',
    args        => {meta=>$meta2},
    comp_line   => 'CMD a e ',
    comp_point0 => '        ^',
    result      => [qw(i j k l)],
);
test_complete(
    name        => 'complete arg value, arg_pos (3b)',
    args        => {meta=>$meta2},
    comp_line   => 'CMD a e j',
    comp_point0 => '         ^',
    result      => [qw(j)],
);
test_complete(
    name        => 'complete arg value, arg_pos mixed with --opt',
    args        => {meta=>$meta2},
    comp_line   => 'CMD a e -',
    comp_point0 => '         ^',
    result      => [qw(--help --str3 -? -h)],
);

test_complete(
    name        => 'custom_completer (decline)',
    args        => {meta=>$meta2,
                    custom_completer=>sub {return undef}},
    comp_line   => 'CMD a e -',
    comp_point0 => '         ^',
    result      => [qw(--help --str3 -? -h)],
);
test_complete(
    name        => 'custom_completer',
    args        => {meta=>$meta2,
                    custom_completer=>sub {return ["-a", "-b"]}},
    comp_line   => 'CMD a e -',
    comp_point0 => '         ^',
    result      => [qw(-a -b)],
);


my $meta3 = _normalize_meta({
    v => 1.1,
    args => {
        b  => {schema => "bool",
               cmdline_aliases => {alias1=>{}}},
        b2 => {schema => "bool"},
        b3 => {schema => ["bool"=>{is=>1}],
               cmdline_aliases => {X=>{}}},
        s  => {schema => "str"},
        s2 => {schema => ["str"],
               cmdline_aliases => {S=>{}, S2=>{schema=>['bool'=>{is=>1}]}}},
    },
});

test_complete(
    name        => 'complete arg name (bool, one-letter, cmdline_aliases)',
    args        => {meta=>$meta3},
    comp_line   => 'CMD ',
    comp_point0 => '    ^',
    result      => [qw(--S2 --alias1 --b2 --b3 --help --noalias1 --nob2 --s2
                       -? -S -X -b -h -s)],
);

my $meta4 = _normalize_meta({
    v => 1.1,
    args => {
        foo_bar   => {schema => "str"},
        "foo.baz" => {schema => "str"},
    },
});

test_complete(
    name        => 'special argument names',
    args        => {meta=>$meta4},
    comp_line   => 'CMD --f',
    comp_point0 => '       ^',
    result      => [qw(--foo-bar --foo-baz)],
);

my $meta5 = _normalize_meta({
    v => 1.1,
    args => {},
    features => {dry_run=>1},
});

test_complete(
    name        => 'special option: dry-run',
    args        => {meta=>$meta5},
    comp_line   => 'CMD --d',
    comp_point0 => '       ^',
    result      => [qw(--dry-run)],
);

subtest "complete element value (using schema)" => sub {
    my $meta = _normalize_meta({
        v => 1.1,
        args => {
            arg => {
                schema => ["array*" => of => [str => in => [qw/a aa b c/]]],
                pos    => 0,
                greedy => 1,
            },
        },
    });
    test_complete(
        args        => {meta=>$meta},
        comp_line   => 'CMD ',
        comp_point0 => '    ^',
        result      => [qw(a aa b c)],
    );
    test_complete(
        args        => {meta=>$meta},
        comp_line   => 'CMD a',
        comp_point0 => '     ^',
        result      => [qw(a aa)],
    );
    test_complete(
        args        => {meta=>$meta},
        comp_line   => 'CMD -',
        comp_point0 => '     ^',
        result      => [qw(--help -? -h)],
    );
    test_complete(
        args        => {meta=>$meta},
        comp_line   => 'CMD x ',
        comp_point0 => '      ^',
        result      => [qw(a aa b c)],
    );
    test_complete(
        args        => {meta=>$meta},
        comp_line   => 'CMD x a',
        comp_point0 => '       ^',
        result      => [qw(a aa)],
    );
    test_complete(
        args        => {meta=>$meta},
        comp_line   => 'CMD x -',
        comp_point0 => '       ^',
        result      => [qw(--help -? -h)],
    );
};

subtest "complete element value (using arg spec's element_completion)" => sub {
    my $meta = _normalize_meta({
        v => 1.1,
        args => {
            arg => {
                schema => ["array*" => of => [str => in => [qw/a aa b c/]]],
                element_completion => sub {[qw/d dd e f/]},
                pos    => 0,
                greedy => 1,
            },
        },
    });
    test_complete(
        args        => {meta=>$meta},
        comp_line   => 'CMD ',
        comp_point0 => '    ^',
        result      => [qw(d dd e f)],
    );
    test_complete(
        args        => {meta=>$meta},
        comp_line   => 'CMD d',
        comp_point0 => '     ^',
        result      => [qw(d dd)],
    );
    test_complete(
        args        => {meta=>$meta},
        comp_line   => 'CMD -',
        comp_point0 => '     ^',
        result      => [qw(--help -? -h)],
    );
    test_complete(
        args        => {meta=>$meta},
        comp_line   => 'CMD x ',
        comp_point0 => '      ^',
        result      => [qw(d dd e f)],
    );
    test_complete(
        args        => {meta=>$meta},
        comp_line   => 'CMD x d',
        comp_point0 => '       ^',
        result      => [qw(d dd)],
    );
    test_complete(
        args        => {meta=>$meta},
        comp_line   => 'CMD x -',
        comp_point0 => '       ^',
        result      => [qw(--help -? -h)],
    );
};

subtest "complete element value (using custom_arg_element_completer HoC)" => sub {
    # TODO
    ok 1;
};

subtest "complete element value (using custom_arg_element_completer Code)" => sub {
    # TODO
    ok 1;
};

# XXX test ENV
# XXX test fallback arg value to file

DONE_TESTING:
done_testing();

sub _normalize_meta {
    my $meta = shift;
    require Perinci::Sub::Wrapper;
    my $res = Perinci::Sub::Wrapper::wrap_sub(
        sub=>sub{}, meta=>$meta, compile=>0);
    die "Can't wrap: $res->[0] - $res->[1]" unless $res->[0] == 200;
    $res->[2]{meta};
}

sub test_complete {
    my (%args) = @_;

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

    subtest $name => sub {

        # XXX test supplying via 'words' and 'cword' arguments
        local $ENV{COMP_LINE}  = $line;
        local $ENV{COMP_POINT} = $point;

        my $res = shell_complete_arg(%{$args{args}});
        is_deeply($res, $args{result}, "result") or diag explain($res);

        done_testing();
    };
}
