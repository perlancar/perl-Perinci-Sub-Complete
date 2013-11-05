package Perinci::Sub::Complete;

use 5.010001;
use strict;
use warnings;
use experimental 'smartmatch';
use Log::Any '$log';

use SHARYANTO::Complete::Util qw(
                                    complete_array
                                    complete_env
                                    complete_file
                                    parse_shell_cmdline
                            );

# VERSION

require Exporter;
our @ISA       = qw(Exporter);
our @EXPORT_OK = qw(
                       shell_complete_arg
               );
our %SPEC;

$SPEC{complete_arg_val} = {
    v => 1.1,
    summary => 'Given argument name and function metadata, complete value',
    args => {
        meta => {
            summary => 'Rinci function metadata',
            schema => 'hash*',
            req => 1,
        },
        arg => {
            summary => 'Argument name',
            schema => 'str*',
            req => 1,
        },
        word => {
            summary => 'Word to be completed',
            schema => ['str*', default => ''],
        },
        ci => {
            summary => 'Whether to be case-insensitive',
            schema => ['bool*', default => 0],
        },
        parent_args => {
            summary => 'To pass parent arguments to completion routines',
            schema  => 'hash',
        },
    },
    result_naked => 1,
};
sub complete_arg_val {
    my %args = @_;

    my $meta = $args{meta} or return [];
    my $arg  = $args{arg} or return [];
    my $ci   = $args{ci} // 0;
    my $word = $args{word} // '';

    my $args_p = $meta->{args} // {};
    my $arg_p = $args_p->{$arg} or return [];

    my $words;
    eval { # completion sub can die, etc.

        if ($arg_p->{completion}) {
            $words = $arg_p->{completion}->(
                word=>$word, ci=>$ci, parent_args=>\%args);
            die "Completion sub does not return array"
                unless ref($words) eq 'ARRAY';
            return;
        }

        my $sch = $arg_p->{schema};

        my ($type, $cs) = @{$sch};
        if ($cs->{in}) {
            $words = $cs->{in};
            return;
        }

        if ($type =~ /^int\*?$/) {
            my $limit = 100;
            if ($cs->{between} &&
                    $cs->{between}[0] - $cs->{between}[0] <= $limit) {
                $words = [$cs->{between}[0] .. $cs->{between}[1]];
                return;
            } elsif ($cs->{xbetween} &&
                    $cs->{xbetween}[0] - $cs->{xbetween}[0] <= $limit) {
                $words = [$cs->{xbetween}[0]+1 .. $cs->{xbetween}[1]-1];
                return;
            } elsif (defined($cs->{min}) && defined($cs->{max}) &&
                         $cs->{max}-$cs->{min} <= $limit) {
                $words = [$cs->{min} .. $cs->{max}];
                return;
            } elsif (defined($cs->{min}) && defined($cs->{xmax}) &&
                         $cs->{xmax}-$cs->{min} <= $limit) {
                $words = [$cs->{min} .. $cs->{xmax}-1];
                return;
            } elsif (defined($cs->{xmin}) && defined($cs->{max}) &&
                         $cs->{max}-$cs->{xmin} <= $limit) {
                $words = [$cs->{xmin}+1 .. $cs->{max}];
                return;
            } elsif (defined($cs->{xmin}) && defined($cs->{xmax}) &&
                         $cs->{xmax}-$cs->{xmin} <= $limit) {
                $words = [$cs->{min}+1 .. $cs->{max}-1];
                return;
            }
        }

        $words = [];
    };
    $log->debug("Completion died: $@") if $@;
    return [] unless $words;
    complete_array(array=>$words, word=>$word, ci=>$ci);
}

