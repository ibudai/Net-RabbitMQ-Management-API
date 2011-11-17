package Net::RabbitMQ::Management::API;

# ABSTRACT: Interface to the HTTP Rest API of the RabbitMQ management plugin

use Moo;

use Carp qw(croak);
use HTTP::Headers;
use HTTP::Request;
use JSON::Any;
use LWP::UserAgent;
use Net::RabbitMQ::Management::API::Result;
use URI;

=head1 DESCRIPTION

L<Net::RabbitMQ::Management::API> provides a set of modules to access
L< RabbitMQ|http://hg.rabbitmq.com/rabbitmq-management/raw-file/rabbitmq_v2_6_1/priv/www/api/index.html>
in an object oriented way.

=head1 SYNOPSIS

    use Net::RabbitMQ::Management::API;
    use Data::Dumper;

    my $a = Net::RabbitMQ::Management::API->new( url => 'http://localhost:55672/api' );
    my $result = $a->get_overview;

    # $result->content is either an arrayref or an hashref
    # depending on the API call that has been made
    printf "%s\n", Dumper $result->content;    # prints random bits of information that describe the whole system

=head1 DOCUMENTATION

The documentation has been taken directly from
L< RabbitMQ|http://hg.rabbitmq.com/rabbitmq-management/raw-file/rabbitmq_v2_6_1/priv/www/api/index.html>
Please also read the documentation there, since it might be more complete.

=cut

=attr ua

By default a L<LWP::UserAgent> object but it can be anything that
implements the same interface.

=cut

has 'ua' => (
    builder => '_build_ua',
    is      => 'ro',
    lazy    => 1,
);

=attr username

By default is guest. This can set the user for the API calls.

=cut

has 'username' => (
    is      => 'ro',
    default => sub {
        return 'guest';
    },
);

=attr password

By default is guest. This can set the password for the API calls.

=cut

has 'password' => (
    is      => 'ro',
    default => sub {
        return 'guest';
    },
);

=attr url

Url for the API calls. Is mandatory.

=cut

has 'url' => (
    is       => 'ro',
    required => 1,
    trigger  => sub {
        my ( $self, $uri ) = @_;
        $self->{url} = URI->new("$uri");
    },
);

has '_json' => (
    builder => '_build__json',
    is      => 'ro',
    lazy    => 1,
);

=method request

All L<Net::RabbitMQ::Management::API> calls are using this method
for making requests to RabbitMQ. This method can be used directly.
It accepts a hash with following keys:

=over

=item *

B<method>: mandatory string, one of the following:

=over

=item *

DELETE

=item *

GET

=item *

PATCH

=item *

POST

=item *

PUT

=back

=item *

B<path>: mandatory string of the relative path used for making the
API call.

=item *

B<data>: optional data reference, usually a reference to an array
or hash. It must be possible to serialize this using L<JSON::Any>.
This will be the HTTP request body.



=back

Usually you should not end up using this method at all. It's only
available if L<Net::RabbitMQ::Management::API> is missing anything
from the RabbitMQ API. Here are some examples of how to use it:

=over

=item *

Same as L<Net::RabbitMQ::Management::API/get_overview>:

    my $a      = Net::RabbitMQ::Management::API->new( url => 'http://localhost:55672/api' );
    my $result = $a->request(
        method => 'GET',
        path   => '/overview',
    );

=item *

Same as L<Net::RabbitMQ::Management::API/get_configuration>:

    my $a      = Net::RabbitMQ::Management::API->new( url => 'http://localhost:55672/api' );
    my $result = $a->request(
        method => 'GET',
        path   => '/all-configuration',
    );

=back

This method always returns a L<Net::RabbitMQ::Management::API::Result> object.

=cut

sub request {
    my ( $self, %args ) = @_;

    my $method = delete $args{method} || croak 'Missing mandatory key in parameters: method';
    my $path   = delete $args{path}   || croak 'Missing mandatory key in parameters: path';
    my $data   = delete $args{data};

    croak "Invalid method: $method" unless grep $_ eq $method, qw(DELETE GET PATCH POST PUT);

    my $uri      = $self->_uri_for($path);
    my $request  = $self->_request_for( $method, $uri, $data );
    my $response = $self->ua->request($request);

    return Net::RabbitMQ::Management::API::Result->new( response => $response );
}

