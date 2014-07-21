#!perl

use 5.010;
use strict;
use warnings;
#use Log::Any '$log';

use Complete::Util qw(complete_array_elem);
use File::Which qw(which);
use Perinci::Sub::Complete qw(complete_cli_arg);
use Perinci::Sub::Normalize qw(normalize_function_metadata);
use Test::More 0.98;

plan skip_all => "bash is not available on this system" unless which("bash");

my $meta = normalize_function_metadata({
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
                complete_array_elem(array=>[qw(apple apricot cherry cranberry)], word=>$args{word});
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
    comp_line0  => 'CMD ^',
    result      => {completion=>[qw(--bool1 --bool2 --help --no-bool1 --no-bool2 --nobool1 --nobool2
                                    --str1 --str2 -? -h)],
                    escmode=>'option'},
);
test_complete(
    name        => 'complete arg name 2',
    args        => {meta=>$meta},
    comp_line0  => 'CMD -^',
    result      => {completion=>[qw(--bool1 --bool2 --help --no-bool1 --no-bool2 --nobool1 --nobool2
                                    --str1 --str2 -? -h)],
                    escmode=>'option'},
);
test_complete(
    name        => 'complete arg name 3',
    args        => {meta=>$meta},
    comp_line0  => 'CMD --^',
    result      => {completion=>[qw(--bool1 --bool2 --help --no-bool1 --no-bool2 --nobool1 --nobool2
                                    --str1 --str2)],
                    escmode=>'option'},
);
test_complete(
    name        => 'complete arg name 4',
    args        => {meta=>$meta},
    comp_line0  => 'CMD --^b',
    result      => {completion=>[qw(--bool1 --bool2 --help --no-bool1 --no-bool2 --nobool1 --nobool2
                                    --str1 --str2)],
                    escmode=>'option'},
);
test_complete(
    name        => 'complete arg name 5',
    args        => {meta=>$meta},
    comp_line0  => 'CMD --b^',
    result      => {completion=>[qw(--bool1 --bool2)],
                    escmode=>'option'},
);
test_complete(
    name        => 'complete arg name 6',
    args        => {meta=>$meta},
    comp_line0  => 'CMD --x^',
    result      => {completion=>[qw()],
                    escmode=>'option'},
);
test_complete(
    name        => 'complete arg name 7',
    args        => {meta=>$meta},
    comp_line0  => 'CMD --bool1^',
    result      => {completion=>[qw(--bool1)],
                    escmode=>'option'},
);
test_complete(
    name        => 'no longer complete mentioned arg',
    args        => {meta=>$meta},
    comp_line0  => 'CMD --bool1 ^',
    result      => {completion=>[qw(--bool2 --help --no-bool2 --nobool2 --str1 --str2 -? -h)],
                    escmode=>'option'},
);
test_complete(
    name        => 'no longer complete mentioned arg (2)',
    args        => {meta=>$meta},
    comp_line0  => 'CMD --nobool1 ^',
    result      => {completion=>[qw(--bool2 --help --no-bool2 --nobool2 --str1 --str2 -? -h)],
                    escmode=>'option'},
);
test_complete(
    name        => 'no longer complete mentioned arg (3)',
    args        => {meta=>$meta},
    comp_line0  => 'CMD --str1 1 --nobool1 ^',
    result      => {completion=>[qw(--bool2 --help --no-bool2 --nobool2 --str2 -? -h)],
                    escmode=>'option'},
);
test_complete(
    name        => 'no longer complete mentioned common opts',
    args        => {meta=>$meta},
    comp_line0  => 'CMD --bool1 --nobool2 --help ^',
    result      => {completion=>[qw(--str1 --str2)],
                    escmode=>'option'},
);
test_complete(
    name        => 'no longer complete mentioned common opts (2)',
    args        => {meta=>$meta},
    comp_line0  => 'CMD --bool1 --nobool2 -h ^',
    result      => {completion=>[qw(--str1 --str2)],
                    escmode=>'option'},
);
test_complete(
    name        => 'complete arg value',
    args        => {meta=>$meta},
    comp_line0  => 'CMD --bool1 --str2 ^',
    result      => {completion=>[qw(bar baz foo str)],
                },
);
test_complete(
    name        => 'complete arg value (2)',
    args        => {meta=>$meta},
    comp_line0  => 'CMD --bool1 --str2=f^',
    result      => {completion=>[qw(foo)],
                },
);
test_complete(
    name        => 'complete arg name instead of value when user type -',
    args        => {meta=>$meta},
    comp_line0  => 'CMD --bool1 -^',
    result      => {completion=>[qw(--bool2 --help --no-bool2 --nobool2 --str1 --str2 -? -h)],
                    escmode=>'option'},
);
test_complete(
    name        => 'complete arg value (spec "in")',
    args        => {meta=>$meta},
    comp_line0  => 'CMD --bool1 --str2 ba^',
    result      => {completion=>[qw(bar baz)],
                },
);
test_complete(
    name        => 'complete arg value (spec "completion")',
    args        => {meta=>$meta},
    comp_line0  => 'CMD --str1 ^',
    result      => {completion=>[qw(apple apricot cherry cranberry)],
                },
);
test_complete(
    name        => 'complete arg value (spec "completion") (2)',
    args        => {meta=>$meta},
    comp_line0  => 'CMD --str1 ap^p',
    result      => {completion=>[qw(apple apricot)],
                },
);
test_complete(
    name        => 'complete arg value (spec "completion") (3)',
    args        => {meta=>$meta},
    comp_line0  => 'CMD --str1 apx^',
    result      => {completion=>[qw()],
                },
);
test_complete(
    name        => 'complete arg value (arg "custom_arg_completer" HoCode)',
    args        => {meta=>$meta,
                    custom_arg_completer => {
                        str1=>sub {
                            my %args = @_;
                            complete_array_elem(array=>[qw/a b c/], word=>$args{word});
                        }}},
    comp_line0  => 'CMD --str1 ^',
    result      => {completion=>[qw(a b c)],
                },
);
test_complete(
    name        => 'complete arg value (arg "custom_arg_completer" HoCode,'.
        ' no match)',
    args        => {meta=>$meta,
                    custom_arg_completer => {
                        str2=>sub {
                            my %args = @_;
                            complete_array_elem(array=>[qw(a b c)], word=>$args{word});
                    }}},
    comp_line0  => 'CMD --str1 ^',
    result      => {completion=>[qw(apple apricot cherry cranberry)],
                },
);
test_complete(
    name        => 'complete arg value (opts "custom_arg_completer" code)',
    args        => {meta=>$meta,
                    custom_arg_completer => sub {
                        my %args = @_;
                        complete_array_elem(array=>[qw(a b c)], word=>$args{word});
                    }},
    comp_line0  => 'CMD --str1 ^',
    result      => {completion=>[qw(a b c)],
                },
);

my $meta2 = normalize_function_metadata({
    v => 1.1,
    args => {
        str1  => {
            schema => ["str*" => {}],
            completion=>sub{
                my %args = @_;
                complete_array_elem(array=>[qw/a b c d/], word=>$args{word});
            },
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
    comp_line0  => 'CMD ^',
    result      => {completion=>[qw(a b c d)],
                },
);
test_complete(
    name        => 'complete arg value, pos (1b)',
    args        => {meta=>$meta2},
    comp_line0  => 'CMD a^',
    result      => {completion=>[qw(a)],
                },
);
test_complete(
    name        => 'complete arg value, pos (2)',
    args        => {meta=>$meta2},
    comp_line0  => 'CMD a ^',
    result      => {completion=>[qw(e f g h)],
                },
);
test_complete(
    name        => 'complete arg value, pos (2b)',
    args        => {meta=>$meta2},
    comp_line0  => 'CMD a f^',
    result      => {completion=>[qw(f)],
                },
);
test_complete(
    name        => 'complete arg value, pos (3)',
    args        => {meta=>$meta2},
    comp_line0  => 'CMD a e ^',
    result      => {completion=>[qw(i j k l)],
                },
);
test_complete(
    name        => 'complete arg value, pos (3b)',
    args        => {meta=>$meta2},
    comp_line0  => 'CMD a e j^',
    result      => {completion=>[qw(j)],
                },
);
test_complete(
    name        => 'complete arg value (pos) becomes complete arg name because word starts with -',
    args        => {meta=>$meta2},
    comp_line0  => 'CMD a e -^',
    result      => {completion=>[qw(--help --str3 -? -h)],
                    escmode=>'option'},
);
{
    my $meta = {
        v => 1.1,
        args => {
            str => { schema => ['str', {in=>[qw/a -a -b/]}], pos=>0 },
        },
    };
    test_complete(
        name        => 'complete arg value does not become complete arg name despite word starts with -, because opt expects value',
        args        => {meta=>$meta},
        comp_line0  => 'CMD --str -^',
        result      => {completion=>[qw(-a -b)],
                    },
    );
}
{
    my $meta = {
        v => 1.1,
        args => {
            bool => { schema => ['bool', {}], pos=>0 },
        },
    };
    test_complete(
        name        => 'complete arg value becomes complete arg name because word starts with - (opt does not expect value)',
        args        => {meta=>$meta},
        comp_line0  => 'CMD --bool -^',
        result      => {completion=>[qw(--bool --help --no-bool --nobool -? -h)],
                    escmode=>'option'},
    );
}

test_complete(
    name        => 'custom_completer (decline)',
    args        => {meta=>$meta2,
                    custom_completer=>sub {return undef}},
    comp_line0  => 'CMD a e -^',
    result      => {completion=>[qw(--help --str3 -? -h)],
                    escmode=>'option'},
);
test_complete(
    name        => 'custom_completer',
    args        => {meta=>$meta2,
                    custom_completer=>sub {return ["-a", "-b"]}},
    comp_line0  => 'CMD a e -^',
    result      => {completion=>[qw(-a -b)],
                },
);


my $meta3 = normalize_function_metadata({
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
    comp_line0  => 'CMD ^',
    result      => {completion=>[qw(--S2 --alias1 --b2 --b3 --help --no-alias1 --no-b2 --noalias1 --nob2 --s2
                                    -? -S -X -b -h -s)],
                    escmode=>'option'},
);

my $meta4 = normalize_function_metadata({
    v => 1.1,
    args => {
        foo_bar   => {schema => "str"},
        "foo.baz" => {schema => "str"},
    },
});

test_complete(
    name        => 'special argument names',
    args        => {meta=>$meta4},
    comp_line0  => 'CMD --f^',
    result      => {completion=>[qw(--foo-bar --foo-baz)],
                    escmode=>'option'},
);

my $meta5 = normalize_function_metadata({
    v => 1.1,
    args => {},
    features => {dry_run=>1},
});

subtest "complete element value (schema)" => sub {
    my $meta = normalize_function_metadata({
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
        comp_line0  => 'CMD ^',
        result      => {completion=>[qw(a aa b c)],
                    },
    );
    test_complete(
        args        => {meta=>$meta},
        comp_line0  => 'CMD a^',
        result      => {completion=>[qw(a aa)],
                    },
    );
    test_complete(
        args        => {meta=>$meta},
        comp_line0  => 'CMD -^',
        result      => {completion=>[qw(--arg --help -? -h)],
                        escmode=>'option'},
    );
    test_complete(
        args        => {meta=>$meta},
        comp_line0  => 'CMD x ^',
        result      => {completion=>[qw(a aa b c)],
                    },
    );
    test_complete(
        args        => {meta=>$meta},
        comp_line0  => 'CMD x a^',
        result      => {completion=>[qw(a aa)],
                    },
    );
    test_complete(
        args        => {meta=>$meta},
        comp_line0  => 'CMD x -^',
        result      => {completion=>[qw(--arg --help -? -h)],
                        escmode=>'option'},
    );
    test_complete(
        name        => '--arg is always completeable',
        args        => {meta=>$meta},
        comp_line0  => 'CMD --arg x --^',
        result      => {completion=>[qw(--arg --help)],
                        escmode=>'option'},
    );
};

subtest "complete element value (arg spec's element_completion)" => sub {
    my $meta = normalize_function_metadata({
        v => 1.1,
        args => {
            arg => {
                schema => ["array*" => of => [str => in => [qw/a aa b c/]]],
                element_completion => sub {
                    my %args = @_;
                    complete_array_elem(array=>[qw/d dd e f/], word=>$args{word});
                },
                pos    => 0,
                greedy => 1,
            },
        },
    });
    test_complete(
        args        => {meta=>$meta},
        comp_line0  => 'CMD ^',
        result      => {completion=>[qw(d dd e f)],
                    },
    );
    test_complete(
        args        => {meta=>$meta},
        comp_line0  => 'CMD d^',
        result      => {completion=>[qw(d dd)],
                    },
    );
    test_complete(
        args        => {meta=>$meta},
        comp_line0  => 'CMD -^',
        result      => {completion=>[qw(--arg --help -? -h)],
                        escmode=>'option'},
    );
    test_complete(
        args        => {meta=>$meta},
        comp_line0  => 'CMD x ^',
        result      => {completion=>[qw(d dd e f)],
                    },
    );
    test_complete(
        args        => {meta=>$meta},
        comp_line0  => 'CMD x d^',
        result      => {completion=>[qw(d dd)],
                    },
    );
    test_complete(
        args        => {meta=>$meta},
        comp_line0  => 'CMD x -^',
        result      => {completion=>[qw(--arg --help -? -h)],
                        escmode=>'option'},
    );
    # XXX test element_completion declines -> fallback to schema
};

subtest "complete element value (custom_arg_element_completer HoC)" => sub {
    my $meta = normalize_function_metadata({
        v => 1.1,
        args => {
            arg => {
                schema => ["array*" => of => [str => in => [qw/a aa b c/]]],
                element_completion => sub {
                    my %args = @_;
                    complete_array_elem(array=>[qw/d dd e f/], word=>$args{word});
                },
                pos    => 0,
                greedy => 1,
            },
        },
    });
    my $caec = {
        arg => sub {
            my %args = @_;
            complete_array_elem(array=>[qw/g gg h i/], word=>$args{word});
        },
    };
    test_complete(
        args        => {meta=>$meta, custom_arg_element_completer=>$caec},
        comp_line0  => 'CMD ^',
        result      => {completion=>[qw(g gg h i)],
                    },
    );
    test_complete(
        args        => {meta=>$meta, custom_arg_element_completer=>$caec},
        comp_line0  => 'CMD g^',
        result      => {completion=>[qw(g gg)],
                    },
    );
    test_complete(
        args        => {meta=>$meta, custom_arg_element_completer=>$caec},
        comp_line0  => 'CMD -^',
        result      => {completion=>[qw(--arg --help -? -h)],
                        escmode=>'option'},
    );
    test_complete(
        args        => {meta=>$meta, custom_arg_element_completer=>$caec},
        comp_line0  => 'CMD x ^',
        result      => {completion=>[qw(g gg h i)],
                    },
    );
    test_complete(
        args        => {meta=>$meta, custom_arg_element_completer=>$caec},
        comp_line0  => 'CMD x g^',
        result      => {completion=>[qw(g gg)],
                    },
    );
    test_complete(
        args        => {meta=>$meta, custom_arg_element_completer=>$caec},
        comp_line0  => 'CMD x -^',
        result      => {completion=>[qw(--arg --help -? -h)],
                        escmode=>'option'},
    );
    # XXX test custom_arg_element_completer declines -> fallback to element_completion
};

subtest "complete element value (custom_arg_element_completer Code)" => sub {
    my $meta = normalize_function_metadata({
        v => 1.1,
        args => {
            arg => {
                schema => ["array*" => of => [str => in => [qw/a aa b c/]]],
                element_completion => sub {
                    my %args = @_;
                    complete_array_elem(array=>[qw/d dd e f/], word=>$args{word});
                },
                pos    => 0,
                greedy => 1,
            },
        },
    });
    my $caec = sub {
        my %args = @_;
        complete_array_elem(array=>[qw/g gg h i/], word=>$args{word});
    };
    test_complete(
        args        => {meta=>$meta, custom_arg_element_completer=>$caec},
        comp_line0  => 'CMD ^',
        result      => {completion=>[qw(g gg h i)],
                    },
    );
    test_complete(
        args        => {meta=>$meta, custom_arg_element_completer=>$caec},
        comp_line0  => 'CMD g^',
        result      => {completion=>[qw(g gg)],
                    },
    );
    test_complete(
        args        => {meta=>$meta, custom_arg_element_completer=>$caec},
        comp_line0  => 'CMD -^',
        result      => {completion=>[qw(--arg --help -? -h)],
                        escmode=>'option'},
    );
    test_complete(
        args        => {meta=>$meta, custom_arg_element_completer=>$caec},
        comp_line0  => 'CMD x ^',
        result      => {completion=>[qw(g gg h i)]},
    );
    test_complete(
        args        => {meta=>$meta, custom_arg_element_completer=>$caec},
        comp_line0  => 'CMD x g^',
        result      => {completion=>[qw(g gg)]},
    );
    test_complete(
        args        => {meta=>$meta, custom_arg_element_completer=>$caec},
        comp_line0  => 'CMD x -^',
        result      => {completion=>[qw(--arg --help -? -h)],
                        escmode=>'option'},
    );
    # XXX test custom_arg_element_completer declines -> fallback to element_completion
};

# since 0.49, we accept hashref from completion routine
subtest "complete values (completion code returns hash)" => sub {
    my $meta;
    $meta = normalize_function_metadata({
        v => 1.1,
        args => {
            arg => {
                schema => ["array*" => of => 'str*'],
                element_completion => sub {
                    my %args = @_;
                    {completion => complete_array_elem(array=>[qw/d dd e f/], word=>$args{word}),
                     path_sep => '/',
                 };
                },
                pos    => 0,
                greedy => 1,
            },
        },
    });
    test_complete(
        args        => {meta=>$meta},
        comp_line0  => 'CMD d^',
        result      => {completion=>[qw(d dd)], path_sep=>'/'},
    );
    $meta = normalize_function_metadata({
        v => 1.1,
        args => {
            arg => {
                schema => ["str*"],
                completion => sub {
                    my %args = @_;
                    {completion => complete_array_elem(array=>[qw/d dd e f/], word=>$args{word}),
                     escmode => 'foo',
                 };
                },
                pos    => 0,
            },
        },
    });
    test_complete(
        args        => {meta=>$meta},
        comp_line0  => 'CMD d^',
        result      => {completion=>[qw(d dd)], escmode=>'foo'},
    );
    # XXX custom_completer returns hash
    # XXX custom_arg_completer returns hash
    # XXX custom_arg_element_completer returns hash
};

# since 0.58, we accept completion property as array (though deliberately
# undocumented for now)
subtest "completion & element_completion code is array" => sub {
    my $meta;
    $meta = normalize_function_metadata({
        v => 1.1,
        args => {
            array => {
                schema => ["array*" => of => "str*"],
                element_completion => [qw/aa ab b/],
            },
            str => {
                schema => "str*",
                completion => [qw/st ss t/],
            },
        },
    });
    test_complete(
        args        => {meta=>$meta},
        comp_line0  => 'CMD --array a^',
        result      => {completion=>[qw/aa ab/]},
    );
    test_complete(
        args        => {meta=>$meta},
        comp_line0  => 'CMD --str s^',
        result      => {completion=>[qw/ss st/]},
    );
};

# XXX test ENV
# XXX test fallback arg value to file

DONE_TESTING:
done_testing();

sub test_complete {
    my (%args) = @_;

    subtest +($args{name} // $args{comp_line0}) => sub {

        # $args{comp_line0} contains comp_line with '^' indicating where
        # comp_point should be, the caret will be stripped. this is more
        # convenient than counting comp_point manually.
        my $comp_line  = $args{comp_line0};
        defined ($comp_line) or die "BUG: comp_line0 not defined";
        my $comp_point = index($comp_line, '^');
        $comp_point >= 0 or
            die "BUG: comp_line0 should contain ^ to indicate where comp_point is";
        $comp_point =~ s/\^//;

        local $ENV{COMP_LINE}  = $comp_line;
        local $ENV{COMP_POINT} = $comp_point;

        my $co = {'help|h|?'=>sub{}};

        my $res = complete_cli_arg(%{$args{args}}, common_opts=>$co);
        is_deeply($res, $args{result}, "result") or diag explain($res);

        done_testing();
    };
}
