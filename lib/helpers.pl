use utf8;
use Regexp::Common qw(URI);
use DateTime;

# Check whether it's a legit date
sub parseDate {
    my ($date) = @_;
    return ( $date =~ tr/-// == 2 ) ? $date : undef;
}

# Get the anime state
sub getState {
    my ( $start_date, $end_date ) = @_;
    my $now = DateTime->now->ymd;

    if ( defined $start_date && $start_date lt $now ) {
        return ( $end_date && $end_date lt $now ) ? 0 : 1;
    }

    # some weird cases ..
    # when $start_date is null
    if ( defined $end_date && $end_date lt $now ) {
        return 0;
    }

    return 2;
}

sub cleanSynopsis {
    my ($synopsis) = @_;

    my @bad_words;

    while ( $synopsis =~ /\[(.*?)\]/g ) {
        my $match = $1;

        unless ( $synopsis =~ /\Q\/$match/ || $match =~ '/' ) {
            push( @bad_words, $match );
        }
    }

    $synopsis =~ s{$RE{URI}{-keep}}{[url=$1]}g;

    foreach my $badword (@bad_words) {
        my $newString = $badword . '[/url]';
        $synopsis =~ s{\s+\[$badword\]}{$newString}g;
    }

    return $synopsis;
}

1;
