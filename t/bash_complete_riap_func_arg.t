#!perl

use 5.010;
use strict;
use warnings;
#use Log::Any '$log';

package Test::Perinci::BashComplete;

our %SPEC;

$SPEC{f1} = {
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
};
sub f1 { [200,"OK"] }

$SPEC{f2} = {
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
};
sub f2 { [200,"OK"] }

package main;

use File::Which qw(which);
use Perinci::Access;
use Perinci::Access::InProcess;
use Perinci::BashComplete qw(bash_complete_riap_func_arg);
use Test::More;

plan skip_all => "bash is not available on this system" unless which("bash");

test_complete(
    args        => {url=>'/Test/Perinci/BashComplete/f1'},
    comp_line   => 'CMD ',
    comp_point0 => '    ^',
    result      => [qw(--bool1 --bool2 --help --nobool1 --nobool2
                       --str1 --str2 -? -h)],
);
test_complete(
    args        => {url=>'/Test/Perinci/BashComplete/f1'},
    comp_line   => 'CMD -',
    comp_point0 => '     ^',
    result      => [qw(--bool1 --bool2 --help --nobool1 --nobool2
                       --str1 --str2 -? -h)],
);
test_complete(
    args        => {url=>'/Test/Perinci/BashComplete/f1'},
    comp_line   => 'CMD --',
    comp_point0 => '      ^',
    result      => [qw(--bool1 --bool2 --help --nobool1 --nobool2
                       --str1 --str2)],
);
test_complete(
    args        => {url=>'/Test/Perinci/BashComplete/f1'},
    comp_line   => 'CMD --b',
    comp_point0 => '      ^',
    result      => [qw(--bool1 --bool2 --help --nobool1 --nobool2
                       --str1 --str2)],
);
test_complete(
    args        => {url=>'/Test/Perinci/BashComplete/f1'},
    comp_line   => 'CMD --b',
    comp_point0 => '       ^',
    result      => [qw(--bool1 --bool2)],
);
test_complete(
    args        => {url=>'/Test/Perinci/BashComplete/f1'},
    comp_line   => 'CMD --x',
    comp_point0 => '       ^',
    result      => [qw()],
);
test_complete(
    args        => {url=>'/Test/Perinci/BashComplete/f1'},
    comp_line   => 'CMD --bool1',
    comp_point0 => '           ^',
    result      => [qw(--bool1)],
);
test_complete(
    name        => 'no longer complete mentioned arg',
    args        => {url=>'/Test/Perinci/BashComplete/f1'},
    comp_line   => 'CMD --bool1 ',
    comp_point0 => '            ^',
    result      => [qw(--bool2 --help --nobool2 --str1 --str2 -? -h)],
);
test_complete(
    name        => 'no longer complete mentioned arg (2)',
    args        => {url=>'/Test/Perinci/BashComplete/f1'},
    comp_line   => 'CMD --nobool1 ',
    comp_point0 => '              ^',
    result      => [qw(--bool2 --help --nobool2 --str1 --str2 -? -h)],
);
test_complete(
    name        => 'no longer complete mentioned arg (3)',
    args        => {url=>'/Test/Perinci/BashComplete/f1'},
    comp_line   => 'CMD --str1 1 --nobool1 ',
    comp_point0 => '                       ^',
    result      => [qw(--bool2 --help --nobool2 --str2 -? -h)],
);
test_complete(
    name        => 'no longer complete mentioned common opts',
    args        => {url=>'/Test/Perinci/BashComplete/f1'},
    comp_line   => 'CMD --bool1 --nobool2 --help ',
    comp_point0 => '                             ^',
    result      => [qw(--str1 --str2)],
);
test_complete(
    name        => 'no longer complete mentioned common opts (2)',
    args        => {url=>'/Test/Perinci/BashComplete/f1'},
    comp_line   => 'CMD --bool1 --nobool2 -h ',
    comp_point0 => '                         ^',
    result      => [qw(--str1 --str2)],
);
test_complete(
    name        => 'complete arg value',
    args        => {url=>'/Test/Perinci/BashComplete/f1'},
    comp_line   => 'CMD --bool1 --str2 ',
    comp_point0 => '                   ^',
    result      => [qw(foo bar baz str)],
);
test_complete(
    name        => 'complete arg value (2)',
    args        => {url=>'/Test/Perinci/BashComplete/f1'},
    comp_line   => 'CMD --bool1 --str2=f',
    comp_point0 => '                    ^',
    result      => [qw(foo)],
);
test_complete(
    name        => 'complete arg name instead of value when user type -',
    args        => {url=>'/Test/Perinci/BashComplete/f1'},
    comp_line   => 'CMD --bool1 -',
    comp_point0 => '             ^',
    result      => [qw(--bool2 --help --nobool2 --str1 --str2 -? -h)],
);
test_complete(
    name        => 'complete arg value (spec "in")',
    args        => {url=>'/Test/Perinci/BashComplete/f1'},
    comp_line   => 'CMD --bool1 --str2 ba',
    comp_point0 => '                     ^',
    result      => [qw(bar baz)],
);
test_complete(
    name        => 'complete arg value (spec "completion")',
    args        => {url=>'/Test/Perinci/BashComplete/f1'},
    comp_line   => 'CMD --str1 ',
    comp_point0 => '           ^',
    result      => [qw(apple apricot cherry cranberry)],
);
test_complete(
    name        => 'complete arg value (spec "completion") (2)',
    args        => {url=>'/Test/Perinci/BashComplete/f1'},
    comp_line   => 'CMD --str1 app',
    comp_point0 => '             ^',
    result      => [qw(apple apricot)],
);
test_complete(
    name        => 'complete arg value (spec "completion") (3)',
    args        => {url=>'/Test/Perinci/BashComplete/f1'},
    comp_line   => 'CMD --str1 apx',
    comp_point0 => '              ^',
    result      => [qw()],
);
test_complete(
    name        => 'complete arg value (arg "custom_arg_completer" HoCode)',
    args        => {url=>'/Test/Perinci/BashComplete/f1',
                    custom_arg_completer => {str1=>sub {qw(a b c)}}},
    comp_line   => 'CMD --str1 ',
    comp_point0 => '           ^',
    result      => [qw(a b c)],
);
test_complete(
    name        => 'complete arg value (arg "custom_arg_completer" HoCode, '.
        'no match)',
    args        => {url=>'/Test/Perinci/BashComplete/f1',
                    custom_arg_completer => {str2=>sub {qw(a b c)}}},
    comp_line   => 'CMD --str1 ',
    comp_point0 => '           ^',
    result      => [qw(apple apricot cherry cranberry)],
);
test_complete(
    name        => 'complete arg value (opts "custom_arg_completer" code)',
    args        => {url=>'/Test/Perinci/BashComplete/f1',
                    custom_arg_completer => sub {qw(a b c)}},
    comp_line   => 'CMD --str1 ',
    comp_point0 => '           ^',
    result      => [qw(a b c)],
);

