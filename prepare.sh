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
yml_version=$(grep '^version:' MYMETA.yml | sed 's/version: v//')
perl_version=$(perl -Ilib -Moverload::open -E 'say $overload::open::VERSION')
perl Makefile.PL
make
if [ "$yml_version" != "$perl_version" ]; then
    echo mismatching versions "yml: $yml_version other: $perl_version"
    exit 1
fi
meta_version=$(cat MYMETA.json| jq '.version' | sed 's/"//g' | sed 's/^v//')
if [ "$meta_version" != "$perl_version" ]; then
    echo "mismatching versions"
fi