sub _request_for {
    my ( $self, $method, $uri, $data ) = @_;

    my $headers = HTTP::Headers->new;

    my $request = HTTP::Request->new( $method, $uri, $headers );
    $request->authorization_basic( $self->username, $self->password );

    if ($data) {
        my $json = $self->_json->encode($data);
        $request->content($json);
    }

    $request->header( 'Content-Length' => length $request->content );
    $request->header( 'Content-Type'   => 'application/json' );

    return $request;
}

sub _uri_for {
    my ( $self, $path ) = @_;

    my $uri = $self->url->clone;

    $uri->path( $uri->path . $path );

    return $uri;
}

sub _build__json {
    my ($self) = @_;
    return JSON::Any->new;
}

sub _build_ua {
    my ($self) = @_;
    return LWP::UserAgent->new;
}

=method get_overview

Get various random bits of information that describe the whole system.

=cut

sub get_overview {
    my ($self) = @_;

    return $self->request(
        method => 'GET',
        path   => '/overview',
    );
}

=method get_nodes

Get a list of nodes in the RabbitMQ cluster.

=cut

sub get_nodes {
    my ($self) = @_;

    return $self->request(
        method => 'GET',
        path   => '/nodes',
    );
}

=method get_node

Get an individual node in the RabbitMQ cluster.

=cut

sub get_node {
    my ( $self, %args ) = @_;
    croak 'Missing key in parameters: name' unless $args{name};

    return $self->request(
        method => 'GET',
        path   => sprintf( '/nodes/%s/', $args{name} ),
    );
}

=method get_extensions

Get a list of extensions to the management plugin.

=cut

sub get_extensions {
    my ($self) = @_;

    return $self->request(
        method => 'GET',
        path   => '/extensions',
    );
}

=method get_configuration

Get the server configuration.

=cut

sub get_configuration {
    my ($self) = @_;

    return $self->request(
        method => 'GET',
        path   => '/all-configuration',
    );
}

=method update_configuration

Upload an existing server configuration.

=cut

sub update_configuration {
    my ( $self, %args ) = @_;
    croak 'Missing key in parameters: users'       unless $args{users};
    croak 'Missing key in parameters: vhosts'      unless $args{vhosts};
    croak 'Missing key in parameters: permissions' unless $args{permissions};
    croak 'Missing key in parameters: queues'      unless $args{queues};
    croak 'Missing key in parameters: exchanges'   unless $args{exchanges};
    croak 'Missing key in parameters: bindings'    unless $args{bindings};

    return $self->request(
        method => 'POST',
        path   => '/all-configuration',
        data   => \%args,
    );
}

=method get_connections

Get a list of all open connections.

=cut

sub get_connections {
    my ($self) = @_;

    return $self->request(
        method => 'GET',
        path   => '/connections',
    );
}

=method get_connection

Get an individual connection.

=cut

sub get_connection {
    my ( $self, %args ) = @_;
    croak 'Missing key in parameters: name' unless $args{name};

    return $self->request(
        method => 'GET',
        path   => sprintf( '/connections/%s', $args{name} ),
    );
}

=method delete_connection

Close an individual connection.

=cut

sub delete_connection {
    my ( $self, %args ) = @_;
    croak 'Missing key in parameters: name' unless $args{name};

    return $self->request(
        method => 'DELETE',
        path   => sprintf( '/connections/%s', $args{name} ),
    );
}

=method get_channels

Get a list of all open channels.

=cut

sub get_channels {
    my ($self) = @_;

    return $self->request(
        method => 'GET',
        path   => '/channels',
    );
}

=method get_channel

Get details about an individual channel.

=cut

sub get_channel {
    my ( $self, %args ) = @_;
    croak 'Missing key in parameters: name' unless $args{name};

    return $self->request(
        method => 'GET',
        path   => sprintf( '/channels/%s', $args{name} ),
    );
}