test_complete(
    name        => 'complete arg value, pos (1)',
    args        => {url=>'/Test/Perinci/BashComplete/f2'},
    comp_line   => 'CMD ',
    comp_point0 => '    ^',
    result      => [qw(a b c d)],
);
test_complete(
    name        => 'complete arg value, arg_pos (1b)',
    args        => {url=>'/Test/Perinci/BashComplete/f2'},
    comp_line   => 'CMD a',
    comp_point0 => '     ^',
    result      => [qw(a)],
);
test_complete(
    name        => 'complete arg value, arg_pos (2)',
    args        => {url=>'/Test/Perinci/BashComplete/f2'},
    comp_line   => 'CMD a ',
    comp_point0 => '      ^',
    result      => [qw(e f g h)],
);
test_complete(
    name        => 'complete arg value, arg_pos (2b)',
    args        => {url=>'/Test/Perinci/BashComplete/f2'},
    comp_line   => 'CMD a f',
    comp_point0 => '       ^',
    result      => [qw(f)],
);
test_complete(
    name        => 'complete arg value, arg_pos (3)',
    args        => {url=>'/Test/Perinci/BashComplete/f2'},
    comp_line   => 'CMD a e ',
    comp_point0 => '        ^',
    result      => [qw(i j k l)],
);
test_complete(
    name        => 'complete arg value, arg_pos (3b)',
    args        => {url=>'/Test/Perinci/BashComplete/f2'},
    comp_line   => 'CMD a e j',
    comp_point0 => '         ^',
    result      => [qw(j)],
);
test_complete(
    name        => 'complete arg value, arg_pos mixed with --opt',
    args        => {url=>'/Test/Perinci/BashComplete/f2'},
    comp_line   => 'CMD a e -',
    comp_point0 => '         ^',
    result      => [qw(--help --str3 -? -h)],
);
test_complete(
    name        => 'custom_completer (decline)',
    args        => {url=>'/Test/Perinci/BashComplete/f2',
                    custom_completer=>sub {return undef}},
    comp_line   => 'CMD a e -',
    comp_point0 => '         ^',
    result      => [qw(--help --str3 -? -h)],
);
test_complete(
    name        => 'custom_completer',
    args        => {url=>'/Test/Perinci/BashComplete/f2',
                    custom_completer=>sub {return ["-a", "-b"]}},
    comp_line   => 'CMD a e -',
    comp_point0 => '         ^',
    result      => [qw(-a -b)],
);

# XXX test ENV
# XXX test fallback arg value to file

DONE_TESTING:
done_testing();

sub test_complete {
    my (%args) = @_;
    #$log->tracef("args=%s", \%args);
    state $pa;
    unless ($pa) {
        my $paip = Perinci::Access::InProcess->new(load=>0);
        $pa = Perinci::Access->new(
            handlers=>{pm=>$paip}
        );
    }

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

        my $res = bash_complete_riap_func_arg(%{$args{args}}, pa=>$pa);
        is_deeply($res, $args{result}, "result") or diag explain($res);

        done_testing();
    };
}

