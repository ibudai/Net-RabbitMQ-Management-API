package    # hide from PAUSE
  Net::RabbitMQ::Test::UA;

use Moo;
use File::Basename qw(dirname);
use File::Slurp qw(read_file);
use HTTP::Response;
use Test::More;

sub request {
    my ( $self, $request ) = @_;
    my $path = sprintf '%s/http_response/%s/%s.%s', dirname(__FILE__), $request->uri->host, $request->uri->path, $request->method;
    my %query_form = $request->uri->query_form;
    while ( my ( $k, $v ) = each %query_form ) {
        $path .= sprintf '.%s-%s', $k, $v;
    }
    my $response = HTTP::Response->new(404);
    if ( -f $path ) {
        my $res = read_file($path);
        $response = HTTP::Response->parse($res);
    }
    $response->request($request);
    return $response;
}

1;