=method get_exchanges

Get a list of all exchanges.

=cut

sub get_exchanges {
    my ($self) = @_;

    return $self->request(
        method => 'GET',
        path   => '/exchanges',
    );
}

=method get_exchanges_in_vhost

Get a list of all exchanges in a given virtual host.

=cut

sub get_exchanges_in_vhost {
    my ( $self, %args ) = @_;
    croak 'Missing key in parameters: vhost' unless $args{vhost};

    return $self->request(
        method => 'GET',
        path   => sprintf( '/exchanges/%s', $args{vhost} ),
    );
}

=method get_exchange

Get an individual exchange.

=cut

sub get_exchange {
    my ( $self, %args ) = @_;
    croak 'Missing key in parameters: name'  unless $args{name};
    croak 'Missing key in parameters: vhost' unless $args{vhost};

    return $self->request(
        method => 'GET',
        path   => sprintf( '/exchanges/%s/%s', $args{vhost}, $args{name} ),
    );
}

=method create_exchange

Create an individual exchange.

=cut

sub create_exchange {
    my ( $self, %args ) = @_;
    croak 'Missing key in parameters: name'  unless $args{name};
    croak 'Missing key in parameters: vhost' unless $args{vhost};
    croak 'Missing key in parameters: type'  unless $args{type};

    return $self->request(
        method => 'PUT',
        path   => sprintf( '/exchanges/%s/%s', delete $args{vhost}, delete $args{name} ),
        data   => \%args,
    );
}

=method delete_exchange

Delete an individual exchange.

=cut

sub delete_exchange {
    my ( $self, %args ) = @_;
    croak 'Missing key in parameters: name'  unless $args{name};
    croak 'Missing key in parameters: vhost' unless $args{vhost};

    return $self->request(
        method => 'DELETE',
        path   => sprintf( '/exchanges/%s/%s', $args{vhost}, $args{name} ),
    );
}

=method get_exchange_bindings_by_source

Get a list of all bindings in which a given exchange is the source.

=cut

sub get_exchange_bindings_by_source {
    my ( $self, %args ) = @_;
    croak 'Missing key in parameters: name'  unless $args{name};
    croak 'Missing key in parameters: vhost' unless $args{vhost};

    return $self->request(
        method => 'GET',
        path   => sprintf( '/exchanges/%s/%s/bindings/source', $args{vhost}, $args{name} ),
    );
}

=method get_exchange_bindings_by_destination

Get a list of all bindings in which a given exchange is the destination.

=cut

sub get_exchange_bindings_by_destination {
    my ( $self, %args ) = @_;
    croak 'Missing key in parameters: name'  unless $args{name};
    croak 'Missing key in parameters: vhost' unless $args{vhost};

    return $self->request(
        method => 'GET',
        path   => sprintf( '/exchanges/%s/%s/bindings/destination', $args{vhost}, $args{name} ),
    );
}

=method publish_message

Publish a message to a given exchange.

=cut

sub publish_message {
    my ( $self, %args ) = @_;
    croak 'Missing key in parameters: name'             unless $args{name};
    croak 'Missing key in parameters: vhost'            unless $args{vhost};
    croak 'Missing key in parameters: properties'       unless $args{properties};
    croak 'Missing key in parameters: routing_key'      unless $args{routing_key};
    croak 'Missing key in parameters: payload'          unless $args{payload};
    croak 'Missing key in parameters: payload_encoding' unless $args{payload_encoding};

    return $self->request(
        method => 'POST',
        path   => sprintf( '/exchanges/%s/%s/publish', delete $args{vhost}, delete $args{name} ),
        data   => \%args,
    );
}

=method get_queues

Get a list of all queues.

=cut

sub get_queues {
    my ($self) = @_;

    return $self->request(
        method => 'GET',
        path   => '/queues',
    );
}

=method get_queues_in_vhost

Get a list of all queues in a given virtual host.

=cut

