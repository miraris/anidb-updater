use Try::Tiny;
use LWP::Simple;
# use JSON;

# wow dirty, need to find out how this is written correctly..
sub setProxy {
    my ($ua) = @_;

    while (1) {
        # just sleep before sending the request, doesn't matter what subrouting we come from
        sleep(5);
        # my $response =
        #   get("http://pubproxy.com/api/proxy?type=http&format=txt");
        # $response = decode_json $json;
        # my $proxy_ip = $response->{ip};
        # my $proxy_port = $response->{port};
        my $proxy = "http://188.192.138.183:80";

        try {
            $ua->proxy( [ 'http', 'https' ], $proxy );
        }
        catch {
            print "Failed to set $proxy, skipping this iteration?\n";
            sleep(5);
            next;
        };

        # test the proxy
        my $test = $ua->get('http://example.org');
        if ( $test->is_success ) {
            print "Nice, successfully set a proxy: $proxy\n";

            # break out of the loop
            last;
        }
        print "Huh? Couldn't request anything using that proxy ($proxy)? Looping again.\n";
    }

    return $ua;
}

1;
