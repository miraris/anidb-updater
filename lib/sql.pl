use utf8;
use DBI;
use JSON;
require "./lib/helpers.pl";

#Debug
use Data::Dumper;
use feature qw(say);

# timestamp
my $timestamp = DateTime->now;


my $json_config = do {
   open(my $json_fh, "<:encoding(UTF-8)", 'db.json')
      or die("Can't open \$filename\": $!\n");
   local $/;
   <$json_fh>
};
my $config = JSON::decode_json($json_config);

# pgsql connection
my $dsn = "DBI:Pg:dbname = $config->{dbname};host = 127.0.0.1;port = 5432";
my $dbh =
  DBI->connect( $dsn, $config->{dbuser}, $config->{dbpass},
    { RaiseError => 1 } )
  or die $DBI::errstr;

# anime.id to noraneko.anime.id (i.e)
sub selectMAL {
    my $sql = "SELECT anime.id, anime_map.mal_id
        FROM noraneko.anime
        LEFT JOIN noraneko.anime_map ON anime.id = anime_map.anime_id
        WHERE mal_id IS NOT NULL";

    my $anime_list = $dbh->selectall_arrayref( $sql, { Slice => {} } );

    return $anime_list;
}

sub syncAnime {
    my ( $id, $rank, $poster ) = @_;

    my $sth = $dbh->prepare(
        "UPDATE noraneko.anime SET rank = ?, updated_at = ? WHERE id=$id");
    $sth->execute( $rank, $timestamp ) or die "died, current anime ID: $id";

    my $sth =
      $dbh->prepare(
        "UPDATE noraneko.poster SET anime_id = ?, mal = ? WHERE id=$id");

    $sth->execute( $id, $poster )
      or die "died, current anime ID: $id";
}

sub animeExists {
    my ($id) = @_;
    $count = $dbh->selectrow_array(
        "SELECT COUNT(*) FROM noraneko.anime_map WHERE anidb_id=$id", undef );

    if ( $count > 0 ) {
        return 1;
    }
    return 0;
}

sub selectAnime {

    my $sql = "SELECT anime.id, anime_map.anidb_id
        FROM noraneko.anime
        LEFT JOIN noraneko.anime_map ON anime.id = anime_map.anime_id
        WHERE state_id != 0";

    my $anime_list = $dbh->selectall_arrayref( $sql, { Slice => {} } );

    return $anime_list;
}

sub updateAnime {
    my ( $id, %anime ) = @_;

    my $sth = $dbh->prepare(
"UPDATE noraneko.anime SET episode_count = ?, start_date = ?, end_date = ?, state_id = ?, synopsis = ?, updated_at = ? WHERE id=$id"
    );

    $synopsis = $anime{description};

    if ( $synopsis eq '' ) {
        $synopsis = undef;
    }

    $sth->execute( $anime{episode_count}, $anime{start_date}, $anime{end_date},
        $anime{state_id}, $synopsis, $timestamp )
      or die "died, current anime ID: $id";
}

sub updateEpisodes {
    my ( $id, @episodes ) = @_;

    foreach my $episode (@episodes) {
        my $episode_number = $episode->{epno};
        my $count          = $dbh->selectrow_array(
"SELECT COUNT(*) FROM noraneko.episode WHERE anime_id=$id AND episode_number='$episode_number'",
            undef
        );

        if ( $count > 0 ) {
            next;
        }

        my $sth = $dbh->prepare(
'INSERT INTO noraneko.episode (anime_id, air_date, episode_number, episode_type_id, duration, created_at) VALUES (?, ?, ?, ?, ?, ?)'
        );

        $sth->execute( $id, $episode->{air_date}, $episode->{epno},
            $episode->{type}, $episode->{length}, $timestamp )
          or die "died, current anime ID: $id";

        #ep id
        my $episode_id = $dbh->last_insert_id( undef, undef, undef, undef,
            { sequence => 'episodes_id_seq' } );

        for $title ( @{ $episode->{titles} } ) {
            my $sth = $dbh->prepare(
'INSERT INTO noraneko.episode_title (episode_id, title, language_id, created_at) VALUES (?, ?, ?, ?)'
            );
            $sth->execute( $episode_id, $title->{title}, $title->{lang},
                $timestamp )
              or die "died, episode_id: $episode_id";
        }
    }
}

sub insertAnime {
    (%anime) = @_;
    $synopsis = $anime{description};

    if ( $synopsis eq '' ) {
        $synopsis = undef;
    }

    my $sth = $dbh->prepare(
'INSERT INTO noraneko.anime (synopsis, start_date, end_date, state_id, type_id, episode_count, created_at)
VALUES (?, ?, ?, ?, ?, ?, ?)'
    );

    $sth->execute( $synopsis, $anime{start_date}, $anime{end_date},
        $anime{state_id}, $anime{type}, $anime{episode_count}, $timestamp )
      or die "died, current anime ID: $id";

    return $dbh->last_insert_id( undef, undef, undef, undef,
        { sequence => 'anime_id_seq' } );
}

sub insertTitles {
    my ( $id, @titles ) = @_;

    foreach my $title (@titles) {
        my $sth = $dbh->prepare(
'INSERT INTO noraneko.anime_title (title, anime_id, language_id, title_type_id, created_at)
    VALUES (?, ?, ?, ?, ?)'
        );

        $sth->execute( $title->{title}, $id, $title->{lang},
            $title->{type}, $timestamp )
          or die "died, current anime ID: $id";
    }
}

sub insertPicture {
    my ( $id, $picture ) = @_;

    my $sth =
      $dbh->prepare(
        'INSERT INTO noraneko.poster (anime_id, anidb) VALUES (?, ?)');

    $sth->execute( $id, $picture )
      or die "died, current anime ID: $id";
}

sub insertEpisodes {
    my ( $id, @episodes ) = @_;

    foreach my $episode (@episodes) {

        my $sth = $dbh->prepare(
'INSERT INTO noraneko.episode (anime_id, air_date, episode_number, duration, episode_type_id, created_at) VALUES (?, ?, ?, ?, ?, ?)'
        );

        $sth->execute( $id, $episode->{air_date}, $episode->{epno},
            $episode->{length}, $episode->{type}, $timestamp )
          or die "died, current anime ID: $id";

        #ep id
        my $episode_id = $dbh->last_insert_id( undef, undef, undef, undef,
            { sequence => 'episodes_id_seq' } );

        for $title ( @{ $episode->{titles} } ) {
            my $sth = $dbh->prepare(
'INSERT INTO noraneko.episode_title (episode_id, title, language_id, created_at) VALUES (?, ?, ?, ?)'
            );
            $sth->execute( $episode_id, $title->{title},
                $title->{lang}, $timestamp )
              or die "died, episode_id: $episode_id";
        }
    }
}

sub mapAnime {
    my ( $id, $anidb_id ) = @_;

    my $sth =
      $dbh->prepare(
        'INSERT INTO noraneko.anime_map (anime_id, anidb_id) VALUES (?, ?)');

    $sth->execute( $id, $anidb_id )
      or die "died, current anime ID: $id";
}

1;
