use utf8;
use feature qw(say);
use Data::Dumper;

require "./lib/sql.pl";
require "./lib/types.pl";
require "./lib/helpers.pl";

# parse the dom and return hash with some values
sub parseAnime {
    my ($dom) = @_;

    $start_date = parseDate( $dom->findvalue('//anime/startdate') );
    $end_date   = parseDate( $dom->findvalue('//anime/enddate') );

    return (
        'type'          => $types{ $dom->findvalue('//anime/type') },
        'episode_count' => $dom->findvalue('//anime/episodecount'),
        'start_date'    => $start_date,
        'end_date'      => $end_date,
        'state_id'      => getState( $start_date, $end_date ),
        'description' =>
          cleanSynopsis( $dom->findvalue('//anime/description') ),
    );
}

# parse titles and return a titles array
sub parseTitles {
    my ($anime) = @_;
    @titles = ();

    foreach my $title ( $anime->findnodes('//anime/titles/title') ) {
        push @titles,
          {
            lang  => $languages{ $title->findvalue('@xml:lang') },
            type  => $title_types{ $title->findvalue('@type') },
            title => $title->to_literal()
          };
    }

    return @titles;
}

# parse the nudes
sub parsePicture {
    my ($dom) = @_;
    return $dom->findvalue('//anime/picture');
}

# parse episodes and it's titles, returns a relatively complex data structure
sub parseEpisodes {
    my ($dom) = @_;
    @episodes = ();

    foreach my $episode ( $dom->findnodes('//anime/episodes/episode') ) {
        my @titles;

        foreach my $title ( $episode->findnodes('./title') ) {
            push(
                @titles,
                {
                    lang  => $languages{ $title->findvalue('@xml:lang') },
                    title => $title->to_literal()
                }
            );
        }

        push(
            @episodes,
            {
                epno     => $episode->findvalue('epno'),
                type     => $episode->findvalue('epno/@type'),
                air_date => parseDate( $episode->findvalue('airdate') ),
                length   => $episode->findvalue('./length'),
                titles   => [@titles]
            }
        );
    }

    return @episodes;
}

1;
