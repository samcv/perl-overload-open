#!sh
if [ -f Makefile ]; then
    make clean
fi
perl -MPod::Checker -E 'use strict; use warnings; exit podchecker($ARGV[0], *STDOUT)' lib/overload/open.pm && perldoc -u lib/overload/open.pm > README.pod || exit 1
if [ -f Manifest ]; then
    rm Manifest
fi
if [ -f Makefile.old ]; then
    rm Makefile.old
fi
