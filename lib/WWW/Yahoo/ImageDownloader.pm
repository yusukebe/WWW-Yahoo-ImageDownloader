package WWW::Yahoo::ImageDownloader;
use Mouse;
our $VERSION = '0.01';
use MouseX::Types::Path::Class;
use AnyEvent;
use AnyEvent::HTTP;
use IO::File;
use URI::Escape qw( uri_escape_utf8 );
use WebService::Simple;
use WebService::Simple::Parser::JSON;

has 'appid' => ( is => 'ro', isa => 'Str', required => 1 );
has 'dir' => ( is => 'ro', isa => 'Path::Class::Dir', required =>1, coerce => 1 );
has 'api' => ( is => 'ro', isa => 'WebService::Simple', lazy_build => 1 );
has 'filter' => ( is => 'rw', isa => 'Str', default => 'no' );
has 'count' => ( is => 'rw', isa => 'Int', default => 50 );

no Mouse;

sub _build_api {
    my $self   = shift;
    my $parser = WebService::Simple::Parser::JSON->new();
    return WebService::Simple->new(
        base_url => 'http://boss.yahooapis.com/ysearch/images/v1/',
        params   => {
            appid  => $self->appid,
            filter => $self->filter,
            count  => $self->count,
        },
        response_parser => $parser,
        debug => 1,
    );
}

sub download {
    my ( $self, $query ) = @_;
    my ( $page, $count, $start, $total_hits ) = ( 0, 1,, );
    while (1) {
        my $cv = AnyEvent->condvar;
        $cv->begin;
        $start = $page * $self->count;
        warn "start: $start\n";
        my $res =
          $self->api->get( uri_escape_utf8($query), { start => $start } );
        my $ref = $res->parse_response();
        unless ($total_hits) {
            $total_hits = $ref->{ysearchresponse}->{totalhits};
            warn "total hits: $total_hits\n";
            sleep(1);
        }
        for my $image ( @{ $ref->{ysearchresponse}->{resultset_images} } ) {
            my $ext = 'jpg';
            $ext = $1 if $image->{url} =~ /\.([^\.]+)$/;
            my $filename =
              $self->dir->file( sprintf( "%08d\.$ext", $count ) )->stringify;
            unless ( -f $filename ) {
                $cv->begin;
                AnyEvent::HTTP::http_request
                  GET     => $image->{url},
                  timeout => 10,
                  on_body => sub {
                    my ( $body, $hdr ) = @_;
                    if ( $hdr->{'content-type'} =~ /image/ ) {
                        print "$filename : $image->{url}\n";
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
        last
          if ( $total_hits - ( $page * $self->count ) < 0
            || $start > ( 1000 - $self->count - 1 ) );
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
