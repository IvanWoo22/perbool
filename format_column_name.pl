#!/usr/bin/env perl
use strict;
use warnings;
use FindBin qw($Bin);
use lib "$Bin/lib";

use Perbool::Command::TableExtractAfter qw(run);

exit run(@ARGV);