sub get_queues_in_vhost {
    my ( $self, %args ) = @_;
    croak 'Missing key in parameters: vhost' unless $args{vhost};

    return $self->request(
        method => 'GET',
        path   => sprintf( '/queues/%s', $args{vhost} ),
    );
}

=method get_queue

Get an individual queue.

=cut

sub get_queue {
    my ( $self, %args ) = @_;
    croak 'Missing key in parameters: name'  unless $args{name};
    croak 'Missing key in parameters: vhost' unless $args{vhost};

    return $self->request(
        method => 'GET',
        path   => sprintf( '/queues/%s/%s', $args{vhost}, $args{name} ),
    );
}

=method create_queue

Create an individual queue.

=cut

sub create_queue {
    my ( $self, %args ) = @_;
    croak 'Missing key in parameters: name'  unless $args{name};
    croak 'Missing key in parameters: vhost' unless $args{vhost};

    return $self->request(
        method => 'PUT',
        path   => sprintf( '/queues/%s/%s', delete $args{vhost}, delete $args{name} ),
        data   => \%args,
    );
}

=method delete_queue

Delete an individual queue.

=cut

sub delete_queue {
    my ( $self, %args ) = @_;
    croak 'Missing key in parameters: name'  unless $args{name};
    croak 'Missing key in parameters: vhost' unless $args{vhost};

    return $self->request(
        method => 'DELETE',
        path   => sprintf( '/queues/%s/%s', $args{vhost}, $args{name} ),
    );
}

=method get_queue_bindings

Get a list of all bindings on a given queue.

=cut

sub get_queue_bindings {
    my ( $self, %args ) = @_;
    croak 'Missing key in parameters: name'  unless $args{name};
    croak 'Missing key in parameters: vhost' unless $args{vhost};

    return $self->request(
        method => 'GET',
        path   => sprintf( '/queues/%s/%s/bindings', $args{vhost}, $args{name} ),
    );
}

=method delete_queue_contents

Delete contents of a queue.

=cut

sub delete_queue_contents {
    my ( $self, %args ) = @_;
    croak 'Missing key in parameters: name'  unless $args{name};
    croak 'Missing key in parameters: vhost' unless $args{vhost};

    return $self->request(
        method => 'DELETE',
        path   => sprintf( '/queues/%s/%s/contents', $args{vhost}, $args{name} ),
    );
}

=method get_queue_messages

Get messages from a queue.

=cut

sub get_queue_messages {
    my ( $self, %args ) = @_;
    croak 'Missing key in parameters: name'     unless $args{name};
    croak 'Missing key in parameters: vhost'    unless $args{vhost};
    croak 'Missing key in parameters: encoding' unless $args{encoding};
    croak 'Missing key in parameters: count'    unless defined $args{count};
    croak 'Missing key in parameters: requeue'  unless defined $args{requeue};

    return $self->request(
        method => 'POST',
        path   => sprintf( '/queues/%s/%s/get', delete $args{vhost}, delete $args{name} ),
        data   => \%args,
    );
}

=method get_bindings

Get a list of all bindings.

=cut

sub get_bindings {
    my ($self) = @_;

    return $self->request(
        method => 'GET',
        path   => '/bindings',
    );
}

=method get_bindings_in_vhost

Get a list of all bindings in a given virtual host.

=cut

sub get_bindings_in_vhost {
    my ( $self, %args ) = @_;
    croak 'Missing key in parameters: vhost' unless $args{vhost};

    return $self->request(
        method => 'GET',
        path   => sprintf( '/bindings/%s', $args{vhost} ),
    );
}

=method get_bindings_between_exchange_and_queue

Get a list of all bindings between an exchange and a queue.

=cut

sub get_bindings_between_exchange_and_queue {
    my ( $self, %args ) = @_;
    croak 'Missing key in parameters: vhost'    unless $args{vhost};
    croak 'Missing key in parameters: exchange' unless $args{exchange};
    croak 'Missing key in parameters: queue'    unless $args{queue};

    return $self->request(
        method => 'GET',
        path   => sprintf( '/bindings/%s/e/%s/q/%s', $args{vhost}, $args{exchange}, $args{queue} ),
    );
}

