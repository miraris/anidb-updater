use LWP::UserAgent ();

require "./lib/proxy.pl";

# user agent options
my %options =
  ( 'agent' =>
'Mozilla/5.0 (Windows NT 6.1; WOW64) AppleWebKit/535.11 (KHTML, like Gecko) Chrome/17.0.963.56 Safari/535.11',
  );

my $ua = LWP::UserAgent->new(%options);
$ua->timeout(10);
$ua->no_proxy('api.myanimelist.net');
$ua->env_proxy;
setProxy($ua);

# TODO: better validation
sub getAnime {
    my ($id)      = @_;
    my $NOT_FOUND = '<error>Anime not found</error>';
    my $BANNED    = '<error code="500">banned</error>';
    my $ANIME     = '<anime id=';

    my $url =
"http://api.anidb.net:9001/httpapi?request=anime&client=alastorehttp&clientver=1&protover=1&aid=$id";
    my $response = $ua->get($url);
    my $data     = $response->decoded_content;

    # Don't try to fetch request a proxy for this
    if ( $data =~ /\Q$NOT_FOUND\E/ ) { return ( error => 404 ); }

    # An actual ban
    if ( $data =~ /\Q$BANNED\E/ ) {
        print $id. "\n";
        print $data. "\n";
        setProxy($ua);
        return ( error => 500 );
    }

# Probably proxy or internal server errors, also pushing this into the banned list..
    unless ( $response->is_success || $data =~ /\Q$ANIME\E/ ) {
        print $data;
        print "Failed on anime $id, fetching a new proxy.\n";
        setProxy($ua);
        return ( error => 500 );
    }

    return ( content => $data );
}

1;
