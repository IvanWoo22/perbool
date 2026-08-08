requires 'perl', '5.014';

requires 'IO::Zlib';

on test => sub {
    requires 'Test::More';
};
