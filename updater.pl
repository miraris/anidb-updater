#!/usr/bin/perl
my $APP = 'updater';
use vars qw($VERSION);
$VERSION = '0.1.0';

use strict;
use warnings;
use utf8;

# requires for packaging
use arybase;
use DateTime;
use DBI;
use JSON;
use List::Util qw(shuffle);
use Pod::Usage;
use Getopt::Long;
use XML::LibXML;
use LWP::Simple;
use IO::Uncompress::Gunzip qw(gunzip $GunzipError);
use Regexp::Common qw(URI);
use Term::ProgressBar 2.00;
use Try::Tiny;

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
my $new     = '';
my $full    = '';
my $sync    = '';

GetOptions(
    'partial' => \$partial,
    'new'     => \$new,
    'full'    => \$full,
    'sync'    => \$sync,

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
if ( $sync ) {
    sync();
}
unless ( $partial || $new || $full || $sync ) {
    die("No args supplied.");
}

sub sync {
    my $mal_list = selectMAL();

    my $max        = scalar(@$mal_list);
    my $progress   = Term::ProgressBar->new(
        { name => 'Synchronizing', count => $max, ETA => 'linear' } );

    foreach my $item (@$mal_list) {
        my $content = get("https://api.myanimelist.net/v0.8/anime/$item->{mal_id}?fields=mean,rank,popularity,num_list_users,num_scoring_users");
        unless (defined $content) {
            say "Couldn't get the anime.";
            $progress->update(1);
            next;
        }

        say $content;
        my $data = decode_json($content);
        syncAnime($item->{id}, $data->{rank}, $data->{main_picture}->{large});
        $progress->update(1);
    }
}

sub update {
    my $anime_list = selectAnime();
    my $max        = scalar(@$anime_list);
    my $progress   = Term::ProgressBar->new(
        { name => 'Updating', count => $max, ETA => 'linear' } );
    my @banned_list = ();

    foreach my $item (@$anime_list) {

        if ( $item->{anidb_id} == 357 ) {
            next;
        }

        # fetch it
        my %data = getAnime( $item->{anidb_id} );

        if ( defined( $data{error} ) && $data{error} == 500 ) {
            push @banned_list, $item->{anidb_id};
            next;
        }

        # animu doesn't even exist
        if ( defined( $data{error} ) && $data{error} == 404 ) {
            next;
        }

        # again.. implies multiple script executions
        try {
            my $oof = XML::LibXML->load_xml( string => $data{content} );

            my %anime    = parseAnime($oof);
            my @episodes = parseEpisodes($oof);

            updateAnime( $item->{id}, %anime );
            updateEpisodes( $item->{id}, @episodes );

            $progress->update(1);
        }
        catch {
            say "Couldn't load the XML string, skipping.";
            $progress->update(1);

            next;
        };

        sleep(2);
    }
    $progress->update($max);

}

sub new {

# Only download the titles dump if it hasn't been fetched during the last 24 hours
    unless ( $title_dump_mod < 86400 ) {
        say "Fetching a new titles dump.\n";

        # Fetch it.
        my $content = getstore( "http://anidb.net/api/anime-titles.xml.gz",
            'anime-titles.xml.gz' );
        die "Can't get the title dump?" unless defined $content;
        gunzip 'anime-titles.xml.gz' => $title_dump
          or die "Decompression failed: $GunzipError\n";
    }

    my $data = XML::LibXML->load_xml( location => $title_dump );

    # list
    my @id_list;
    foreach my $title ( $data->findnodes('//animetitles/anime') ) {
        push @id_list, $title->getAttribute('aid');
    }
    @id_list = shuffle(@id_list);

    # bcs ascii art
    my $max      = scalar(@id_list);
    my $progress = Term::ProgressBar->new(
        { name => 'Inserting new stuff', count => $max, ETA => 'linear' } );

    # banned list
    my @banned_list;

    foreach my $anidb_id (@id_list) {
        unless ( animeExists($anidb_id) ) {

            # fetch it
            my %data = getAnime($anidb_id);

            if ( defined( $data{error} ) && $data{error} == 500 ) {
                push @banned_list, $anidb_id;
                next;
            }

            # animu doesn't even exist
            if ( defined( $data{error} ) && $data{error} == 404 ) {
                next;
            }

            # again.. implies multiple script executions
            try {
                my $oof = XML::LibXML->load_xml( string => $data{content} );

                # Parse
                my %anime    = parseAnime($oof);
                my $picture  = parsePicture($oof);
                my @titles   = parseTitles($oof);
                my @episodes = parseEpisodes($oof);

                # Insert
                my $local_id = insertAnime(%anime);
                insertPicture( $local_id, $picture );
                insertEpisodes( $local_id, @episodes );
                insertTitles( $local_id, @titles );
                mapAnime( $local_id, $anidb_id );

                $progress->update(1);
            }
            catch {
                say "Couldn't parse the XML string, skipping.";
                $progress->update(1);

                next;
            };
        }
        sleep(2);
    }
    $progress->update($max);

    # banned progress bar
    $max      = scalar(@banned_list);
    $progress = Term::ProgressBar->new(
        { name => 'Banned list', count => $max, ETA => 'linear' } );

    # one more try..
    foreach my $anidb_id (@banned_list) {
        unless ( animeExists($anidb_id) ) {

            # fetch it
            my %data = getAnime($anidb_id);

            # fuck it
            if ( defined( $data{error} ) && $data{error} == 500 ) {
                next;
            }

            # load
            # again.. implies multiple script executions
            try {
                my $oof = XML::LibXML->load_xml( string => $data{content} );

                # parse
                my %anime    = parseAnime($oof);
                my $picture  = parsePicture($oof);
                my @titles   = parseTitles($oof);
                my @episodes = parseEpisodes($oof);

                # insert
                my $local_id = insertAnime(%anime);
                insertPicture( $local_id, $picture );
                insertEpisodes( $local_id, @episodes );
                insertTitles( $local_id, @titles );
                mapAnime( $local_id, $anidb_id );
                $progress->update(1);
            }
            catch {
                say "Couldn't load the XML string, skipping.";
                $progress->update(1);

                next;
            };
        }

        sleep(2);
    }
    $progress->update($max);
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
  --sync    Synchronize with MAL

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
