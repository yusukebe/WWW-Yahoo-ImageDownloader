use inc::Module::Install;
name 'WWW-Yahoo-ImageDownloader';
all_from 'lib/WWW/Yahoo/ImageDownloader.pm';

# requires '';

tests 't/*.t';

build_requires 'Test::More';
use_test_base;
auto_include;
WriteAll;
