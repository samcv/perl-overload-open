#!perl
use strict;
use warnings;
use Test::More;
use Fcntl;
use File::Temp;
my $test_file = File::Temp->new->filename;
my %opened_files;
my $test_file2 = File::Temp->new->filename;
open my $fh99, '>', $test_file2;
use overload::open;

BEGIN {
    sub record_opened_file {
        my $filename;
        open my $fh222, '>', $test_file;
        if (@_ == 3) {
            $filename = $_[2];
        }
        elsif (@_ == 2) {
            $filename = $_[1];
        }
        else {
            return;
        }
        if (exists $opened_files{$filename}) {
        }
        else {
            $opened_files{$filename} = 1;
        }
    }
    overload::open->prehook_open(\&record_opened_file);
}
sub cleanup {
    unlink $test_file;
    unlink $test_file2;
}
my $global;
ok(!exists $opened_files{$test_file2}, "did not register we opened the file called '$test_file2'");
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
    die $@;
};
is $print_lives, 1, "Print does not die";
is $open_lives, 1, "open does not die";
my $sysopen_fh;
close $fh;
die if ! -f $test_file;
sysopen($sysopen_fh, $test_file, O_RDONLY);
my $a;
ok(defined ($a = <$sysopen_fh>), "result is defined");
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
