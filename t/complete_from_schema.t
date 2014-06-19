#!perl

use 5.010;
use strict;
use warnings;

use Perinci::Sub::Complete qw(complete_from_schema);
#use Perinci::Sub::Normalize qw(normalize_function_metadata);
#use Data::Sah qw(normalize_schema);
use Test::More 0.98;

# XXX in clause (btw, already tested in shell_complete_arg.t)
# XXX bool 0/1
# XXX is clause

subtest int => sub {
    subtest "min/max below limit" => sub {
        my $sch = [int => {min=>2, max=>14}, {}];
        is_deeply(complete_from_schema(schema=>$sch, word=>''),
                  [sort qw/2 3 4 5 6 7 8 9 10 11 12 13 14/]);
    };

    subtest "min/xmax below limit" => sub {
        my $sch = [int => {min=>2, xmax=>14}, {}];
        is_deeply(complete_from_schema(schema=>$sch, word=>''),
                  [sort qw/2 3 4 5 6 7 8 9 10 11 12 13/]);
    };

    subtest "xmin/max below limit" => sub {
        my $sch = [int => {xmin=>2, max=>14}, {}];
        is_deeply(complete_from_schema(schema=>$sch, word=>''),
                  [sort qw/3 4 5 6 7 8 9 10 11 12 13 14/]);
    };

    subtest "xmin/xmax below limit" => sub {
        my $sch = [int => {xmin=>2, xmax=>14}, {}];
        is_deeply(complete_from_schema(schema=>$sch, word=>''),
                  [sort qw/3 4 5 6 7 8 9 10 11 12 13/]);
    };

    subtest "between below limit" => sub {
        my $sch = [int => {between=>[2, 14]}, {}];
        is_deeply(complete_from_schema(schema=>$sch, word=>''),
                  [sort qw/2 3 4 5 6 7 8 9 10 11 12 13 14/]);
    };

    subtest "xbetween below limit" => sub {
        my $sch = [int => {xbetween=>[2, 14]}, {}];
        is_deeply(complete_from_schema(schema=>$sch, word=>''),
                  [sort qw/3 4 5 6 7 8 9 10 11 12 13/]);
    };

    subtest "digit by digit completion" => sub {
        my $sch = [int => {}, {}];
        is_deeply(complete_from_schema(schema=>$sch, word=>''),
                  [qw/0 1 2 3 4 5 6 7 8 9/]);
        is_deeply(complete_from_schema(schema=>$sch, word=>'0'),
                  [qw/0/]);
        is_deeply(complete_from_schema(schema=>$sch, word=>'1'),
                  [qw/1 10 11 12 13 14 15 16 17 18 19/]);
        is_deeply(complete_from_schema(schema=>$sch, word=>'13'),
                  [qw/13 130 131 132 133 134 135 136 137 138 139/]);
        is_deeply(complete_from_schema(schema=>$sch, word=>'-1'),
                  [qw/-1 -10 -11 -12 -13 -14 -15 -16 -17 -18 -19/]);
        is_deeply(complete_from_schema(schema=>$sch, word=>'-13'),
                  [qw/-13 -130 -131 -132 -133 -134 -135 -136 -137 -138 -139/]);
        is_deeply(complete_from_schema(schema=>$sch, word=>'a'),
                  [qw//]);
    };

    subtest "digit by digit completion, with min/max" => sub {
        my $sch = [int => {min=>1, max=>2000}, {}];
        is_deeply(complete_from_schema(schema=>$sch, word=>''),
                  [qw/1 2 3 4 5 6 7 8 9/]);
        is_deeply(complete_from_schema(schema=>$sch, word=>'1'),
                  [qw/1 10 11 12 13 14 15 16 17 18 19/]);
        is_deeply(complete_from_schema(schema=>$sch, word=>'13'),
                  [qw/13 130 131 132 133 134 135 136 137 138 139/]);
        is_deeply(complete_from_schema(schema=>$sch, word=>'-1'),
                  [qw//]);
        is_deeply(complete_from_schema(schema=>$sch, word=>'201'),
                  [qw/201/]);
    };

    # XXX digit-by-digit, with xmin, xmax, between, xbetween
};

DONE_TESTING:
done_testing;
