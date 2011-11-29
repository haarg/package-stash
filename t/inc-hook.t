#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use Test::Fatal;

unshift @INC, sub { "some regex" =~ /match/; undef };

is(exception { require Package::Stash }, undef, "works with an \@INC hook");

done_testing;
