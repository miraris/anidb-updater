use utf8;
use DBI;
require "./lib/helpers.pl";

#Debug
use Data::Dumper;
use feature qw(say);

# timestamp
my $timestamp = DateTime->now;

# pgsql connection
my $dsn = "DBI:Pg:dbname = noraneko2;host = 127.0.0.1;port = 5432";
my $dbh = DBI->connect( $dsn, "postgres", "", { RaiseError => 1 } )
  or die $DBI::errstr;

sub animeExists {
    my ($id) = @_;
    $count = $dbh->selectrow_array(
        "SELECT COUNT(*) FROM anime_map WHERE anidb_id=$id", undef );

    if ( $count > 0 ) {
        return 1;
    }
    return 0;
}

sub selectAnime {

    my $sql = "SELECT anime.id, anime_map.anidb_id
        FROM public.anime
        LEFT JOIN anime_map ON anime.id = anime_map.anime_id
        WHERE state_id != 0";

    my $anime_list = $dbh->selectall_arrayref( $sql, { Slice => {} } );

    return $anime_list;
}

sub updateAnime {
    my ( $id, %anime ) = @_;

    my $sth = $dbh->prepare(
"UPDATE anime SET episode_count = ?, start_date = ?, end_date = ?, state_id = ?, synopsis = ?, updated_at = ? WHERE id=$id"
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
"SELECT COUNT(*) FROM episodes WHERE anime_id=$id AND episode_number='$episode_number'",
            undef
        );

        if ( $count > 0 ) {
            next;
        }

        my $sth = $dbh->prepare(
'INSERT INTO episodes (anime_id, air_date, episode_number, episode_type_id, duration, created_at) VALUES (?, ?, ?, ?, ?, ?)'
        );

        $sth->execute( $id, $episode->{air_date}, $episode->{epno},
            $episode->{type}, $episode->{length}, $timestamp )
          or die "died, current anime ID: $id";

        #ep id
        my $episode_id = $dbh->last_insert_id( undef, undef, undef, undef,
            { sequence => 'episodes_id_seq' } );

        for $title ( @{ $episode->{titles} } ) {
            my $sth = $dbh->prepare(
'INSERT INTO episode_titles (episode_id, title, language_id, created_at) VALUES (?, ?, ?, ?)'
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
'INSERT INTO anime (synopsis, start_date, end_date, state_id, type_id, episode_count, created_at)
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
'INSERT INTO anime_titles (title, anime_id, language_id, title_type_id, created_at)
    VALUES (?, ?, ?, ?, ?)'
        );

        $sth->execute( $titles{title}, $id, $titles{lang},
            $titles{type}, $timestamp )
          or die "died, current anime ID: $id";
    }
}

sub insertPicture {
    my ( $id, $picture ) = @_;

    my $sth =
      $dbh->prepare('INSERT INTO posters (anime_id, anidb) VALUES (?, ?)');

    $sth->execute( $id, $picture )
      or die "died, current anime ID: $id";
}

sub insertEpisodes {
    my ( $id, @episodes ) = @_;

    foreach my $episode (@episodes) {

        my $sth = $dbh->prepare(
'INSERT INTO episodes (anime_id, air_date, episode_number, duration, episode_type_id, created_at) VALUES (?, ?, ?, ?, ?, ?)'
        );

        $sth->execute( $id, $episode->{air_date}, $episode->{epno},
            $episode->{length}, $episode->{type}, $timestamp )
          or die "died, current anime ID: $id";

        #ep id
        my $episode_id = $dbh->last_insert_id( undef, undef, undef, undef,
            { sequence => 'episodes_id_seq' } );

        for $title ( @{ $episode->{titles} } ) {
            my $sth = $dbh->prepare(
'INSERT INTO episode_titles (episode_id, title, language_id, created_at) VALUES (?, ?, ?, ?)'
            );
            $sth->execute( $episode_id, $title->{title},
                $title->{lang}, $timestamp )
              or die "died, episode_id: $episode_id";
        }
    }
}

sub map {

}

1;
