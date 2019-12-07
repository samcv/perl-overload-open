#!perl
use strict;
use warnings;
use feature qw/ say /;;
use Test::More;
use Carp qw/ confess /;
use Fcntl;
use overload::open 'record_opened_file';
my $test_file = 'filename.txt';
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
sysopen($sysopen_fh, $test_file, O_RDONLY);
my $a;
($a = <$sysopen_fh>) // warn $!;
is $a, 'words', "file has correct content";
close($sysopen_fh) or die $!;
%opened_files = ();
open($fh, '>', $test_file) || die $!;
ok $opened_files{"filename.txt"}, 'recorded that we opened filename.txt from three argument open';
is keys %opened_files, 1, "correct number of keys after opened filename.txt twice";
%opened_files = ();
close $fh;

open $fh, 'filename2.txt';
is keys %opened_files, 1, "correct number of keys after opened filename2.txt once";
ok $opened_files{"filename2.txt"}, "stored filename2.txt from two argument open";

cleanup();
done_testing();
