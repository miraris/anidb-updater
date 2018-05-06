use LWP::UserAgent ();

# user agent options
my %options =
  ( 'agent' =>
'Mozilla/5.0 (Windows NT 6.1; WOW64) AppleWebKit/535.11 (KHTML, like Gecko) Chrome/17.0.963.56 Safari/535.11',
  );

my $ua = LWP::UserAgent->new(%options);

sub getAnime {
    my ($id) = @_;

    # debug
    $id = 357;

    $url = "http://api.anidb.net:9001/httpapi?request=anime&client=alastorehttp&clientver=1&protover=1&aid=$id";
    my $response = $ua->get($url);

    if ( $response->is_success ) {
        return $response->decoded_content;
    }
}

1;
