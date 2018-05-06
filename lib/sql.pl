use utf8;
use DBI;
require "./lib/helpers.pl";

#Debug
use Data::Dumper;
use feature qw(say);

# pgsql connection
my $dsn = "DBI:Pg:dbname = noraneko2;host = 127.0.0.1;port = 5432";
my $dbh = DBI->connect( $dsn, "postgres", "", { RaiseError => 1 } )
  or die $DBI::errstr;

sub selectAnime {
    my $sql = "SELECT anime.id, anime_map.anidb_id
        FROM public.anime
        LEFT JOIN anime_map ON anime.id = anime_map.anime_id
        WHERE state_id != 0 OFFSET 9 LIMIT 1";

    my $anime_list = $dbh->selectall_arrayref( $sql, { Slice => {} } );

    return $anime_list;
}

sub updateAnime {
    my ( $id, %anime ) = @_;

    # say Dumper(%anime);
}

sub updatePicture {
    my ( $id, $poster ) = @_;

    say $poster;
}

sub updateTitles {
    my ( $id, @titles ) = @_;

    # say Dumper(@titles);
}

sub updateEpisodes {
    my ( $id, @episodes ) = @_;

    foreach my $episode (@episodes) {

        # say ($episode->{titles}[0]->{title});
        $sth = $dbh->prepare(
"SELECT COUNT(*) FROM episodes WHERE anime_id = ? AND episode_number = ?"
        );

        $sth->execute( $id, $episode->{episode_number} );

        unless ( $sth->fetchrow_array ) {
            say 'nope';
        }

        # for $title ( @{ $episode->{titles} } ) {
        #     say $title->{title};
        # }
    }

    # foreach my @episodes( keys %{ $grades{$name} } ) {
    #     print "$name, $subject: $grades{$name}{$subject}\n";
    # }

}

1;
