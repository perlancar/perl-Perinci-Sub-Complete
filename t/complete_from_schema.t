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

subtest float => sub {
    subtest "digit by digit completion" => sub {
        my $sch = [float => {}, {}];
        is_deeply(complete_from_schema(schema=>$sch, word=>''),
                  [sort qw/0 -1 -2 -3 -4 -5 -6 -7 -8 -9 1 2 3 4 5 6 7 8 9/]);
        is_deeply(complete_from_schema(schema=>$sch, word=>'0'),
                  [sort qw/0 0.0 0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9/]);
        is_deeply(complete_from_schema(schema=>$sch, word=>'-0'),
                  [sort qw/-0 -0.0 -0.1 -0.2 -0.3 -0.4 -0.5 -0.6 -0.7 -0.8
                           -0.9/]);
        is_deeply(complete_from_schema(schema=>$sch, word=>'10'),
                  [sort qw/10 100 101 102 103 104 105 106 107 108 109
                           10.0 10.1 10.2 10.3 10.4 10.5 10.6 10.7 10.8 10.9/]);
        is_deeply(complete_from_schema(schema=>$sch, word=>'102'),
                  [sort qw/102 1020 1021 1022 1023 1024 1025 1026 1027 1028 1029
                           102.0 102.1 102.2 102.3 102.4 102.5 102.6 102.7 102.8
                           102.9/]);
        is_deeply(complete_from_schema(schema=>$sch, word=>'10.'),
                  [sort qw/10.0 10.1 10.2 10.3 10.4 10.5 10.6 10.7 10.8 10.9/]);
        is_deeply(complete_from_schema(schema=>$sch, word=>'a'),
                  [sort qw//]);
    };

    subtest "digit by digit completion, with min/max" => sub {
        my $sch = [float => {min=>-2, max=>6}, {}];
        is_deeply(complete_from_schema(schema=>$sch, word=>''),
                  [sort qw/0 -1 -2 1 2 3 4 5 6/]);
        is_deeply(complete_from_schema(schema=>$sch, word=>'0'),
                  [sort qw/0 0.0 0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9/]);
        is_deeply(complete_from_schema(schema=>$sch, word=>'-2'),
                  [sort qw/-2 -2.0/]);
        is_deeply(complete_from_schema(schema=>$sch, word=>'-3'),
                  [sort qw//]);
    };

    # XXX digit-by-digit, with xmin, xmax, between, xbetween
};

DONE_TESTING:
done_testing;
