use utf8;
use DBI;
use JSON;
require "./lib/helpers.pl";

#Debug
use feature qw(say);


my %config = (
    name => $ENV{"POSTGRES_DB"},
    user => $ENV{"POSTGRES_USER"},
    pass => $ENV{"POSTGRES_PASSWORD"},
    host => $ENV{"POSTGRES_HOST"}
);

# pgsql connection
my $dsn = "DBI:Pg:dbname = $config{name};host = $config{host};port = 5432";
my $dbh =
  DBI->connect( $dsn, $config{user}, $config{pass}, { RaiseError => 1 } )
  or die $DBI::errstr;

# anime.id to nekoani_public.anime.id (i.e)
sub selectMAL {
    my $sql = "SELECT anime.id, anime_mappings.mal_id
        FROM nekoani_public.anime
        LEFT JOIN nekoani_public.anime_mappings ON anime.id = anime_mappings.anime_id
        WHERE mal_id IS NOT NULL";

    my $anime_list = $dbh->selectall_arrayref( $sql, { Slice => {} } );

    return $anime_list;
}

sub syncAnime {
    my ( $id, $rank, $poster ) = @_;

    my $sth = $dbh->prepare(
        "UPDATE nekoani_public.anime SET rank = ? WHERE id=$id");
    $sth->execute( $rank, ) or die "died, current anime ID: $id";

    my $sth =
      $dbh->prepare(
        "UPDATE nekoani_public.posters SET anime_id = ?, mal = ? WHERE id=$id");

    $sth->execute( $id, $poster )
      or die "died, current anime ID: $id";
}

sub animeExists {
    my ($id) = @_;
    $count = $dbh->selectrow_array(
        "SELECT COUNT(*) FROM nekoani_public.anime_mappings WHERE anidb_id=$id", undef );

    if ( $count > 0 ) {
        return 1;
    }
    return 0;
}

sub selectAnime {

    my $sql = "SELECT anime.id, anime_mappings.anidb_id
        FROM nekoani_public.anime
        LEFT JOIN nekoani_public.anime_mappings ON anime.id = anime_mappings.anime_id
        WHERE state_id != 0";

    my $anime_list = $dbh->selectall_arrayref( $sql, { Slice => {} } );

    return $anime_list;
}

sub updateAnime {
    my ( $id, %anime ) = @_;

    my $sth = $dbh->prepare(
"UPDATE nekoani_public.anime SET episode_count = ?, start_date = ?, end_date = ?, state_id = ?, synopsis = ? WHERE id = $id"
    );

    $synopsis = $anime{description};

    if ( $synopsis eq '' ) {
        $synopsis = undef;
    }

    $sth->execute( $anime{episode_count}, $anime{start_date}, $anime{end_date},
        $anime{state_id}, $synopsis )
      or die "died, current anime ID: $id";
}

sub updateEpisodes {
    my ( $id, @episodes ) = @_;

    foreach my $episode (@episodes) {
        my $episode_number = $episode->{epno};
        my $count          = $dbh->selectrow_array(
"SELECT COUNT(*) FROM nekoani_public.episodes WHERE anime_id=$id AND episode_number='$episode_number'",
            undef
        );

        if ( $count > 0 ) {
            next;
        }

        my $sth = $dbh->prepare(
'INSERT INTO nekoani_public.episodes (anime_id, air_date, episode_number, episode_type_id, duration) VALUES (?, ?, ?, ?, ?)'
        );

        $sth->execute( $id, $episode->{air_date}, $episode->{epno},
            $episode->{type}, $episode->{length} )
          or die "died, current anime ID: $id";

        #ep id
        my $episode_id = $dbh->last_insert_id( undef, undef, undef, undef,
            { sequence => 'nekoani_public.episodes_id_seq' } );

        for $title ( @{ $episode->{titles} } ) {
            my $sth = $dbh->prepare(
'INSERT INTO nekoani_public.episode_titles (episode_id, title, language_id) VALUES (?, ?, ?)'
            );
            $sth->execute( $episode_id, $title->{title}, $title->{lang} )
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
'INSERT INTO nekoani_public.anime (synopsis, start_date, end_date, state_id, type_id, episode_count)
VALUES (?, ?, ?, ?, ?, ?)'
    );

    $sth->execute( $synopsis, $anime{start_date}, $anime{end_date},
        $anime{state_id}, $anime{type}, $anime{episode_count} )
      or die "died, current anime ID: $id";

    return $dbh->last_insert_id( undef, undef, undef, undef,
        { sequence => 'nekoani_public.anime_id_seq' } );
}

sub insertTitles {
    my ( $id, @titles ) = @_;

    foreach my $title (@titles) {
        my $sth = $dbh->prepare(
'INSERT INTO nekoani_public.anime_titles (title, anime_id, language_id, title_type_id)
    VALUES (?, ?, ?, ?)'
        );

        $sth->execute( $title->{title}, $id, $title->{lang},
            $title->{type} )
          or die "died, current anime ID: $id";
    }
}

sub insertPicture {
    my ( $id, $picture ) = @_;

    my $sth =
      $dbh->prepare(
        'INSERT INTO nekoani_public.posters (anime_id, anidb) VALUES (?, ?)');

    $sth->execute( $id, $picture )
      or die "died, current anime ID: $id";
}

sub insertEpisodes {
    my ( $id, @episodes ) = @_;

    foreach my $episode (@episodes) {

        my $sth = $dbh->prepare(
'INSERT INTO nekoani_public.episodes (anime_id, air_date, episode_number, duration, episode_type_id) VALUES (?, ?, ?, ?, ?)'
        );

        $sth->execute( $id, $episode->{air_date}, $episode->{epno},
            $episode->{length}, $episode->{type} )
          or die "died, current anime ID: $id";

        #ep id
        my $episode_id = $dbh->last_insert_id( undef, undef, undef, undef,
            { sequence => 'nekoani_public.episodes_id_seq' } );

        for $title ( @{ $episode->{titles} } ) {
            my $sth = $dbh->prepare(
'INSERT INTO nekoani_public.episode_titles (episode_id, title, language_id) VALUES (?, ?, ?)'
            );
            $sth->execute( $episode_id, $title->{title},
                $title->{lang} )
              or die "died, episode_id: $episode_id";
        }
    }
}

sub mapAnime {
    my ( $id, $anidb_id ) = @_;

    my $sth =
      $dbh->prepare(
        'INSERT INTO nekoani_public.anime_mappings (anime_id, anidb_id) VALUES (?, ?)');

    $sth->execute( $id, $anidb_id )
      or die "died, current anime ID: $id";
}

1;
