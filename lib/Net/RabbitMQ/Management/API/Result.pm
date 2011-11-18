package Net::RabbitMQ::Management::API::Result;

# ABSTRACT: RabbitMQ Management API result object

use Moo;

use JSON::Any;

=attr response

The L<HTTP::Response> object.

=cut

has 'response' => (
    handles => {
        code        => 'code',
        raw_content => 'content',
        request     => 'request',
        success     => 'is_success',
    },
    is       => 'ro',
    isa      => sub { die 'must be a HTTP::Response, but is ' . ref $_[0] unless ref $_[0] eq 'HTTP::Response' },
    required => 1,
);

=attr content

The decoded JSON response. May be an arrayref or hashref, depending
on the API call. For some calls there is no content at all.

=cut

has 'content' => (
    builder => '_build_content',
    clearer => 'clear_content',
    is      => 'ro',
    lazy    => 1,
);

has '_json' => (
    builder => '_build__json',
    is      => 'ro',
    isa     => sub { die 'must be a JSON::Any, but is ' . ref $_[0] unless ref $_[0] eq 'JSON::Any' },
    lazy    => 1,
);


sub _build__json {
    my ($self) = @_;
    return JSON::Any->new;
}

sub _build_content {
    my ($self) = @_;
    if ( $self->raw_content ) {
        return $self->_json->decode( $self->raw_content );
    }
    return {};
}

1;