=method create_bindings_between_exchange_and_queue

Create a new binding between an exchange and a queue.

=cut

sub create_bindings_between_exchange_and_queue {
    my ( $self, %args ) = @_;
    croak 'Missing key in parameters: vhost'       unless $args{vhost};
    croak 'Missing key in parameters: exchange'    unless $args{exchange};
    croak 'Missing key in parameters: queue'       unless $args{queue};
    croak 'Missing key in parameters: routing_key' unless $args{routing_key};
    croak 'Missing key in parameters: arguments'   unless $args{arguments};

    return $self->request(
        method => 'POST',
        path   => sprintf( '/bindings/%s/e/%s/q/%s', delete $args{vhost}, delete $args{exchange}, delete $args{queue} ),
        data   => \%args,
    );
}

=method get_binding

Get an individual binding between an exchange and a queue.

=cut

sub get_binding {
    my ( $self, %args ) = @_;
    croak 'Missing key in parameters: vhost'    unless $args{vhost};
    croak 'Missing key in parameters: exchange' unless $args{exchange};
    croak 'Missing key in parameters: queue'    unless $args{queue};
    croak 'Missing key in parameters: name'     unless $args{name};

    return $self->request(
        method => 'GET',
        path   => sprintf( '/bindings/%s/e/%s/q/%s/%s', $args{vhost}, $args{exchange}, $args{queue}, $args{name} ),
    );
}

=method create_binding

Create an individual binding between an exchange and a queue.

=cut

sub create_binding {
    my ( $self, %args ) = @_;
    croak 'Missing key in parameters: vhost'    unless $args{vhost};
    croak 'Missing key in parameters: exchange' unless $args{exchange};
    croak 'Missing key in parameters: queue'    unless $args{queue};
    croak 'Missing key in parameters: name'     unless $args{name};

    return $self->request(
        method => 'PUT',
        path   => sprintf( '/bindings/%s/e/%s/q/%s/%s', $args{vhost}, $args{exchange}, $args{queue}, $args{name} ),
    );
}

=method delete_binding

Delete an individual binding between an exchange and a queue.

=cut

sub delete_binding {
    my ( $self, %args ) = @_;
    croak 'Missing key in parameters: vhost'    unless $args{vhost};
    croak 'Missing key in parameters: exchange' unless $args{exchange};
    croak 'Missing key in parameters: queue'    unless $args{queue};
    croak 'Missing key in parameters: name'     unless $args{name};

    return $self->request(
        method => 'DELETE',
        path   => sprintf( '/bindings/%s/e/%s/q/%s/%s', $args{vhost}, $args{exchange}, $args{queue}, $args{name} ),
    );
}

=method get_vhosts

Get a list of all vhosts.

=cut

sub get_vhosts {
    my ($self) = @_;

    return $self->request(
        method => 'GET',
        path   => '/vhosts',
    );
}

=method get_vhost

Get an individual virtual host.

=cut

sub get_vhost {
    my ( $self, %args ) = @_;
    croak 'Missing key in parameters: name' unless $args{name};

    return $self->request(
        method => 'GET',
        path   => sprintf( '/vhosts/%s', $args{name} ),
    );
}

=method create_vhost

Create an individual virtual host.

=cut

sub create_vhost {
    my ( $self, %args ) = @_;
    croak 'Missing key in parameters: name' unless $args{name};

    return $self->request(
        method => 'PUT',
        path   => sprintf( '/vhosts/%s', $args{name} ),
    );
}

=method delete_vhost

Delete an individual virtual host.

=cut

sub delete_vhost {
    my ( $self, %args ) = @_;
    croak 'Missing key in parameters: name' unless $args{name};

    return $self->request(
        method => 'DELETE',
        path   => sprintf( '/vhosts/%s', $args{name} ),
    );
}

=method get_vhost_permissions

Get a list of all permissions for a given virtual host.

=cut

