#!perl

use 5.010;
use strict;
use warnings;
#use Log::Any '$log';

use Test::More;

use Perinci::BashComplete qw(complete_hash_key);

test_complete(
    word      => 'a',
    hash      => {a=>1, aa=>1, ab=>1, b=>1, A=>1},
    result    => [qw(a aa ab)],
    result_ci => [qw(A a aa ab)],
);
test_complete(
    word      => 'c',
    hash      => {a=>1, aa=>1, ab=>1, b=>1, A=>1},
    result    => [qw()],
    result_ci => [qw()],
);
done_testing();

sub test_complete {
    my (%args) = @_;
    #$log->tracef("args=%s", \%args);

    my $name = $args{name} // $args{word};
    my $res = [sort @{complete_hash_key(word=>$args{word}, hash=>$args{hash})}];
    is_deeply($res, $args{result}, "$name (result)") or explain($res);
    if ($args{result_ci}) {
        my $res_ci = [sort @{complete_hash_key(
            word=>$args{word}, hash=>$args{hash}, ci=>1)}];
        is_deeply($res_ci, $args{result_ci}, "$name (result_ci)")
            or explain($res_ci);
    }
}

