package Filter::Handle;
use strict;

=head1 NAME

Filter::Handle - Apply filters to output filehandles

=head1 SYNOPSIS

    use Filter::Handle;
    my $f = Filter::Handle->new(\*STDOUT);

    use Filter::Handle qw/subs/;
    Filter \*STDOUT;
    ...
    UnFilter \*STDOUT;

    tie *STDOUT, 'Filter::Handle', \*HANDLE;
    ...
    untie *STDOUT;

=head1 DESCRIPTION

I<Filter::Handle> allows you to apply arbitrary filters
to output filehandles. You can perform any sorts of
transformations on the outgoing text: you can prepend it
with some data, you can replace all instances of one word
with another, etc.

You can even filter all of your output to one filehandle
and send it to another; for example, you can filter
everything written to STDOUT and write it instead to
another filehandle. To do this, you need to explicitly
use the I<tie> interface (see below).

=head2 Calling Interfaces

There are three interfaces to filtering a handle:

=over 4

=item * Functional

    use Filter::Handle qw/subs/;

    Filter \*STDOUT;
    print "I am filtered text";
    UnFilter \*STDOUT;

    print "I am normal text";

The functional interface works by exporting two functions
into the caller's namespace: I<Filter> and I<UnFilter>. To
start filtering a filehandle, call the I<Filter> function;
to stop, call I<UnFilter> on that same filehandle.

Any writes between the time you start and stop filtering
will be filtered.

=item * Object-Oriented

    use Filter::Handle;

    {
        my $f = Filter::Handle->new(\*STDOUT);
        print "I am filtered text";
    }

    print "I am normal text";

The object-oriented interface works by filtering the
filehandle while your object is in scope. Once all
references to that object have gone out of scope--typically,
this is after your one reference has gone away--the
filehandle will no longer be filtered.

=item * Tie

    use Filter::Handle;

    local *HANDLE;
    tie *STDOUT, 'Filter::Handle', \*HANDLE;

    print "I am filtered text written to HANDLE";

    untie *STDOUT;

The I<tie> interface will filter your filehandle until
you explicitly I<untie> it. This is the only interface
that allows you to filter one filehandle through another.
The above example will filter all writes to STDOUT through
the output filter, then write it out on HANDLE. Note that
this is different behavior than that of the first two
interfaces; if you want your output written to the same
handle that you're filtering, you could use:

    tie *STDOUT, 'Filter::Handle', \*STDOUT;

Which is exactly what the first two interfaces do.

=back

=head2 Customized Filters

The default filter is relatively boring: it simply prepends
any text you print with the filename and line of the invoking
caller. You'll probably want to do something more interesting.

To do so, pass an anonymous subroutine as a second argument
to either the I<new> method, if you're using the OO interface,
or to the I<Filter> function, if you're using the functional
interface. Your subroutine will be passed the list originally
passed to print, and it should return another list, suitable
for passing to your (unfiltered) output filehandle.

For example, say that we want to replace all instances of
"blue" with "red". We could say:

    use Filter::Handle qw/subs/;

    Filter \*STDOUT,
        sub { local $_ = "@_"; s/blue/red/g; $_ };

    print "My house is blue.\n";
    print "So is my cat, whose nose is blue.\n";

    UnFilter \*STDOUT;

    print "And the plane is also blue.\n";

This prints:

    My house is red.
    So is my cat, whose nose is red.
    And the plane is also blue.

As expected.

=head1 CAVEATS

Note that this won't work correctly with output from
XSUBs or system calls. This is due to a limitation of
Perl's I<tie> mechanism when tying filehandles.

=head1 AUTHOR

Benjamin Trott, ben@rhumba.pair.com

=head1 CREDITS

Thanks to tilly, chromatic, and merlyn at PerlMonks.org
for suggestions, critiques, and code samples.

=cut

use vars qw/$VERSION/;
$VERSION = '0.01';

sub import {
    my $class  = shift;
    return if !@_;

    my $caller = caller;
    if ($_[0] eq "subs") {
        no strict 'refs';
        for my $sub (qw/Filter UnFilter/) {
            *{"${caller}::$sub"} = \&{"${class}::$sub"};
        }
    }
}

sub Filter {
    my $fh = $_[0];
    tie *{ $fh }, __PACKAGE__, @_;
}

sub UnFilter {
    my $fh = shift;
    { local $^W = 0; untie *{ $fh } }
}

sub TIEHANDLE {
    my $class = shift;
    my $fh       = shift or die "Need a filehandle to tie.";
    my $output   = shift || sub {
        sprintf "%s:%d - %s\n", (caller(1))[1,2], "@_"
    };
    bless { fh => $fh, output => $output }, $class;
}

sub new {
    Filter(@_[1..$#_]);
    bless { fh => $_[1] }, $_[0]
}

sub DESTROY {
    my $self = shift;
    UnFilter($self->{fh});
}

sub PRINT {
    my $self = shift;
    my $fh = *{ $self->{fh} };
    print $fh $self->{output}->(@_);
}

sub PRINTF {
    my $self  = shift;
    @_ = ($self, sprintf shift, @_);
    goto &PRINT;
}

1;
