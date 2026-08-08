requires 'perl', '5.014';

requires 'AlignDB::IntSpan';
requires 'IO::Zlib';
requires 'PerlIO::gzip';

on test => sub {
    requires 'Test::More';
};
