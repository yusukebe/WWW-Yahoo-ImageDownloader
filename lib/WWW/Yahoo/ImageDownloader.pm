package WWW::Yahoo::ImageDownloader;
use Mouse;
our $VERSION = '0.01';
use MouseX::Types::Path::Class;
use AnyEvent;
use AnyEvent::HTTP;
use IO::File;
use JSON qw( from_json );
use URI::Escape qw( uri_unescape uri_escape_utf8 );
use LWP::UserAgent;

has 'dir' => ( is => 'ro', isa => 'Path::Class::Dir', required =>1, coerce => 1 );
has 'count' => ( is => 'ro', isa => 'Int', default => 22 );
has 'ua' => (
    is      => 'rw',
    isa     => 'LWP::UserAgent',
    default => sub {
        my $ua = LWP::UserAgent->new();
        $ua->agent('Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.0;)');
        $ua->cookie_jar( {} );
        return $ua;
    }
);

no Mouse;

sub download {
    my ( $self, $query ) = @_;

    my $res = $self->ua->get('http://search.yahoo.com/preferences/preferences?page=filters');
    my $bcrumb = $1 if $res->content =~ /".bcrumb".*?value="(.+?)"/;
    $res = $self->ua->get("http://search.yahoo.com/web/validate?pref_done=http%3A%2F%2Fsearch.yahoo.com&.bcrumb=$bcrumb&adult_done=http%3A%2F%2Fsearch.yahoo.com%2Fweb%2Fsavepref&adult_cancel=http%3A%2F%2Fsearch.yahoo.com%2Fpreferences%2Fpreferences%3Fei%3DUTF-8%26page%3Dfilters&vm=p&prev_sBL=Off");
    my $pref_url = $1 if $res->content =~ /name=accept value="(.+?)"/;
    $pref_url =~ s/&amp;/&/;
    $self->ua->get( $pref_url );

    my ( $page, $count, $start, $total_hits ) = ( 0, 1,, );
    while (1) {
        $start = $page * $self->count + 1;
        $query = uri_escape_utf8( $query );
        my $url = "http://images.search.yahoo.com/search/images?p=$query&pstart=1&b=$start&xargs=0";
        warn $url;
        $res = $self->ua->get( $url );
        my $content = $res->content();
        $content =~ /jsonData=(\{"RES":.+?\}\});/;
        my $ref = from_json( $1 );
        unless ($total_hits) {
            $total_hits = $ref->{META}{tor};
            warn "total hits: $total_hits\n";
            sleep(1);
        }
        my $cv = AnyEvent->condvar;
        $cv->begin;
        for my $image ( @{$ref->{RES}} ){
            my $href = uri_unescape( $image->{href} );
            my $url = 'http://' . uri_unescape($1) if $href =~ /imgurl=([^&].+?)&/;
            my $ext = 'jpg';
            $ext = $1 if $url =~ /\.([^\.]+)$/;
            my $filename =
              $self->dir->file( sprintf( "%08d\.$ext", $count ) )->stringify;
            unless ( -f $filename ) {
                $cv->begin;
                AnyEvent::HTTP::http_request
                  GET     => $url,
                  timeout => 10,
                  on_body => sub {
                    my ( $body, $hdr ) = @_;
                    if ( $hdr->{'content-type'} =~ /image/ ) {
                        print "$filename : $url\n";
                        my $file = IO::File->new( $filename, 'w' );
                        $file->print($body);
                        $file->close;
                    }
                    $cv->end;
                  };
            }
            $count++;
        }
        $cv->end( sub { $cv = undef; } ); $cv->recv;
        $page++;
        last if ( $total_hits - $start - $self->count < 0 );
    }
}

__PACKAGE__->meta->make_immutable();
1;
__END__

=head1 NAME

WWW::Yahoo::ImageDownloader -

=head1 SYNOPSIS

  use WWW::Yahoo::ImageDownloader;

=head1 DESCRIPTION

WWW::Yahoo::ImageDownloader is

=head1 AUTHOR

Yusuke Wada E<lt>yusuke at kamawada.comE<gt>

=head1 SEE ALSO

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
