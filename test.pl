# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

######################### We start with some black magic to print on failure.

# Change 1..1 below to 1..last_test_to_print .
# (It may become useful if the test is moved to ./t subdirectory.)

BEGIN { $| = 1; print "1..5\n"; }
END {print "not ok 1\n" unless $loaded;}
use Filter::Handle qw/subs/;
$loaded = 1;
print "ok 1\n";

######################### End of black magic.

# Insert your test code below (better if it prints "ok 13"
# (correspondingly "not ok 13") depending on the success of chunk 13
# of the test code):

## 2. Test OO interface and printf method.
{
    my $out;
    my $f = Filter::Handle->new(\*STDOUT, sub {
        $out = sprintf "%d: %s\n", 1, "@_";
        ()
    });
    $f->printf("(%s)", "Foo");
    print $out eq "1: (Foo)\n" ? "ok 2\n" : "not ok 2\n";
}

## 3. Test Filter/UnFilter routines.
my $out;
Filter \*STDOUT, sub {
    $out = sprintf "%d: %s\n", 1, "@_";
    ()
};
print "Foo";
UnFilter \*STDOUT;
print $out eq "1: Foo\n" ? "ok 3\n" : "not ok 3\n";

## 4. Test that we're actually untie-d (we should be).
print tied *STDOUT ? "not ok 4\n" : "ok 4\n";

## 5. Test tie interface.
local *FH;
my $test_out = "tout";
open FH, ">$test_out" or die "Can't open $test_out: $!";
tie *STDOUT, 'Filter::Handle', \*FH, sub {
    sprintf "%d: %s\n", 1, "@_";
};
print "Foo";
untie *STDOUT;
open FH, "$test_out" or die "Can't open $test_out: $!";
print scalar <FH> eq "1: Foo\n" ? "ok 5\n" : "not ok 5\n";
close FH;
unlink $test_out or die "Can't unlink $test_out: $!";
