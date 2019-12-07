#!perl
use strict;
use warnings;
use feature qw/ say /;;
use Test::More;
use Carp qw/ confess /;
use Fcntl;
use overload::open 'record_opened_file';
use File::Temp qw/ tempfile /;
my $test_file = tempfile;
sub cleanup {
    unlink $test_file;
}
my %opened_files;
sub record_opened_file {
    my ($filename) = @_;
    if (exists $opened_files{$filename}) {
    }
    else {
        $opened_files{$filename} = 1;
    }
}
my $global;
unlink $test_file;
my ($open_lives, $print_lives) = (0, 0);
my $fh;
eval {
    open $fh, '>', $test_file || die $!;
    $open_lives = 1;
    1;
} or do {
    warn $@;
};
eval {
    print $fh "words" || die $!;
    $print_lives = 1;
    1;
} or do {
    confess $@;
};
is $print_lives, 1, "Print does not die";
is $open_lives, 1, "open does not die";
my $sysopen_fh;
close $fh;
die if ! -f $test_file;
sysopen($sysopen_fh, $test_file, O_RDONLY);
my $a;
($a = <$sysopen_fh>) // warn $!;
is $a, 'words', "file has correct content";
close($sysopen_fh) or die $!;
%opened_files = ();
open($fh, '>', $test_file) || die $!;
ok $opened_files{$test_file}, 'recorded that we opened the test file from three argument open';
is keys %opened_files, 1, "correct number of keys after opened the test file twice";
%opened_files = ();
close $fh;

open $fh, 'filename2.txt';
is keys %opened_files, 1, "correct number of keys after opened filename2.txt once";
ok $opened_files{"filename2.txt"}, "stored filename2.txt from two argument open";

cleanup();
done_testing();
