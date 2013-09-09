package Perinci::BashComplete;

use 5.010001;
use strict;
use warnings;
use experimental 'smartmatch';
use Log::Any '$log';

# VERSION

require Exporter;
our @ISA       = qw(Exporter);
our @EXPORT_OK = qw(
                       complete_array
                       complete_hash_key
                       complete_env
                       complete_file
                       complete_program
                       complete_riap_func

                       bash_complete_riap_func_arg
               );
our %SPEC;

# current problems: Can't parse unclosed quotes (e.g. spanel get-plan "BISNIS
# A<tab>) and probably other problems, since we don't have access to COMP_WORDS
# like in shell functions.
sub _line_to_argv {
    require IPC::Open2;

    my $line = pop;
    my $cmd = q{_pbc() { for a in "$@"; do echo "$a"; done }; _pbc } . $line;
    my ($reader, $writer);
    my $pid = IPC::Open2::open2($reader,$writer,'bash 2>/dev/null');
    print $writer $cmd;
    close $writer;
    my @array = map {chomp;$_} <$reader>;

    # We don't want to expand ~ for user experience and to be consistent with
    # Bash's behavior for tab completion (as opposed to expansion of ARGV).
    my $home_dir = (getpwuid($<))[7];
    @array = map { s!\A\Q$home_dir\E(/|\z)!\~$1!; $_ } @array;

    return @array;
}

# simplistic parsing, doesn't consider shell syntax at all. doesn't work the
# minute we use funny characters.
#sub _line_to_argv_BC {
#    split(/\h+/, $_[0]);
#}

