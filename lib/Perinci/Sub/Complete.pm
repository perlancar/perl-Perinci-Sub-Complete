package Perinci::Sub::Complete;

# DATE
# VERSION

use 5.010001;
use strict;
use warnings;
use experimental 'smartmatch';
use Log::Any '$log';

use Complete::Util qw(hashify_answer complete_array_elem);
use Perinci::Sub::Util qw(gen_modified_sub);

require Exporter;
our @ISA       = qw(Exporter);
our @EXPORT_OK = qw(
                       complete_from_schema
                       complete_arg_val
                       complete_arg_elem
                       complete_cli_arg
               );
our %SPEC;

$SPEC{':package'} = {
    v => 1.1,
    summary => 'Complete command-line argument using Rinci metadata',
};

my %common_args_riap = (
    riap_client => {
        summary => 'Optional, to perform complete_arg_val to the server',
        schema  => 'obj*',
        description => <<'_',

When the argument spec in the Rinci metadata contains `completion` key, this
means there is custom completion code for that argument. However, if retrieved
from a remote server, sometimes the `completion` key no longer contains the code
(it has been cleansed into a string). Moreover, the completion code needs to run
on the server.

If supplied this argument and te `riap_server_url` argument, the function will
try to request to the server (via Riap request `complete_arg_val`). Otherwise,
the function will just give up/decline completing.

_
        },
    riap_server_url => {
        summary => 'Optional, to perform complete_arg_val to the server',
        schema  => 'str*',
        description => <<'_',

See the `riap_client` argument.

_
    },
    riap_uri => {
        summary => 'Optional, to perform complete_arg_val to the server',
        schema  => 'str*',
        description => <<'_',

See the `riap_client` argument.

_
    },
);

