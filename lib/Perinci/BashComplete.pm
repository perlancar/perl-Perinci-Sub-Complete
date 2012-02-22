package Perinci::BashComplete;

use 5.010;
use strict;
use warnings;
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

# borrowed from Getopt::Complete. current problems: 1) '$foo' disappears because
# shell will substitute it. 2) can't parse if closing quotes have not been
# supplied (e.g. spanel get-plan "BISNIS A<tab>). at least it works with
# backslash escapes.
sub _line_to_argv {
    require IPC::Open2;

    my $line = pop;
    my $cmd = q{perl -e "use Data::Dumper; print Dumper(\@ARGV)" -- } . $line;
    my ($reader,$writer);
    my $pid = IPC::Open2::open2($reader,$writer,'bash 2>/dev/null');
    return unless $pid;
    print $writer $cmd;
    close $writer;
    my $result = join("",<$reader>);
    no strict; no warnings;
    my $array = eval $result;
    my @array = @$array;

    # We don't want to expand ~ for user experience and to be consistent with
    # Bash's behavior for tab completion (as opposed to expansion of ARGV).
    my $home_dir = (getpwuid($<))[7];
    @array = map { $_ =~ s/^$home_dir/\~/; $_ } @array;

    return @array;
}

# simplistic parsing, doesn't consider shell syntax at all. doesn't work the
# minute we use funny characters.
#sub _line_to_argv_BC {
#    split(/\h+/, $_[0]);
#}

