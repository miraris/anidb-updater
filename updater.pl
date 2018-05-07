#!/usr/bin/perl
my $APP = 'updater';
use vars qw($VERSION);
$VERSION = '0.1.0';

use strict;
use warnings;
use utf8;

use DateTime;
use Pod::Usage;
use Getopt::Long;
use XML::LibXML;
use LWP::Simple;
use IO::Uncompress::Gunzip qw(gunzip $GunzipError);
use Term::ProgressBar 2.00;

#Debug
use Data::Dumper;
use feature qw(say);

# requires
require "./lib/httpclient.pl";
require "./lib/parser.pl";
require "./lib/sql.pl";

# Title dump file path
my $title_dump = './anime-titles.xml';

# difference between current timestamp and title dump mod time
my $title_dump_mod =
  DateTime->now->subtract_datetime_absolute(
    DateTime->from_epoch( epoch => ( stat($title_dump) )[9] ) )->seconds();

my $partial = '';
my $new = '';
my $full = '';

GetOptions(
    'partial' => \$partial,
    'new'     => \$new,
    'full'    => \$full,

    'm|man'  => sub { pod2usage( verbose => 3 ); },
    'h|help' => sub { pod2usage( verbose => 1 ); },
    'v|version' => sub { print "$APP v$VERSION\n" and exit 0; },
);

# Run
if ( $partial || $full ) {
    update();
}
if ( $new || $full ) {
    new();
}

sub update {
    my $anime_list = selectAnime();
    my $max        = scalar(@$anime_list);
    my $progress   = Term::ProgressBar->new(
        { name => 'Updating', count => $max, ETA => 'linear' } );

    foreach my $item (@$anime_list) {

        if ( $item->{anidb_id} == 357 ) {
            next;
        }

        my $data = getAnime( $item->{anidb_id} );

        if ($data == 0) {
            next;
        }

        $data = XML::LibXML->load_xml( string => $data );

        my %anime    = parseAnime($data);
        my @episodes = parseEpisodes($data);

        updateAnime( $item->{id}, %anime );
        updateEpisodes( $item->{id}, @episodes );

        $progress->update($_);

        sleep(2);
    }
    $progress->update($max);

}

sub new {

    # Do not download the titles dump if it has been fetched during 24 hours
    unless ( $title_dump_mod < 86400 ) {
        say
"Title dump modification time is lower than 24 hours, using existing.\n";

        # Fetch it.
        my $content = getstore( "http://anidb.net/api/anime-titles.xml.gz",
            'anime-titles.xml.gz' );
        die "Can't get the title dump?" unless defined $content;
        gunzip 'anime-titles.xml.gz' => $title_dump
          or die "Decompression failed: $GunzipError\n";
    }

    my $data = XML::LibXML->load_xml( location => $title_dump );

    my $counter = 0;
    foreach my $title ( $data->findnodes('//animetitles/anime') ) {

        my $anidb_id = $title->getAttribute('aid');
        unless ( animeExists($anidb_id) ) {
            my $data = getAnime($anidb_id);

            # Parse
            my %anime    = parseAnime($data);
            my $picture  = parsePicture($data);
            my @titles   = parseTitles($data);
            my @episodes = parseEpisodes($data);

            # Insert
            my $local_id = insertAnime(%anime);
            insertPicture( $local_id, $picture );
            insertEpisodes( $local_id, @episodes );
            insertTitles( $local_id, @titles );
        }
    }
}

__END__

=pod

=head1 NAME

Noraneko updater

=head1 USAGE

updater.pl [OPTIONS..]

=head1 DESCRIPTION

Updates the noraneko database by selecting unknown/ongoing anime
and performing queries to AniDB.

=head1 OPTIONS

=head3 Update type

  --full    Full update, updates existing then fetches new anime
  --partial Only updates ongoing & unknown anime
  --new     Only fetches new anime

=head3 Documentation

  --help  show the help and exit
  --man   show the manpage and exit

=head1 AUTHOR

  Miraris
  miraris@autistici.org
  https://miraris.me

=head1 LICENSE

MIT License

Copyright (c) 2018 Miraris

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.


=cut
