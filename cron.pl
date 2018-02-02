#!/usr/bin/perl

use strict;
use utf8;

system('perl access.pl');
system('perl indexes.pl');
system('killall lighttpd');
system('lighttpd -D -f ./lighttpd.conf');