$SPEC{shell_complete_arg} = {
    v => 1.1,
    summary => 'Complete command-line argument using Rinci function metadata',
    description => <<'_',

Assuming that command-line like:

    foo a b c

is executing some function, and the command-line arguments will be parsed using
`Perinci::Sub::GetArgs::Argv`, then try to complete command-line arguments using
information from Rinci metadata.

Algorithm:

1. If word begins with `$`, we complete from environment variables and are done.

2. Call `get_args_from_argv()` to extract hash arguments from the given `words`.

3. Determine whether we need to complete argument name (e.g. `--arg<tab>`) or
argument value (e.g. `--arg1 <tab>` or `<tab>` at 1st word where there is an
argument specified at pos=0).

4. Call `custom_completer` if defined. If a list of words is returned, we're
done. This can be used for, e.g. nested function call, e.g.:

    somecmd --opt-for-cmd ... subcmd --opt-for-subcmd ...

5. If we are completing argument name, then supply a list of possible argument
names, or fallback to completing filenames.

6. If we are completing argument value, first check if `custom_arg_completer` is
defined. If yes, call that routine. If a list of words is returned, we're done.
Fallback to completing argument values from information in Rinci metadata (using
`complete_arg_val()` function).

_
    args => {
        words => {
            summary => 'Command-line, broken as words',
            schema => ['array*' => {of=>'str*'}],
            description => <<'_',

If unset, will be taken from COMP_LINE and COMP_POINT.

_
        },
        cword => {
            summary => 'On which word cursor is located (zero-based)',
            description => <<'_',

If unset, will be taken from COMP_LINE and COMP_POINT.

_
            schema => 'int*',
        },
        custom_completer => {
            summary => 'Supply custom completion routine',
            description => <<'_',

If supplied, instead of the default completion routine, this code will be called
instead. Refer to function description to see when this routine is called.

Code will be called with a hash argument, with these keys: `which` (a string
with value `name` or `value` depending on whether we should complete argument
name or value), `words` (an array, the command line split into words), `cword`
(int, position of word in `words`), `word` (the word to be completed),
`parent_args` (hash), `remaining_words` (array, slice of `words` after `cword`),
`meta` (the Rinci function metadata).

Code should return an arrayref of completion, or `undef` to declare declination,
on which case completion will resume using the standard builtin routine.

A use-case of using this option: XXX.

_
            schema => 'code*',
        },
        custom_arg_completer => {
            summary => 'Supply custom argument value completion routines',
            description => <<'_',

Either code or a hash of argument names and codes.

If supplied, instead of the default completion routine, this code will be called
instead. Refer to function description to see when this routine is called.

Code will be called with hash arguments containing these keys: `word` (string,
the word to be completed), `arg` (string, the argument name that we are
completing the value of), `args` (hash, the arguments that have been collected
so far).

A use-case for using this option: getting argument value from Riap client using
the `complete_arg_val` action. This allows getting completion from remote
server.

_
            schema=>['any*' => {
                of => [
                    'code*',
                    ['hash*'=>{
                        #values=>'code*', # temp: disabled, not supported yet by Data::Sah
                    }],
                ]}],
        },
        common_opts => {
            summary => 'Common options',
            description => <<'_',

When completing argument name, this list will be added.

_
            schema => ['array*' => {
                of=>['any*' => {of=>['str*', ['array*'=>{of=>'str*'}]]}],
                default=>[['--help', '-?', '-h']],
            }],
        },
    },
    result_naked => 1,
};
sub shell_complete_arg {
    require Perinci::Sub::GetArgs::Argv;
    require UUID::Random;

    my %args = @_;
    $log->tracef("=> complete_arg(%s)", \%args);
    my $meta  = $args{meta} or die "Please specify meta";
    my $words = $args{words};
    my $cword = $args{cword} // 0;
    if (!$words) {
        my $res = parse_shell_cmdline();
        $words = $res->{words};
        $cword = $res->{cword};
    }
    my $word = $words->[$cword] // "";

    my $res;

    $log->tracef("words=%s, cword=%d, word=%s", $words, $cword, $word);

    if ($word =~ /^\$/) {
        $log->tracef("word begins with \$, completing env vars");
        return complete_env(word=>$word);
    }

    if ((my $v = $meta->{v} // 1.0) != 1.1) {
        $log->debug("Metadata version is not supported ($v), ".
                        "only 1.1 is supported");
        return [];
    }
    my $args_p = $meta->{args} // {};

    # first, we stick a unique ID at cword to be able to check whether we should
    # complete arg name or arg value.
    my $which = 'name';
    my $arg;
    my $remaining_words = [@$words];

    my $uuid = UUID::Random::generate();
    my $orig_word = $remaining_words->[$cword];
    $remaining_words->[$cword] = $uuid;
    $res = Perinci::Sub::GetArgs::Argv::get_args_from_argv(
        argv=>$remaining_words, meta=>$meta, strict=>0);
    if ($res->[0] != 200) {
        $log->debug("Failed getting args from argv: $res->[0] - $res->[1]");
        return [];
    }
    my $args = $res->[2];
    for (keys %$args) {
        if (defined($args->{$_}) && $args->{$_} eq $uuid) {
            $arg = $_;
            $which = 'value';
            $args->{$_} = undef;
            last;
        }
    }
    # restore original word which we replaced with uuid earlier (we can't simply
    # use local $remaining_words->[$cword] = $uuid because the $remaining_words
    # array might already be sliced by get_args_from_argv())
    for my $i (0..@$remaining_words-1) {
        if (defined($remaining_words->[$i]) &&
                $remaining_words->[$i] eq $uuid) {
            $remaining_words->[$i] = $orig_word;
        }
    }
    # shave undef at the end because it might be formed when doing '--arg1
    # <tab>' (XXX but why?) if we don't shave it, it will be assumed as '--arg1
    # undef' and we move on to next arg name, when we should complete arg1's
    # value.
    pop @$remaining_words
        while (@$remaining_words && !defined($remaining_words->[-1]));

    if ($which eq 'value' && $word =~ /^-/) {
        # user indicates he wants to complete arg name
        $which = 'name';
        delete $args->{$arg} if !defined($args->{$arg});
    } elsif ($which ne 'value' && $word =~ /^--([\w-]+)=(.*)/) {
        $arg = $1;
        $word = $words->[$cword] = $2;
        $which = 'value';
    }
    $log->tracef("we should complete arg $which, arg=%s, word=%s", $arg, $word);

    if ($args{custom_completer}) {
        $log->tracef("calling 'custom_completer'");
        # custom_completer can decline by returning undef
        my $newcword = $cword - (@$words - @$remaining_words);
        $newcword = 0 if $newcword < 0;
        $res = $args{custom_completer}->(
            which => $which,
            words => $words,
            cword => $newcword,
            word  => $word,
            parent_args => $args,
            meta  => $meta,
            remaining_words => $remaining_words,
        );
        if (!$res) {
            $log->tracef("custom_completer declined, will continue without");
        } else {
            $log->tracef("result from custom_completer: %s", $res);
            return complete_array(word=>$word, array=>$res);
        }
    }

    if ($which eq 'value') {
        my $cac = $args{custom_arg_completer};
        if ($cac) {
            if (ref($cac) eq 'HASH') {
                if ($cac->{$arg}) {
                    $log->tracef("calling 'custom_arg_completer'->{%s}", $arg);
                    $res = $cac->{$arg}->(
                        word => $word, arg => $arg, parent_args => \%args,
                    );
                    if ($res) {
                        return complete_array(word => $word, array => $res);
                    }
                }
            } else {
                $log->tracef("calling 'custom_arg_completer' (arg=%s)", $arg);
                $res = $cac->(
                    word => $word, arg => $arg, parent_args => \%args);
                if ($res) {
                    return complete_array(word => $word, array => $res);
                }
            }
        }

        $res = complete_arg_val(
            meta=>$meta, arg=>$arg, word=>$word,
            parent_args=>\%args,
        );

        return $res if $res && @$res;

        # fallback to file
        $log->tracef("completing arg value from file (fallback)");
        return complete_file(word=>$word);

    } elsif ($word eq '' || $word =~ /^--?/) {
        # which eq 'name'

        # find completable args (the one that has not been mentioned)

        my @words;
      ARG:
        for my $a0 (keys %$args_p) {
            next if exists $args->{$a0};
            my $as = $args_p->{$a0};
            my @a;
            push @a, $a0;
            if ($as->{cmdline_aliases}) {
                push @a, $_ for keys %{$as->{cmdline_aliases}};
            }
            for my $a (@a) {
                $a =~ s/[_.]/-/g;
                my @w;
                my $type = $as->{schema}[0];
                if ($type eq 'bool' && length($a) > 1 &&
                        !$as->{schema}[1]{is}) {
                    @w = ("--$a", "--no$a");
                } else {
                    @w = length($a) == 1 ? ("-$a") : ("--$a");
                }
                push @words, @w;
            }
        }

        my $special_opts = [];
        my $ff = $meta->{features} // {};
        if ($ff->{dry_run}) {
            push @$special_opts, ['--dry-run'];
        }

        my $common_opts = $args{common_opts} // [['--help', '-h', '-?']];

      CO:
        for my $co (@$special_opts, @$common_opts) {
            if (ref($co) eq 'ARRAY') {
                for (@$co) { next CO if $_ ~~ @$words || $_ ~~ @words }
                push @words, @$co;
            } else {
                push @words, $co unless $co ~~ @$words || $co ~~ @words;
            }
        }

        return complete_array(word=>$word, array=>\@words);

    } else {

        # fallback
        return complete_file(word=>$word);

    }
}

1;
# ABSTRACT: Shell completion routines using Rinci metadata

=for Pod::Coverage ^(.+)$

=head1 SYNOPSIS

 # require'd by Perinci::CmdLine when shell completion is enabled


=head1 DESCRIPTION

This module provides functionality for doing shell completion. It is meant to be
used by L<Perinci::CmdLine>, but nevertheless some routines are reusable outside
it.


=head1 BUGS/LIMITATIONS/TODOS

Due to parsing limitation (invokes subshell), can't complete unclosed quotes,
e.g.

 foo "bar <tab>

while shell function can complete this because they are provided C<COMP_WORDS>
and C<COMP_CWORD> by bash.


=head1 SEE ALSO

L<Perinci::CmdLine>

Other shell completion modules on CPAN: L<Getopt::Complete>,
L<Bash::Completion>.

=cut