# parse COMP_LINE and COMP_POINT
sub _parse_request {
    my ($line, $point, $opts) = @_;
    $log->tracef("-> _parse_request(%s, %s)", $line, $point);
    $opts //= {};
    $opts->{parse_line_sub} //= \&_line_to_argv;


    $line  //= $ENV{COMP_LINE};
    $point //= $ENV{COMP_POINT};
    $log->tracef("line=q(%s), point=%s", $line, $point);

    my $left  = substr($line, 0, $point);
    my @left;
    if (length($left)) {
        @left = $opts->{parse_line_sub}->($left);
        # shave off $0
        substr($left, 0, length($left[0])) = "";
        $left =~ s/^\s+//;
        shift @left;
    }

    my $right = substr($line, $point);
    my @right;
    if (length($right)) {
        $right =~ s/^\S+//;
        @right = $opts->{parse_line_sub}->($right) if length($right);
    }
    $log->tracef("left=q(%s), \@left=%s, right=q(%s), \@right=%s",
                 $left, \@left, $right, \@right);

    my $words = [@left, @right],
    my $cword = @left ? scalar(@left)-1 : 0;

    # is there a space after the final word (e.g. "foo bar ^" instead of "foo
    # bar^" or "foo bar\ ^")? if yes then cword is on the next word.
    my $tmp = $left;
    my $nspc_left = 0; $nspc_left++ while $tmp =~ s/\s$//;
    $tmp = $left[-1];
    my $nspc_lastw = 0;
    if (defined($tmp)) { $nspc_lastw++ while $tmp =~ s/\s$// }
    $cword++ if $nspc_lastw < $nspc_left;

    my $res = {words => $words, cword => $cword};
    $log->tracef("<- _parse_request, result=%s", $res);
    $res;
}

sub _add_slashes {
    my ($a) = @_;
    $a =~ s!([^A-Za-z0-9,+._/:-])!\\$1!g;
    $a;
}

$SPEC{complete_array} = {
    v => 1.1,
    args => {
        array => { schema=>['array*'=>{of=>'str*'}], pos=>0, req=>1 },
        word  => { schema=>[str=>{default=>''}], pos=>1 },
        ci    => { schema=>[bool=>{default=>0}] },
    },
    result_naked => 1,
};
sub complete_array {
    my %args  = @_;
    $log->tracef("=> complete_array(%s)", \%args);
    my $array = $args{array} or die "Please specify array";
    my $word  = $args{word} // "";
    my $ci    = $args{ci};

    my $wordu = uc($word);
    my @words;
    for (@$array) {
        next unless 0==($ci ? index(uc($_), $wordu) : index($_, $word));
        push @words, $_;
    }
    $ci ? [sort {lc($a) cmp lc($b)} @words] : [sort @words];
}

$SPEC{complete_hash_key} = {
    v => 1.1,
    args => {
        hash  => { schema=>['hash*'=>{}], pos=>0, req=>1 },
        word  => { schema=>[str=>{default=>''}], pos=>1 },
        ci    => { schema=>[bool=>{default=>0}] },
    },
    result_naked => 1,
};
sub complete_hash_key {
    my %args  = @_;
    $log->tracef("=> complete_hash_key(%s)", \%args);
    my $hash  = $args{hash} or die "Please specify hash";
    my $word  = $args{word} // "";
    my $ci    = $args{ci};

    complete_array(word=>$word, array=>[keys %$hash], ci=>$ci);
}

$SPEC{complete_env} = {
    v => 1.1,
    args => {
        word  => { schema=>[str=>{default=>''}], pos=>0 },
        ci    => { schema=>[bool=>{default=>0}] },
    },
    result_naked => 1,
};
sub complete_env {
    my %args  = @_;
    $log->tracef("=> complete_env(%s)", \%args);
    my $word  = $args{word} // "";
    my $ci    = $args{ci};
    if ($word =~ /^\$/) {
        complete_array(word=>$word, array=>[map {"\$$_"} keys %ENV], ci=>$ci);
    } else {
        complete_array(word=>$word, array=>[keys %ENV], ci=>$ci);
    }
}

$SPEC{complete_program} = {
    v => 1.1,
    args => {
        word  => { schema=>[str=>{default=>''}], pos=>0 },
    },
    result_naked => 1,
};
sub complete_program {
    require List::MoreUtils;

    my %args  = @_;
    $log->tracef("=> complete_program(%s)", \%args);
    my $word  = $args{word} // "";

    my @words;
    my @dir;
    my $word_has_path;
    $word =~ m!(.*)/(.*)! and do { @dir = ($1); $word_has_path++; $word = $2 };
    @dir = split /:/, $ENV{PATH} unless @dir;
    unshift @dir, ".";
    for my $dir (@dir) {
        $dir =~ s!/+$!!; #TEST
        opendir my($dh), $dir or next;
        for (readdir($dh)) {
            next if $word !~ /^\.\.?$/ && ($_ eq '.' || $_ eq '..');
            next unless index($_, $word) == 0;
            next unless (-x "$dir/$_") && (-f _) ||
                ($dir eq '.' || $word_has_path) && (-d _);
            push @words, (-d _) ? "$_/" : $_;
        };
    }

    complete_array(array=>[List::MoreUtils::uniq(@words)]);
}

$SPEC{complete_file} = {
    v => 1.1,
    args => {
        word => { schema=>[str=>{default=>''}], pos=>0 },
        f    => { summary => 'Whether to include file',
                  schema=>[bool=>{default=>1}] },
        d    => { summary => 'Whether to include directory',
                  schema=>[bool=>{default=>1}] },
    },
    result_naked => 1,
};
sub complete_file {
    my %args  = @_;
    $log->tracef("=> complete_file(%s)", \%args);
    my $word  = $args{word} // "";
    my $f     = $args{f} // 1;
    my $d     = $args{d} // 1;

    my @all;
    if ($word =~ m!(\A|/)\z!) {
        my $dir = length($word) ? $word : ".";
        opendir my($dh), $dir or return [];
        @all = map { ($dir eq '.' ? '' : $dir) . $_ }
            grep { $_ ne '.' && $_ ne '..' } readdir($dh);
        closedir $dh;
    } else {
        # must add wildcard char, glob() is convoluted. also {a,b} is
        # interpreted by glob() (not so by bash file completion). also
        # whitespace is interpreted by glob :(. later should replace with a
        # saner one, like wildcard2re.
        @all = glob("$word*");
    }

    my @words;
    for (@all) {
        next if (-f $_) && !$f;
        next if (-d _ ) && !$d;
        $_ = "$_/" if (-d _) && !m!/\z!;
        #s!.+/(.+)!$1!;
        push @words, $_;
    }

    my $w = complete_array(array=>\@words);

    # this is a trick so that when completion is a single dir/, bash does not
    # insert a space but still puts the cursor after "/", just like when it's
    # doing dir completion.
    if (@$w == 1 && $w->[0] =~ m!/\z!) { $w->[1] = "$w->[0] ";  }

    $w;
}

sub _get_pa {
    my ($pa) = @_;
    state $default_pa;

    if (!$pa) {
        if (!$default_pa) {
            require Perinci::Access;
            $default_pa = Perinci::Access->new;
        }
        $pa = $default_pa;
    }
    $pa;
}

# XXX configurable path separator other than "."
$SPEC{complete_riap_func} = {
    v => 1.1,
    summary => 'Complete function name from Riap server',
    description => <<'_',

Will try to complete word as dotted path from the Riap server, e.g.
'Package.SubPackage.function'.

_
    args => {
        base_url => {
            summary => 'Base URL, should point to a package code entity',
            description => <<'_',

Examples would be: '/' (or 'pl:/'), '/Company/API/', 'http://example.com/api/'

_
            schema=>'str*',
            pos=>0, req=>1,
        },
        pa => {
            summary => 'Perinci::Access obj, will use default if unspecified',
            schema  => 'obj',
        },
        word => { schema=>[str=>{default=>''}], pos=>0 },
    },
    result_naked => 1,
};
sub complete_riap_func {
    my %args = @_;
    $log->tracef("=> complete_riap_func(%s)", \%args);
    my $base_url = $args{base_url} or die "Please specify base_url";
    my $word     = $args{word} // "";
    my $pa       = _get_pa($args{pa});

    my $p = $word;
    $p =~ s![^.]+$!!;
    my $p2 = $p;
    $p =~ s!\.!/!g;
    my $url = $base_url . $p;
    my $res = $pa->request(list => $url, {detail=>1});
    unless ($res->[0] == 200) {
        $log->debug("Can't list code entities on $url: $res->[0] - $res->[1]");
        return [];
    }
    my @words = map {
        my $w = $_->{uri};
        if ($w =~ m!/$!) {
            $w =~ s!.+/([^/]+/)$!$1!;
        } else {
            $w =~ s!.+/!!;
        }
        $w =~ s!/!.!g;
        (length($p) ? $p2 : "") . $w
    } grep {$_->{type} =~ /^(?:function|package)$/} @{$res->[2]};
    complete_array(array=>\@words, word=>$word);
}

$SPEC{bash_complete_riap_func_arg} = {
    v => 1.1,
    summary => 'Complete function arguments',
    description => <<'_',

Given a function URL, will try to complete function argument names or values.

Algorithm:

0. If word begins with '$', we complete from environment variables and are done.

1. Retrieve function metadata from URL.

2. Call 'get_args_from_argv()' to extract hash arguments from the given 'words'.

3. Determine whether we need to complete argument name (e.g. '--arg<tab>') or
argument value (e.g. '--arg1 <tab>' or '<tab>' at 1st word where there is an
argument specified at pos=0).

4. Call 'custom_completer' if defined. If a list of words is returned, we're
done.

5. If we are completing argument name, then supply a list of possible argument
names (or fallback to completing filenames).

6. If we are completing argument value, first check if 'custom_arg_completer'
and 'custom_arg_completer' are defined. If yes, call those routines. If a list
of words is returned, we're done.

7.

_
    args => {
        url => {
            summary => 'Function URL',
            description => <<'_',

Examples would be: '/Perinci/Examples/gen_array' (or
'pl:/Perinci/Examples/gen_array') or 'http://example.com/api/some_func'

_
            schema=>'str*',
            pos=>0, req=>1,
        },
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
        pa => {
            summary => 'Perinci::Access obj, will use default if unspecified',
            schema  => 'obj',
        },
        custom_completer => {
            summary => 'Supply custom completion routine',
            description => <<'_',

If supplied, instead of the default completion routine, this code will be called
instead. Refer to function description to see when this routine is called.

Code will be called with a hash argument, with these keys: 'which' (a string
with value 'name' or 'value' depending on whether we should complete argument
name or value), 'words' (an array, the command line split into words), 'cword'
(int, position of word in 'words'), 'word' (the word to be completed),
'parent_args' (hash), 'remaining_words' (array, slice of 'words' after 'cword'),
'meta' (the function metadata retrieved from Riap client).

Code should return an array(ref) of completion, or undef to declare declination,
on which case completion will resume using the standard builtin routine.

_
            schema => 'code',
        },
        custom_arg_completer => {
            summary => 'Supply custom argument value completion routines',
            description => <<'_',

Either code or a hash of argument names and codes.

If supplied, instead of the default completion routine, this code will be called
instead. Refer to function description to see when this routine is called.

Code will be called with hash arguments containing these keys: 'word' (string,
the word to be completed), 'arg' (string, the argument name that we are
completing the value of), 'args' (hash, the arguments that have been collected
so far).

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
sub bash_complete_riap_func_arg {
    require Perinci::Sub::GetArgs::Argv;
    require UUID::Random;

    my %args = @_;
    $log->tracef("=> bash_complete_riap_func_arg(%s)", \%args);
    my $url = $args{url} or die "Please specify url";
    my $words = $args{words};
    my $cword = $args{cword} // 0;
    if (!$words) {
        my $res = _parse_request();
        $words = $res->{words};
        $cword = $res->{cword};
    }
    my $word = $words->[$cword] // "";
    my $pa = _get_pa($args{pa});

    my $res;

    $log->tracef("words=%s, cword=%d, word=%s", $words, $cword, $word);

    if ($word =~ /^\$/) {
        $log->tracef("word begins with \$, completing env vars");
        return complete_env(word=>$word);
    }

    $res = $pa->request(meta => $url);
    unless ($res->[0] == 200) {
        $log->debug("Failed getting meta from $url: $res->[0] - $res->[1]");
        return [];
    }
    my $meta = $res->[2];
    if ((my $v = $meta->{v} // 1.0) != 1.1) {
        $log->debug("Metadata version is not supported ($v), ".
                        "only 1.1 is supported");
        return [];
    }
    my $args_p = $meta->{args};
    unless ($args_p) {
        $log->debug("Metadata does not have 'args' property, is URL a ".
                        "function code entity?");
        return [];
    }

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
        my $res = $args{custom_completer}->(
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
                    return complete_array(
                        word => $word,
                        array => [$cac->{$arg}->(
                            word => $word, arg => $arg, args => $args,
                        )]
                    );
                }
            } else {
                $log->tracef("calling 'custom_arg_completer' (arg=%s)", $arg);
                return complete_array(
                    word  => $word,
                    array => [$cac->(
                        word => $word, arg => $arg, args => $args,
                    )]
                );
            }
        }

        $log->tracef("calling 'complete_arg_val' action on %s", $url);
        $res = $pa->request(complete_arg_val => $url, {arg=>$arg, word=>$word});
        $log->tracef("result from %s: %s", $url, $res);
        my $words;
        if ($res->[0] != 200) {
            $log->debug("Failed requesting complete_arg_val to $url: ".
                            "$res->[0] - $res->[1]");
            $words = [];
        } else {
            $words = $res->[2];
        }

        return $words if @$words;

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
# ABSTRACT: Bash completion routines for function & function argument over Riap

=for Pod::Coverage ^(.+)$

=head1 SYNOPSIS

 # require'd by Perinci::CmdLine when bash completion is enabled


=head1 DESCRIPTION

This module provides functionality for doing bash completion. It is meant to be
used by L<Perinci::CmdLine>, but nevertheless some routines are reusable outside
it.


=head1 FUNCTIONS

None of the functions are exported by default, but they are exportable.


=head1 BUGS/LIMITATIONS/TODOS

Due to parsing limitation (invokes subshell), can't complete unclosed quotes,
e.g.

 foo "bar <tab>

while shell function can complete this because they are provided COMP_WORDS and
COMP_CWORD by bash.


=head1 SEE ALSO

L<Perinci::CmdLine>, L<Riap>

Other bash completion modules on CPAN: L<Getopt::Complete>, L<Bash::Completion>.

=cut