$SPEC{complete_from_schema} = {
    v => 1.1,
    summary => 'Complete a value from schema',
    description => <<'_',

Employ some heuristics to complete a value from Sah schema. For example, if
schema is `[str => in => [qw/new open resolved rejected/]]`, then we can
complete from the `in` clause. Or for something like `[int => between => [1,
20]]` we can complete using values from 1 to 20.

_
    args => {
        schema => {
            summary => 'Must be normalized',
            req => 1,
        },
        word => {
            schema => [str => default => ''],
            req => 1,
        },
        ci => {
            schema => 'bool',
        },
    },
};
sub complete_from_schema {
    my %args = @_;
    my $sch  = $args{schema}; # must be normalized
    my $word = $args{word} // "";
    my $ci   = $args{ci};

    my $fres;
    $log->tracef("[comp][periscomp] entering complete_from_schema, word=<%s>, schema=%s", $word, $sch);

    my ($type, $cs) = @{$sch};

    my $static;
    my $words;
    eval {
        if ($cs->{is} && !ref($cs->{is})) {
            $log->tracef("[comp][periscomp] adding completion from 'is' clause");
            push @$words, $cs->{is};
            $static++;
            return; # from eval. there should not be any other value
        }
        if ($cs->{in}) {
            $log->tracef("[comp][periscomp] adding completion from 'in' clause");
            push @$words, grep {!ref($_)} @{ $cs->{in} };
            $static++;
            return; # from eval. there should not be any other value
        }
        if ($type =~ /\Abool\*?\z/) {
            $log->tracef("[comp][periscomp] adding completion from possible values of bool");
            push @$words, 0, 1;
            $static++;
            return; # from eval
        }
        if ($type =~ /\Aint\*?\z/) {
            my $limit = 100;
            if ($cs->{between} &&
                    $cs->{between}[0] - $cs->{between}[0] <= $limit) {
                $log->tracef("[comp][periscomp] adding completion from 'between' clause");
                push @$words, $cs->{between}[0] .. $cs->{between}[1];
                $static++;
            } elsif ($cs->{xbetween} &&
                         $cs->{xbetween}[0] - $cs->{xbetween}[0] <= $limit) {
                $log->tracef("[comp][periscomp] adding completion from 'xbetween' clause");
                push @$words, $cs->{xbetween}[0]+1 .. $cs->{xbetween}[1]-1;
                $static++;
            } elsif (defined($cs->{min}) && defined($cs->{max}) &&
                         $cs->{max}-$cs->{min} <= $limit) {
                $log->tracef("[comp][periscomp] adding completion from 'min' & 'max' clauses");
                push @$words, $cs->{min} .. $cs->{max};
                $static++;
            } elsif (defined($cs->{min}) && defined($cs->{xmax}) &&
                         $cs->{xmax}-$cs->{min} <= $limit) {
                $log->tracef("[comp][periscomp] adding completion from 'min' & 'xmax' clauses");
                push @$words, $cs->{min} .. $cs->{xmax}-1;
                $static++;
            } elsif (defined($cs->{xmin}) && defined($cs->{max}) &&
                         $cs->{max}-$cs->{xmin} <= $limit) {
                $log->tracef("[comp][periscomp] adding completion from 'xmin' & 'max' clauses");
                push @$words, $cs->{xmin}+1 .. $cs->{max};
                $static++;
            } elsif (defined($cs->{xmin}) && defined($cs->{xmax}) &&
                         $cs->{xmax}-$cs->{xmin} <= $limit) {
                $log->tracef("[comp][periscomp] adding completion from 'xmin' & 'xmax' clauses");
                push @$words, $cs->{xmin}+1 .. $cs->{xmax}-1;
                $static++;
            } elsif (length($word) && $word !~ /\A-?\d*\z/) {
                $log->tracef("[comp][periscomp] word not an int");
                $words = [];
            } else {
                # do a digit by digit completion
                $words = [];
                for my $sign ("", "-") {
                    for ("", 0..9) {
                        my $i = $sign . $word . $_;
                        next unless length $i;
                        next unless $i =~ /\A-?\d+\z/;
                        next if $i eq '-0';
                        next if $i =~ /\A-?0\d/;
                        next if $cs->{between} &&
                            ($i < $cs->{between}[0] ||
                                 $i > $cs->{between}[1]);
                        next if $cs->{xbetween} &&
                            ($i <= $cs->{xbetween}[0] ||
                                 $i >= $cs->{xbetween}[1]);
                        next if defined($cs->{min} ) && $i <  $cs->{min};
                        next if defined($cs->{xmin}) && $i <= $cs->{xmin};
                        next if defined($cs->{max} ) && $i >  $cs->{max};
                        next if defined($cs->{xmin}) && $i >= $cs->{xmax};
                        push @$words, $i;
                    }
                }
                $words = [sort @$words];
            }
            return; # from eval
        }
        if ($type =~ /\Afloat\*?\z/) {
            if (length($word) && $word !~ /\A-?\d*(\.\d*)?\z/) {
                $log->tracef("[comp][periscomp] word not a float");
                $words = [];
            } else {
                $words = [];
                for my $sig ("", "-") {
                    for ("", 0..9,
                         ".0",".1",".2",".3",".4",".5",".6",".7",".8",".9") {
                        my $f = $sig . $word . $_;
                        next unless length $f;
                        next unless $f =~ /\A-?\d+(\.\d+)?\z/;
                        next if $f eq '-0';
                        next if $f =~ /\A-?0\d\z/;
                        next if $cs->{between} &&
                            ($f < $cs->{between}[0] ||
                                 $f > $cs->{between}[1]);
                        next if $cs->{xbetween} &&
                            ($f <= $cs->{xbetween}[0] ||
                                 $f >= $cs->{xbetween}[1]);
                        next if defined($cs->{min} ) && $f <  $cs->{min};
                        next if defined($cs->{xmin}) && $f <= $cs->{xmin};
                        next if defined($cs->{max} ) && $f >  $cs->{max};
                        next if defined($cs->{xmin}) && $f >= $cs->{xmax};
                        push @$words, $f;
                    }
                }
            }
            return; # from eval
        }
    }; # eval

    goto RETURN_RES unless $words;
    $fres = hashify_answer(
        complete_array_elem(array=>$words, word=>$word, ci=>$ci),
        {static=>$static && $word eq '' ? 1:0},
    );

  RETURN_RES:
    $log->tracef("[comp][periscomp] leaving complete_from_schema, result=%s", $fres);
    $fres;
}

