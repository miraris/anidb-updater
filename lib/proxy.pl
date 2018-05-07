use Try::Tiny;
use LWP::Simple;

# wow dirty, need to find out how this is written correctly..
sub setProxy {
    my ($ua) = @_;

    while (1) {
        my $proxy = get("https://gimmeproxy.com/api/getProxy?protocol=http&curl=true");

        try {
            $ua->proxy( [ 'http', 'https' ], $proxy );
        } catch {
            sleep(3);
            next;
        };

        # test the proxy
        my $test = $ua->get('http://example.org');
        if ( $test->is_success ) {
            print "Fetched a new proxy: $proxy\n";

            # break out of the loop
            last;
        }
    }

    return $ua;
}

1;