sub get_vhost_permissions {
    my ( $self, %args ) = @_;
    croak 'Missing key in parameters: name' unless $args{name};

    return $self->request(
        method => 'GET',
        path   => sprintf( '/vhosts/%s/permissions', $args{name} ),
    );
}

=method get_users

Get a list of all users.

=cut

sub get_users {
    my ($self) = @_;

    return $self->request(
        method => 'GET',
        path   => '/users',
    );
}

=method get_user

Get an individual user.

=cut

sub get_user {
    my ( $self, %args ) = @_;
    croak 'Missing key in parameters: name' unless $args{name};

    return $self->request(
        method => 'GET',
        path   => sprintf( '/users/%s', $args{name} ),
    );
}

=method create_user

Create an individual user.

=cut

sub create_user {
    my ( $self, %args ) = @_;
    croak 'Missing key in parameters: name' unless $args{name};
    croak 'Missing key in parameters: password or password_hash' unless $args{password} or $args{password_hash};

    return $self->request(
        method => 'PUT',
        path   => sprintf( '/users/%s', delete $args{name} ),
        data   => \%args,
    );
}

=method delete_user

Delete an individual user.

=cut

sub delete_user {
    my ( $self, %args ) = @_;
    croak 'Missing key in parameters: name' unless $args{name};

    return $self->request(
        method => 'DELETE',
        path   => sprintf( '/users/%s', $args{name} ),
    );
}

=method get_user_permissions

Get a list of all permissions for a given user.

=cut

sub get_user_permissions {
    my ( $self, %args ) = @_;
    croak 'Missing key in parameters: name' unless $args{name};

    return $self->request(
        method => 'GET',
        path   => sprintf( '/users/%s/permissions', $args{name} ),
    );
}

=method get_user_details

Get details of the currently authenticated user.

=cut

sub get_user_details {
    my ($self) = @_;

    return $self->request(
        method => 'GET',
        path   => '/whoami',
    );
}

=method get_users_permissions

Get a list of all permissions for all users.

=cut

sub get_users_permissions {
    my ($self) = @_;

    return $self->request(
        method => 'GET',
        path   => '/permissions',
    );
}

=method get_user_vhost_permissions

Get an individual permission of a user and virtual host.

=cut

sub get_user_vhost_permissions {
    my ( $self, %args ) = @_;
    croak 'Missing key in parameters: name'  unless $args{name};
    croak 'Missing key in parameters: vhost' unless $args{vhost};

    return $self->request(
        method => 'GET',
        path   => sprintf( '/permissions/%s/%s', $args{vhost}, $args{name} ),
    );
}

=method create_user_vhost_permissions

Create an individual permission of a user and virtual host.

=cut

sub create_user_vhost_permissions {
    my ( $self, %args ) = @_;
    croak 'Missing key in parameters: name'      unless $args{name};
    croak 'Missing key in parameters: vhost'     unless $args{vhost};
    croak 'Missing key in parameters: write'     unless $args{write};
    croak 'Missing key in parameters: read'      unless $args{read};
    croak 'Missing key in parameters: configure' unless $args{configure};

    return $self->request(
        method => 'PUT',
        path   => sprintf( '/permissions/%s/%s', delete $args{vhost}, delete $args{name} ),
        data   => \%args,
    );
}

=method delete_user_vhost_permissions

Delete an individual permission of a user and virtual host.

=cut

sub delete_user_vhost_permissions {
    my ( $self, %args ) = @_;
    croak 'Missing key in parameters: name'  unless $args{name};
    croak 'Missing key in parameters: vhost' unless $args{vhost};

    return $self->request(
        method => 'DELETE',
        path   => sprintf( '/permissions/%s/%s', $args{vhost}, $args{name} ),
    );
}

=method get_vhost_aliveness_test

Declares a test queue, then publishes and consumes a message.

=cut

sub get_vhost_aliveness_test {
    my ( $self, %args ) = @_;
    croak 'Missing key in parameters: vhost' unless $args{vhost};

    return $self->request(
        method => 'GET',
        path   => sprintf( '/aliveness-test/%s', $args{vhost} ),
    );
}

1;
