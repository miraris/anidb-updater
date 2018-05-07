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

    my $data = $response->decoded_content;

    # Don't try to fetch request a proxy for this
    if ( $data eq '<error>Anime not found</error>' ) {
        return ( error => 404 );
    }

    if ( $data eq '<error code="500">banned</error>' ) {
        print $id. "\n";
        print $data. "\n";
        return ( error => 500 );
    }

    # should probably handle this in a better way,
    # but for now just set a proxy and move onto
    # another anime. (this implies multiple script executions)
    while ( !$response->is_success ) {
        $ua       = setProxy($ua);
        $response = $ua->get($url);
    }

    return ( content => $response->decoded_content );
}

1;