$SPEC{complete_arg_val} = {
    v => 1.1,
    summary => 'Given argument name and function metadata, complete value',
    description => <<'_',

Will attempt to complete using the completion routine specified in the argument
specification (the `completion` property, or in the case of `complete_arg_elem`
function, the `element_completion` property), or if that is not specified, from
argument's schema using `complete_from_schema`.

Completion routine will get `%args`, with the following keys:

* `word` (str, the word to be completed)
* `ci` (bool, whether string matching should be case-insensitive)
* `arg` (str, the argument name which value is currently being completed)
* `index (int, only for the `complete_arg_elem` function, the index in the
   argument array that is currently being completed, starts from 0)
* `args` (hash, the argument hash to the function, so far)

as well as extra keys from `extras` (but these won't overwrite the above
standard keys).

Completion routine should return a completion answer structure (described in
`Complete`) which is either a hash or an array. The simplest form of answer is
just to return an array of strings. Completion routine can also return undef to
express declination.

_
    args => {
        meta => {
            summary => 'Rinci function metadata, must be normalized',
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
        args => {
            summary => 'Collected arguments so far, '.
                'will be passed to completion routines',
            schema  => 'hash',
        },
        extras => {
            summary => 'Add extra arguments to completion routine',
            schema  => 'hash',
            description => <<'_',

The keys from this `extras` hash will be merged into the final `%args` passed to
completion routines. Note that standard keys like `word`, `cword`, `ci`, and so
on as described in the function description will not be overwritten by this.

_
        },

        %common_args_riap,
    },
    result_naked => 1,
    result => {
        schema => 'array', # XXX of => str*
    },
};
sub complete_arg_val {
    my %args = @_;

    $log->tracef("[comp][periscomp] entering complete_arg_val, arg=<%s>", $args{arg});
    my $fres;

    my $extras = $args{extras} // {};

    my $meta = $args{meta} or do {
        $log->tracef("[comp][periscomp] meta is not supplied, declining");
        goto RETURN_RES;
    };
    my $arg  = $args{arg} or do {
        $log->tracef("[comp][periscomp] arg is not supplied, declining");
        goto RETURN_RES;
    };
    my $ci   = $args{ci} // 0;
    my $word = $args{word} // '';

    # XXX reject if meta's v is not 1.1

    my $args_p = $meta->{args} // {};
    my $arg_p = $args_p->{$arg} or do {
        $log->tracef("[comp][periscomp] arg '$arg' is not specified in meta, declining");
        goto RETURN_RES;
    };

    my $static;
    eval { # completion sub can die, etc.

        my $comp = $arg_p->{completion};
        if ($comp) {
            if (ref($comp) eq 'CODE') {
                $log->tracef("[comp][periscomp] invoking routine specified in arg spec's 'completion' property");
                $fres = $comp->(
                    %$extras,
                    word=>$word, ci=>$ci, arg=>$arg, args=>$args{args});
                return; # from eval
            } elsif (ref($comp) eq 'ARRAY') {
                $log->tracef("[comp][periscomp] using array specified in arg spec's 'completion' property: %s", $comp);
                $fres = complete_array_elem(
                    array=>$comp, word=>$word, ci=>$ci);
                $static++;
                return; # from eval
            }

            $log->tracef("[comp][periscomp] arg spec's 'completion' property is not a coderef or arrayref");
            if ($args{riap_client} && $args{riap_server_url}) {
                $log->tracef("[comp][periscomp] trying to perform complete_arg_val request to Riap server");
                my $res = $args{riap_client}->request(
                    complete_arg_val => $args{riap_server_url},
                    {(uri=>$args{riap_uri}) x !!defined($args{riap_uri}),
                     arg=>$arg, word=>$word, ci=>$ci},
                );
                if ($res->[0] != 200) {
                    $log->tracef("[comp][periscomp] Riap request failed (%s), declining", $res);
                    return; # from eval
                }
                $fres = $res->[2];
                return; # from eval
            }

            $log->tracef("[comp][periscomp] declining");
            return; # from eval
        }

        my $sch = $arg_p->{schema};
        unless ($sch) {
            $log->tracef("[comp][periscomp] arg spec does not specify schema, declining");
            return; # from eval
        };

        # XXX normalize schema if not normalized

        $fres = complete_from_schema(schema=>$sch, word=>$word, ci=>$ci);
    };
    $log->debug("[comp][periscomp] completion died: $@") if $@;
    unless ($fres) {
        $log->tracef("[comp][periscomp] no completion from metadata possible, declining");
        goto RETURN_RES;
    }

    $fres = hashify_answer($fres);
    $fres->{static} //= $static && $word eq '' ? 1:0;
  RETURN_RES:
    $log->tracef("[comp][periscomp] leaving complete_arg_val, result=%s", $fres);
    $fres;
}

gen_modified_sub(
    output_name  => 'complete_arg_elem',
    install_sub  => 0,
    base_name    => 'complete_arg_val',
    summary      => 'Given argument name and function metadata, '.
        'complete array element',
    add_args     => {
        index => {
            summary => 'Index of element to complete',
            schema  => [int => min => 0],
        },
    },
);
sub complete_arg_elem {
    require Data::Sah::Normalize;

    my %args = @_;

    my $fres;

    $log->tracef("[comp][periscomp] entering complete_arg_elem, arg=<%s>, index=<%d>",
                 $args{arg}, $args{index});

    my $extras = $args{extras} // {};

    my $ourextras = {arg=>$args{arg}, args=>$args{args}};

    my $meta = $args{meta} or do {
        $log->tracef("[comp][periscomp] meta is not supplied, declining");
        goto RETURN_RES;
    };
    my $arg  = $args{arg} or do {
        $log->tracef("[comp][periscomp] arg is not supplied, declining");
        goto RETURN_RES;
    };
    defined(my $index = $args{index}) or do {
        $log->tracef("[comp][periscomp] index is not supplied, declining");
        goto RETURN_RES;
    };
    my $ci   = $args{ci} // 0;
    my $word = $args{word} // '';

    # XXX reject if meta's v is not 1.1

    my $args_p = $meta->{args} // {};
    my $arg_p = $args_p->{$arg} or do {
        $log->tracef("[comp][periscomp] arg '$arg' is not specified in meta, declining");
        goto RETURN_RES;
    };

    my $static;
    eval { # completion sub can die, etc.

        my $elcomp = $arg_p->{element_completion};
        $ourextras->{index} = $index;
        if ($elcomp) {
            if (ref($elcomp) eq 'CODE') {
                $log->tracef("[comp][periscomp] invoking routine specified in arg spec's 'element_completion' property");
                $fres = $elcomp->(
                    %$extras,
                    %$ourextras,
                    word=>$word, ci=>$ci);
                return; # from eval
            } elsif (ref($elcomp) eq 'ARRAY') {
                $log->tracef("[comp][periscomp] using array specified in arg spec's 'element_completion' property: %s", $elcomp);
                $fres = complete_array_elem(
                    array=>$elcomp, word=>$word, ci=>$ci);
                $static = $word eq '';
            }

            $log->tracef("[comp][periscomp] arg spec's 'element_completion' property is not a coderef or ".
                             "arrayref");
            if ($args{riap_client} && $args{riap_server_url}) {
                $log->tracef("[comp][periscomp] trying to perform complete_arg_elem request to Riap server");
                my $res = $args{riap_client}->request(
                    complete_arg_elem => $args{riap_server_url},
                    {(uri=>$args{riap_uri}) x !!defined($args{riap_uri}),
                     arg=>$arg, args=>$args{args}, word=>$word, ci=>$ci,
                     index=>$index},
                );
                if ($res->[0] != 200) {
                    $log->tracef("[comp][periscomp] Riap request failed (%s), declining", $res);
                    return; # from eval
                }
                $fres = $res->[2];
                return; # from eval
            }

            $log->tracef("[comp][periscomp] declining");
            return; # from eval
        }

        my $sch = $arg_p->{schema};
        unless ($sch) {
            $log->tracef("[comp][periscomp] arg spec does not specify schema, declining");
            return; # from eval
        };

        # XXX normalize if not normalized

        my ($type, $cs) = @{ $sch };
        if ($type ne 'array') {
            $log->tracef("[comp][periscomp] can't complete element for non-array");
            return; # from eval
        }

        unless ($cs->{of}) {
            $log->tracef("[comp][periscomp] schema does not specify 'of' clause, declining");
            return; # from eval
        }

        # normalize subschema because normalize_schema (as of 0.01) currently
        # does not do it yet
        my $elsch = Data::Sah::Normalize::normalize_schema($cs->{of});

        $fres = complete_from_schema(schema=>$elsch, word=>$word, ci=>$ci);
    };
    $log->debug("[comp][periscomp] completion died: $@") if $@;
    unless ($fres) {
        $log->tracef("[comp][periscomp] no completion from metadata possible, declining");
        goto RETURN_RES;
    }

    $fres = hashify_answer($fres);
    $fres->{static} //= $static && $word eq '' ? 1:0;
  RETURN_RES:
    $log->tracef("[comp][periscomp] leaving complete_arg_elem, result=%s", $fres);
    $fres;
}

$SPEC{complete_cli_arg} = {
    v => 1.1,
    summary => 'Complete command-line argument using Rinci function metadata',
    description => <<'_',

This routine uses `Perinci::Sub::GetArgs::Argv` to generate `Getopt::Long`
specification from arguments list in Rinci function metadata and common options.
Then, it will use `Complete::Getopt::Long` to complete option names, option
values, as well as arguments.

_
    args => {
        meta => {
            summary => 'Rinci function metadata',
            schema => 'hash*',
            req => 1,
        },
        words => {
            summary => 'Command-line arguments',
            schema => ['array*' => {of=>'str*'}],
            req => 1,
        },
        cword => {
            summary => 'On which argument cursor is located (zero-based)',
            schema => 'int*',
            req => 1,
        },
        completion => {
            summary => 'Supply custom completion routine',
            description => <<'_',

If supplied, instead of the default completion routine, this code will be called
instead. Will receive all arguments that `Complete::Getopt::Long` will pass, and
additionally:

* `arg` (str, the name of function argument)
* `args` (hash, the function arguments formed so far)
* `index` (int, if completing argument element value)

_
            schema => 'code*',
        },
        per_arg_json => {
            summary => 'Will be passed to Perinci::Sub::GetArgs::Argv',
            schema  => 'bool',
        },
        per_arg_yaml => {
            summary => 'Will be passed to Perinci::Sub::GetArgs::Argv',
            schema  => 'bool',
        },
        common_opts => {
            summary => 'Common options',
            description => <<'_',

A hash where the values are hashes containing these keys: `getopt` (Getopt::Long
option specification), `handler` (Getopt::Long handler). Will be passed to
`get_args_from_argv()`. Example:

    {
        help => {
            getopt  => 'help|h|?',
            handler => sub { ... },
            summary => 'Display help and exit',
        },
        version => {
            getopt  => 'version|v',
            handler => sub { ... },
            summary => 'Display version and exit',
        },
    }

_
            schema => ['hash*'],
        },
        extras => {
            summary => 'Add extra arguments to completion routine',
            schema  => 'hash',
            description => <<'_',

The keys from this `extras` hash will be merged into the final `%args` passed to
completion routines. Note that standard keys like `word`, `cword`, `ci`, and so
on as described in the function description will not be overwritten by this.

_
        },
        %common_args_riap,
    },
    result_naked => 1,
    result => {
        schema => 'hash*',
        description => <<'_',

You can use `format_completion` function in `Complete::Bash` module to format
the result of this function for bash.

_
    },
};
sub complete_cli_arg {
    require Complete::Getopt::Long;
    require Perinci::Sub::GetArgs::Argv;

    my %args   = @_;
    my $meta   = $args{meta} or die "Please specify meta";
    my $words  = $args{words} or die "Please specify words";
    my $cword  = $args{cword}; defined($cword) or die "Please specify cword";
    my $copts  = $args{common_opts} // {};
    my $comp   = $args{completion};
    my $extras = {
        %{ $args{extras} // {} },
        words => $args{words},
        cword => $args{cword},
    };

    my $fname = __PACKAGE__ . "::complete_cli_arg"; # XXX use __SUB__
    my $fres;

    my $word   = $words->[$cword];
    my $args_p = $meta->{args} // {};

    $log->tracef('[comp][periscomp] entering %s(), words=%s, cword=%d, word=<%s>',
                 $fname, $words, $cword, $word);

    my $genres = Perinci::Sub::GetArgs::Argv::gen_getopt_long_spec_from_meta(
        meta         => $meta,
        common_opts  => $copts,
        per_arg_json => $args{per_arg_json},
        per_arg_yaml => $args{per_arg_yaml},
        ignore_converted_code => 1,
    );
    die "Can't generate getopt spec from meta: $genres->[0] - $genres->[1]"
        unless $genres->[0] == 200;
    my $gospec = $genres->[2];
    my $specmeta = $genres->[3]{'func.specmeta'};

    my $gares = Perinci::Sub::GetArgs::Argv::get_args_from_argv(
        argv   => [@$words],
        meta   => $meta,
        strict => 0,
    );

    my $copts_by_ospec = {};
    for (keys %$copts) { $copts_by_ospec->{$copts->{$_}{getopt}}=$copts->{$_} }

    my $compgl_comp = sub {
        $log->tracef("[comp][periscomp] entering completion routine (that we supply to Complete::Getopt::Long)");
        my %cargs = @_;
        my $type  = $cargs{type};
        my $ospec = $cargs{ospec} // '';
        my $word  = $cargs{word};
        my $ci    = $cargs{ci};

        my $fres;

        my %rargs = (
            riap_server_url => $args{riap_server_url},
            riap_uri        => $args{riap_uri},
            riap_client     => $args{riap_client},
        );

        if (my $sm = $specmeta->{$ospec}) {
            $cargs{type} = 'optval';
            if ($sm->{arg}) {
                $log->tracef("[comp][periscomp] completing option value for a known function argument, arg=<%s>, ospec=<%s>", $sm->{arg}, $ospec);
                $cargs{arg} = $sm->{arg};
                my $as = $args_p->{$sm->{arg}} or goto RETURN_RES;
                if ($comp) {
                    $log->tracef("[comp][periscomp] invoking routine supplied from 'completion' argument");
                    my $compres;
                    eval { $compres = $comp->(%cargs) };
                    $log->debug("[comp][periscomp] completion died: $@") if $@;
                    $log->tracef("[comp][periscomp] result from 'completion' routine: %s", $compres);
                    if ($compres) {
                        $fres = $compres;
                        goto RETURN_RES;
                    }
                }
                if ($ospec =~ /\@$/) {
                    $fres = complete_arg_elem(
                        meta=>$meta, arg=>$sm->{arg}, args=>$gares->[2],
                        word=>$word, index=>$cargs{nth}, # XXX correct index
                        extras=>$extras, %rargs);
                    goto RETURN_RES;
                } else {
                    $fres = complete_arg_val(
                        meta=>$meta, arg=>$sm->{arg}, args=>$gares->[2],
                        word=>$word, extras=>$extras, %rargs);
                    goto RETURN_RES;
                }
            } else {
                $log->tracef("[comp][periscomp] completing option value for a common option, ospec=<%s>", $ospec);
                $cargs{arg}  = undef;
                my $codata = $copts_by_ospec->{$ospec};
                if ($comp) {
                    $log->tracef("[comp][periscomp] invoking routine supplied from 'completion' argument");
                    my $res;
                    eval { $res = $comp->(%cargs) };
                    $log->debug("[comp][periscomp] completion died: $@") if $@;
                    if ($res) {
                        $fres = $res;
                        goto RETURN_RES;
                    }
                }
                if ($codata->{completion}) {
                    $cargs{arg}  = undef;
                    $log->tracef("[comp][periscomp] completing with common option's 'completion' property");
                    my $res;
                    eval { $res = $codata->{completion}->(%cargs) };
                    $log->debug("[comp][periscomp] completion died: $@") if $@;
                    if ($res) {
                        $fres = $res;
                        goto RETURN_RES;
                    }
                }
                if ($codata->{schema}) {
                    require Data::Sah::Normalize;
                    my $nsch = Data::Sah::Normalize::normalize_schema(
                        $codata->{schema});
                    $log->tracef("[comp][periscomp] completing with common option's schema");
                    $fres = complete_from_schema(
                        schema => $nsch, word=>$word, ci=>$ci);
                    goto RETURN_RES;
                }
                goto RETURN_RES;
            }
        } elsif ($type eq 'arg') {
            $log->tracef("[comp][periscomp] completing argument #%d", $cargs{argpos});
            $cargs{type} = 'arg';

            my $pos = $cargs{argpos};

            # find if there is a non-greedy argument with the exact position
            for my $an (keys %$args_p) {
                my $as = $args_p->{$an};
                next unless !$as->{greedy} &&
                    defined($as->{pos}) && $as->{pos} == $pos;
                $log->tracef("[comp][periscomp] this argument position is for non-greedy function argument <%s>", $an);
                $cargs{arg} = $an;
                if ($comp) {
                    $log->tracef("[comp][periscomp] invoking routine supplied from 'completion' argument");
                    my $res;
                    eval { $res = $comp->(%cargs) };
                    $log->debug("[comp][periscomp] completion died: $@") if $@;
                    if ($res) {
                        $fres = $res;
                        goto RETURN_RES;
                    }
                }
                $fres = complete_arg_val(
                    meta=>$meta, arg=>$an, args=>$gares->[2],
                    word=>$word, extras=>$extras, %rargs);
                goto RETURN_RES;
            }

            # find if there is a greedy argument which takes elements at that
            # position
            for my $an (sort {
                ($args_p->{$b}{pos} // 9999) <=> ($args_p->{$a}{pos} // 9999)
            } keys %$args_p) {
                my $as = $args_p->{$an};
                next unless $as->{greedy} &&
                    defined($as->{pos}) && $as->{pos} <= $pos;
                my $index = $pos - $as->{pos};
                $cargs{arg} = $an;
                $cargs{index} = $index;
                $log->tracef("[comp][periscomp] this position is for greedy function argument <%s>'s element[%d]", $an, $index);
                if ($comp) {
                    $log->tracef("[comp][periscomp] invoking routine supplied from 'completion' argument");
                    my $res;
                    eval { $res = $comp->(%cargs) };
                    $log->debug("[comp][periscomp] completion died: $@") if $@;
                    if ($res) {
                        $fres = $res;
                        goto RETURN_RES;
                    }
                }
                $fres = complete_arg_elem(
                    meta=>$meta, arg=>$an, args=>$gares->[2],
                    word=>$word, index=>$index, extras=>$extras, %rargs);
                goto RETURN_RES;
            }

            $log->tracef("[comp][periscomp] there is no matching function argument at this position");
            if ($comp) {
                $log->tracef("[comp][periscomp] invoking routine supplied from 'completion' argument");
                my $res;
                eval { $res = $comp->(%cargs) };
                $log->debug("[comp][periscomp] completion died: $@") if $@;
                if ($res) {
                    $fres = $res;
                    goto RETURN_RES;
                }
            }
            goto RETURN_RES;
        } else {
            $log->tracef("[comp][periscomp] completing option value for an unknown/ambiguous option, declining ...");
            # decline because there's nothing in Rinci metadata that can aid us
            goto RETURN_RES;
        }
      RETURN_RES:
        $log->tracef("[comp][periscomp] leaving completion routine (that we supply to Complete::Getopt::Long)");
        $fres;
    }; # completion routine

    $fres = Complete::Getopt::Long::complete_cli_arg(
        getopt_spec => $gospec,
        words       => $words,
        cword       => $cword,
        completion  => $compgl_comp,
        extras      => $extras,
    );

  RETURN_RES:
    $log->tracef('[comp][periscomp] leaving %s(), result=%s',
                 $fname, $fres);
    $fres;
}

1;
# ABSTRACT:

=for Pod::Coverage ^(.+)$

=head1 SYNOPSIS

See L<Perinci::CmdLine> or L<Perinci::CmdLine::Lite> or L<App::riap> which use
this module.


=head1 DESCRIPTION


=head1 SEE ALSO

L<Complete>, L<Complete::Getopt::Long>

L<Perinci::CmdLine>, L<Perinci::CmdLine::Lite>, L<App::riap>

=cut
