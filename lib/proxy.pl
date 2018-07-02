use Try::Tiny;
use LWP::Simple;

# Such a mess
# TODO: save the last proxy list to a file (JSON?), and set banned flags on them
sub setProxy {
    my ($ua) = @_;

    while (1) {
        my $proxy_dump = './proxy.txt';
        my $proxy_dump_mod =
          DateTime->now->subtract_datetime_absolute(
            DateTime->from_epoch( epoch => ( stat($proxy_dump) )[9] ) )
          ->seconds()
          if -e $proxy_dump;

        if ( !defined($proxy_dump_mod) || $proxy_dump_mod > 3600 ) {
            print "Fetching a new proxy list.\n";

            # Fetch and save.
            my $content = getstore( "http://spys.me/proxy.txt", 'proxy.txt' );
            die "Can't get the proxy list" unless defined $content;
        }

        open( my $fh, "<", $proxy_dump )
          or die "Unable to open < proxy.txt: $!";
        my @lines = <$fh>;
        chomp(@lines);

        @proxy_list = grep { /((\d{1,3}.){3}\d{1,3}:\d+)/ } @lines;
        for (@proxy_list) {
            s/\s.*//;    # remove everything post-whitespace
        }

        my $random_proxy = $proxy_list[ rand @proxy_list ];
        my $proxy        = "http://$random_proxy";

        try {
            $ua->proxy( [ 'http', 'https' ], $proxy );
        }
        catch {
            print "Failed to set $proxy, skipping this iteration?\n";
            next;
        };

        # test the proxy
        my $test = $ua->get('http://example.org');
        if ( $test->is_success ) {
            print "Nice, successfully set a proxy: $proxy\n";

            # break out of the loop
            last;
        }
        print
"Huh? Couldn't request anything using that proxy ($proxy)? Looping again.\n";
    }

    # return $ua;
    $ENV{'HTTP_PROXY'} = $proxy;
}

1;
