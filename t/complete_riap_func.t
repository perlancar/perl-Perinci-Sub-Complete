#!perl

use 5.010;
use strict;
use warnings;
#use Log::Any '$log';

use Test::More 0.96;

use Perinci::BashComplete qw(complete_riap_func);

test_complete(
    word      => 'Perinci.Examp',
    base_url  => '/',
    result    => [qw(Perinci.Examples.)],
);
test_complete(
    word      => 'Perinci.Examples.No',
    base_url  => '/',
    result    => [qw(Perinci.Examples.NoMeta.)],
);
test_complete(
    word      => 'Perinci.Examples.d',
    base_url  => '/',
    result    => [qw(Perinci.Examples.delay Perinci.Examples.dies)],
);
test_complete(
    word      => 'Perinci.ExamplesX',
    base_url  => '/',
    result    => [qw()],
);

test_complete(
    word      => 'gen_',
    base_url  => '/Perinci/Examples/',
    result    => [qw(gen_array gen_hash)],
);

done_testing();

sub test_complete {
    my (%args) = @_;
    #$log->tracef("args=%s", \%args);

    my $name = $args{name} // "search $args{word} (base $args{base_url})";
    subtest $name => sub {
        my $res = complete_riap_func(
            word=>$args{word}, base_url=>$args{base_url});
        is_deeply($res, $args{result}, "result") or explain($res);
    };
}

