use strict;
use Test::More ('no_plan');
use utf8;

use_ok('WWW::Yahoo::ImageDownloader');

my $client = WWW::Yahoo::ImageDownloader->new(
    appid => $ENV{YAHOO_APPID},
    dir   => 'temp',
    count => 50
);
diag $client->download('おっぱい');
