#!perl

use 5.010;
use strict;
use warnings;

use File::chdir;
use File::Temp qw(tempdir);
use Test::More;

use Perinci::BashComplete qw(complete_file);

sub mkfiles { open my($fh), ">$_" for @_ }
sub mkdirs  { mkdir $_ for @_ }

my $rootdir = tempdir(CLEANUP=>1);
$CWD = $rootdir;
mkfiles(qw(a ab abc ac bb d .h1));
mkdirs (qw(dir1 dir2 foo));
mkdirs (qw(dir1/sub1 dir2/sub2 dir2/sub3));
mkfiles(qw(foo/f1 foo/f2 foo/g));

test_complete(
    # sorted
    word      => '',
    result    => [qw(.h1 a ab abc ac bb d dir1/ dir2/ foo/)],
);
test_complete(
    # has word
    word      => 'a',
    result    => [qw(a ab abc ac)],
);
test_complete(
    # dir + file
    word      => 'd',
    result    => [qw(d dir1/ dir2/)],
);
test_complete(
    # two dirs, won't enable space trick
    word      => 'di',
    result    => [qw(dir1/ dir2/)],
);
test_complete(
    # space trick
    word      => 'f',
    result    => ["foo/", "foo/ "],
);
test_complete(
    # subdir
    word      => 'foo/',
    result    => ["foo/f1", "foo/f2", "foo/g"],
);
test_complete(
    # subdir 2
    word      => 'foo/f',
    result    => ["foo/f1", "foo/f2"],
);

DONE_TESTING:
$CWD = "/";
done_testing();

sub test_complete {
    my (%args) = @_;

    my $name = $args{name} // $args{word};
    my $res = complete_file(
        word=>$args{word}, array=>$args{array});
    is_deeply($res, $args{result}, "$name (result)") or diag explain($res);
}

