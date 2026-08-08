#!/usr/bin/env perl
use strict;
use warnings;
use FindBin qw($Bin);
use lib "$Bin/../lib";

use Perbool::Command::QcLengths qw(run);

exit run(@ARGV);
