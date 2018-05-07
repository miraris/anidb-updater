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
sub failedRequest {
    my ($text) = @_;

    if (   $text eq '<error>Anime not found</error>'
        || $text eq '<error code="500">banned</error>' )
    {
        return 1;
    }
    return 0;
}

sub getAnime {
    my ($id) = @_;

    $url =
"http://api.anidb.net:9001/httpapi?request=anime&client=alastorehttp&clientver=1&protover=1&aid=$id";
    my $response = $ua->get($url);

    while ( !$response->is_success
        || failedRequest( $response->decoded_content ) )
    {
        $ua = setProxy($ua);
        $response = $ua->get($url);
    }

    return $response->decoded_content;
}

1;
