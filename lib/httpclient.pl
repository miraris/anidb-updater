use LWP::UserAgent ();

require "./lib/proxy.pl";

# user agent options
my %options =
  ( 'agent' =>
'Mozilla/5.0 (Windows NT 6.1; WOW64) AppleWebKit/535.11 (KHTML, like Gecko) Chrome/17.0.963.56 Safari/535.11',
  );

my $ua = LWP::UserAgent->new(%options);
$ua->timeout(10);
$ua = setProxy($ua);

# TODO: better validation
sub getAnime {
    my ($id) = @_;

    $url =
"http://api.anidb.net:9001/httpapi?request=anime&client=alastorehttp&clientver=1&protover=1&aid=$id";
    my $response = $ua->get($url);

    my $data = $response->decoded_content

    # Don't try to fetch request a proxy for this
    if ($text eq '<error>Anime not found</error>') {
        return 0;
    }

    while ( !$response->is_success
        || $data eq '<error code="500">banned</error>' )
    {
        # do they keep banning on the same request?
        print $id;
        print $data;

        $ua = setProxy($ua);
        $response = $ua->get($url);
    }

    return $response->decoded_content;
}

1;