# parse COMP_LINE and COMP_POINT
sub _parse_request {
    my ($line, $point) = @_;
    $log->tracef("-> _parse_request(%s, %s)", $line, $point);

    $line  //= $ENV{COMP_LINE};
    $point //= $ENV{COMP_POINT};
    $log->tracef("line=q(%s), point=%s", $line, $point);

    my $left  = substr($line, 0, $point);
    my @left;
    if (length($left)) {
        @left = _line_to_argv($left);
        # shave off $0
        substr($left, 0, length($left[0])) = "";
        $left =~ s/^\s+//;
        shift @left;
    }

    my $right = substr($line, $point);
    my @right;
    if (length($right)) {
        $right =~ s/^\S+//;
        @right = _line_to_argv($right) if length($right);
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
    \@words;
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

    $word =~ s!/+$!!;

    my @words;
    opendir my($dh), "." or return [];
    for (readdir($dh)) {
        next if $word !~ /^\.\.?$/ && ($_ eq '.' || $_ eq '..');
        next unless index($_, $word) == 0;
        next if (-f $_) && !$f;
        next if (-d _ ) && !$d;
        push @words, (-d _) ? "$_/" : $_;
    }

    complete_array(array=>\@words);
}

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

Examples would be: '/' (or 'pm:/'), '/Company/API/', 'http://example.com/api/'

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
    state $default_pa;
    my $base_url = $args{base_url} or die "Please specify base_url";
    my $pa       = $args{pa};
    my $word     = $args{word} // "";

    if (!$pa) {
        if (!$default_pa) {
            require Perinci::Access;
            $default_pa = Perinci::Access->new;
        }
        $pa = $default_pa;
    }

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

sub bash_complete_func_arg {
    require Perinci::Sub::GetArgs::Argv;
    require UUID::Random;

    my ($meta, $opts) = @_;
    $opts //= {};
    $log->tracef("-> bash_complete_func_arg, opts=%s", $opts);

    my ($words, $cword);
    if ($opts->{words}) {
        $words = $opts->{words};
        $cword = $opts->{cword} // 0;
    } else {
        my $res = _parse_request();
        $words = $res->{words};
        $cword = $res->{cword};
    }
    my $word = $words->[$cword] // "";
    $log->tracef("words=%s, cword=%d, word=%s", $words, $cword, $word);

    if ($word =~ /^\$/) {
        $log->tracef("word begins with \$, completing env vars");
        return complete_env($word);
    }

    require Data::Sah;
    my $args_prop = $meta->{args};
    my $args_nschemas = {
        map { $_ => Data::Sah::normalize_schema(
            $args_prop->{$_}{schema} // 'any') }
            keys %$args_prop };

    # first, we stick a unique ID at cword to be able to check whether we should
    # complete arg name or arg value.
    my $which = 'name';
    my $arg;
    my $remaining_words = [@$words];

    my $uuid = UUID::Random::generate();
    my $orig_word = $remaining_words->[$cword];
    $remaining_words->[$cword] = $uuid;
    my $args = Perinci::Sub::GetArgs::Argv::get_args_from_argv(
        argv=>$remaining_words, meta=>$meta, strict=>0);
    for (keys %$args) {
        if (defined($args->{$_}) && $args->{$_} eq $uuid) {
            $arg = $_;
            $which = 'value';
            $args->{$_} = undef;
            last;
        }
    }
    # restore original word which we replaced with uuid earlier (we can't simply
    # use local $remaining_words->[$cword] = $uuid because the array might be
    # sliced)
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
    } elsif ($which ne 'value' && $word =~ /^--([\w-]+)=(.*)/) {
        $arg = $1;
        $words->[$cword] = $2;
        $which = 'value';
    }
    $log->tracef("we should complete arg $which, arg=%s, word=%s", $arg, $word);

    if ($opts->{custom_completer}) {
        $log->tracef("custom_completer option is specified, will use it");
        # custom_completer can decline by returning (undef) (that is, a
        # 1-element list containing undef)
        my $newcword = $cword - (@$words - @$remaining_words);
        $newcword = 0 if $newcword < 0;
        my $res = $opts->{custom_completer}->(
            which => $which,
            words => $words,
            cword => $newcword,
            word  => $word,
            parent_args => $args,
            meta  => $meta,
            opts  => $opts,
            remaining_words => $remaining_words,
        );
        if (@$res==1 && !defined($res->[0])) {
            $log->tracef("custom_completer declined, will continue without");
        } else {
            $log->tracef("result from custom_completer: %s", $res);
            my @res = _complete_array($word, $res);
            return @res;
        }
    }

    if ($which eq 'value') {

        my $arg_spec = $args_prop->{$arg};
        return () unless $arg_spec; # unknown arg? should not happen

        if ($opts->{arg_sub} && $opts->{arg_sub}{$arg}) {
            $log->tracef("completing arg value from 'arg_sub' opt");
            return _complete_array(
                $word,
                [$opts->{arg_sub}{$arg}->(
                    word => $word, arg => $arg, args => $args,
                )] # ...
            );
        }

        if ($opts->{args_sub}) {
            $log->tracef("completing arg value from 'args_sub' opt");
            return _complete_array(
                $word,
                [$opts->{args_sub}->(
                    word => $word, arg => $arg, args => $args,
                )] # ...
            );
        }

        my $as = {}; #$args_nschema->{$arg}; # XXX
        my $ah = $as->[1];
        if ($ah->{in}) {
            $log->tracef("completing arg value from 'in' schema clause");
            return _complete_array($word, $ah->{in});
        }

        if ($arg_spec->{complete}) {
            $log->tracef("completing arg value from 'complete' arg spec");
            return _complete_array(
                $word,
                $arg_spec->{complete}->(
                    word => $word, args => $args,
                )
            );
        }

        # fallback
        $log->tracef("completing arg value from file (fallback)");
        return complete_file($word);

    } elsif ($word eq '' || $word =~ /^--?/) {
        # which eq 'name'

        my @completeable_args;
        for (sort keys %$args_prop) {
            my $a = $_; $a =~ s/^--//;
            my @w;
            my $type = $args_nschemas->{$_}[0];
            if ($type eq 'bool') {
                @w = ("--$_", "--no$_");
            } else {
                @w = ("--$_");
            }
            my $aliases = $args_prop->{$_}{aliases};
            if ($aliases) {
                while (my ($al, $alinfo) = each %$aliases) {
                    push @w,
                        (length($al) == 1 ? "-$al" : "--$al");
                    if ($type eq 'bool' && length($al) > 1 &&
                            !$alinfo->{code}) {
                        push @w, "--no$al";
                    }
                }
            }
            # skip displaying --foo if already mentioned, except when current
            # word
            next if defined($args->{$a}) && !($word ~~ @w);
            push @completeable_args, @w;
        }
        $log->tracef("completeable_args = %s", \@completeable_args);

        if ($cword == 0 || $cword == 1 && !$words->[0]) {
            my @general_opts = ('--help', '-h', '-?');
            return _complete_array($word, [@general_opts, @completeable_args]);
        } else {
            return _complete_array($word, [@completeable_args]);
        }
    } else {
        # fallback
        return complete_file($word);
    }
}

1;
# ABSTRACT: Provide bash completion for Sub::Spec::CmdLine programs
__END__

=head1 SYNOPSIS

 # require'd by Sub::Spec::CmdLine bash completion is enabled


=head1 DESCRIPTION

This module provides functionality for doing bash completion. It is meant to be
used by L<Sub::Spec::CmdLine>, but nevertheless some routines is reusable
outside it.


=head1 FUNCTIONS

None of the functions are exported by default, but they are exportable.


=head2 complete_env($word, \%opts) => ARRAY

Complete from environment variables (C<%ENV>). Word should be '' or '$' or 'foo'
or '$foo'. Return list of possible completion, e.g. C<('$USER', '$HOME', ...)>.

Options:

=over 4

=item * ci => BOOL (default 0)

If set to true, match case-insensitively.

=back

=head2 complete_program($word, \%opts) => ARRAY

Complete from program names (or dir names). Only program which is executable
will be listed. Word can be '/usr/bin/foo' or 'foo' or ''. If word doesn't
contain '/', will search from PATH.

=head2 complete_file($word, \%opts) => ARRAY

Complete from file names in the current directory.

Options:

=over 4

=item * f => BOOL (default 1)

If set to 0, will not complete files, only directories.

=item * d => BOOL (default 1)

If set to 0, will not complete directories, only files.

=back

=head2 complete_subcommand($word, \%subcommands, \%opts) => ARRAY

Complete from subcommand names in C<%subcommands>.

Options:

=over 4

=item * ci => BOOL (default 0)

If set to true, match case-insensitively.

=back

=head2 bash_complete_spec_arg(\%spec, \%opts) => ARRAY

Complete subroutine arguments (from C<$spec{args}>, where %spec is a
L<Sub::Spec> subroutine spec). Word can be 'argname' or '--arg' or '--arg='.

Options:

=over 4

=item * words => ARRAYREF

If unset, will be taken from COMP_LINE and COMP_POINT.

=item * cword => INT

=item * args_sub => CODEREF

=item * arg_sub => {ARGNAME => CODEREF, ...}

=back

=head1 BUGS/LIMITATIONS/TODOS

Due to parsing limitation (invokes subshell), can't complete unclosed quotes,
e.g.

 foo "bar <tab>

while shell function can complete this because they are provided COMP_WORDS and
COMP_CWORD by bash.


=head1 SEE ALSO

L<Sub::Spec>

L<Sub::Spec::CmdLine>

Other bash completion modules on CPAN: L<Getopt::Complete>, L<Bash::Completion>.

=cut
