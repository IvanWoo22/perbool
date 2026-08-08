requires 'perl', '5.014';

requires 'AlignDB::IntSpan';
requires 'IO::Zlib';

on test => sub {
    requires 'Test::More';
};
