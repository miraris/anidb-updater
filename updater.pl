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

use feature qw(say);

#Debug
use Data::Dumper;

# requires
require "./lib/httpclient.pl";
require "./lib/parser.pl";
require "./lib/sql.pl";

# Title dump file path
my $title_dump = './anime-titles.xml';

# difference between current timestamp and title dump mod time
my $title_dump_mod_diff =
  DateTime->now->subtract_datetime(
    DateTime->from_epoch( epoch => ( stat($title_dump) )[9] ) );

my $opt = {
    partial => undef,
    full    => undef,
};

GetOptions(
    'partial' => \$opt->{partial},
    'full'    => \$opt->{full},

    'm|man'  => sub { pod2usage( verbose => 3 ); },
    'h|help' => sub { pod2usage( verbose => 1 ); },
    'v|version' => sub { print "$APP v$VERSION\n" and exit 0; },
);

# Run
update();

sub update {
    my $anime_list = selectAnime();

    # print Dumper($anime_list);

    foreach my $item (@$anime_list) {

        # my $data = getAnime( $item->{anidb_id} );
        # load
        open my $fh, '<', 'test.xml';
        binmode
          $fh;    # drop all PerlIO layers possibly created by a use open pragma
        my $data = XML::LibXML->load_xml( IO => $fh );

        my %anime    = parseAnime($data);
        my $picture  = parsePicture($data);
        my @titles   = parseTitles($data);
        my @episodes = parseEpisodes($data);

        if ( $opt->{partial} ) {
            updateAnime( $item->{id}, %anime );
            updateTitles( $item->{id}, @titles );
            updatePicture( $item->{id}, $picture );
            updateEpisodes( $item->{id}, @episodes );
        }
    }

}

sub insert {

    # Exit if the modification time is lower than one day
    if ( ( $title_dump_mod_diff->days() ) <= 1 ) {
        die "Cannot update yet, title dump modification time is lower than 24 hours\n";
    }

    # foreach my $title ( $dom->findnodes('/animetitles/anime') ) {
    #     # print $title->getAttribute('aid');
    #     push (@list, $title->getAttribute('aid'));
    # }
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

  --full    Full update, fetches new anime and updates existing
  --partial Only updates ongoing & unknown anime

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
