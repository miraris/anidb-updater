use Try::Tiny;
use LWP::UserAgent ();

my $proxy_agent = LWP::UserAgent->new;

# wow dirty, need to find out how this is written correctly..
sub setProxy {
    my ($ua) = @_;

    while (1) {
        try {
            my $proxy = $proxy_agent->get('https://gimmeproxy.com/api/getProxy?curl=true');
            print $proxy->decoded_content;
            $ua->proxy( [ 'http', 'https' ], $proxy->decoded_content );

            # test the proxy
            my $test = $ua->get('http://example.org');
            if ($test->is_success) {
                last;
            }
        } catch {
            print "Broken proxy?";
            sleep(1);
        }
    }

    return $ua;
}

1;
