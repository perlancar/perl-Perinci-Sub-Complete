package Sub::Spec::BashComplete;

use 5.010;
use strict;
use warnings;
use Log::Any '$log';

# VERSION

require Exporter;
our @ISA       = qw(Exporter);
our @EXPORT_OK = qw(
                       complete_env
                       complete_file
                       complete_program
                       complete_subcommand

                       bash_complete_spec_arg
               );

use Sub::Spec::Utils; # tmp, for _parse_schema

sub _parse_schema {
    Sub::Spec::Utils::_parse_schema(@_);
}

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

sub _complete_array {
    my ($word, $arrayref, $opts) = @_;
    $log->tracef("-> _complete_array(), word=%s, array=%s", $word, $arrayref);
    $word //= "";
    $opts //= {};

    my $wordu = uc($word);
    my @res;
    for (@$arrayref) {
        next unless 0==($opts->{ci} ? index(uc($_), $wordu):index($_, $word));
        push @res, $_;
    }
    @res;
}

sub _complete_hash_key {
    my ($word, $hashref, $opts) = @_;
    $log->tracef("-> _complete_hash_key(), word=%s, hash=%s", $word, $hashref);
    $word //= "";
    $opts //= {};

    _complete_array($word, [keys %$hashref], $opts);
}

sub complete_env {
    my ($word, $opts) = @_;
    $word //= "";
    if ($word =~ /^\$/) {
        _complete_array($word, [map {"\$$_"} keys %ENV], $opts);
    } else {
        _complete_array($word, [keys %ENV], $opts);
    }
}

sub complete_program {
    require List::MoreUtils;

    my ($word, $opts) = @_;
    $word //= "";
    $opts //= {};

    my @res;

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
            push @res, (-d _) ? "$_/" : $_;
        };
    }

    _complete_array("", [List::MoreUtils::uniq(@res)]);
}

sub complete_file {
    my ($word, $opts) = @_;
    $word //= "";
    $opts //= {};
    $opts->{f} //= 1;
    $opts->{d} //= 1;

    $word =~ s!/+$!!;

    my @res;
    opendir my($dh), "." or return ();
    for (readdir($dh)) {
        next if $word !~ /^\.\.?$/ && ($_ eq '.' || $_ eq '..');
        next unless index($_, $word) == 0;
        next if (-f $_) && !$opts->{f};
        next if (-d _ ) && !$opts->{d};
        push @res, (-d _) ? "$_/" : $_;
    }

    _complete_array("", \@res);
}

sub complete_subcommand {
    my ($word, $subcommands, $opts) = @_;

    _complete_hash_key($word, $subcommands, $opts);
}

sub bash_complete_spec_arg {
    require Sub::Spec::GetArgs::Argv;
    require UUID::Random;

    my ($spec, $opts) = @_;
    $opts //= {};
    $log->tracef("-> bash_complete_spec_arg, opts=%s", $opts);

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

    my $args_spec = $spec->{args};
    $args_spec    = {
        map { $_ => _parse_schema($args_spec->{$_}) }
            keys %$args_spec };
    my $args;

    # first, we stick a unique ID at cword to be able to check whether we should
    # complete arg name or arg value.
    my $which = 'name';
    my $arg;
    my $remaining_words = [@$words];

    my $uuid = UUID::Random::generate();
    my $orig_word = $remaining_words->[$cword];
    $remaining_words->[$cword] = $uuid;
    $args = Sub::Spec::GetArgs::Argv::get_args_from_argv(
        argv=>$remaining_words, spec=>$spec, strict=>0);
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
            spec  => $spec,
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

        my $arg_spec = $args_spec->{$arg};
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

        my $ah0 = $arg_spec->{attr_hashes}[0];
        if ($ah0->{in}) {
            $log->tracef("completing arg value from 'in' spec");
            return _complete_array($word, $ah0->{in});
        }

        if ($ah0->{arg_complete}) {
            $log->tracef("completing arg value from 'arg_complete' spec");
            return _complete_array(
                $word,
                $ah0->{arg_complete}->(
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
        for (sort keys %$args_spec) {
            my $a = $_; $a =~ s/^--//;
            my @w;
            my $type = $args_spec->{$_}{type};
            if ($type eq 'bool') {
                @w = ("--$_", "--no$_");
            } else {
                @w = ("--$_");
            }
            my $aliases = $args_spec->{$_}{attr_hashes}[0]{arg_aliases};
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
