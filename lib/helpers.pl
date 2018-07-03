use utf8;
use Regexp::Common qw(URI);
use DateTime;
use Parse::BBCode::Markdown;

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
        return ( defined $end_date && $end_date lt $now ) ? 0 : 1;
    }

    # if the start date is unknown but the anime already ended
    elsif ( defined $end_date && $end_date lt $now ) {
        return 0;
    }

    return 2;
}

# Parse synopsis into markdown
sub cleanSynopsis {
    my ($synopsis) = @_;
    my $p = Parse::BBCode::Markdown->new();

    while ( $synopsis =~ /$RE{URI}{-keep}(\s+\[(.*?)\])/g ) {
        my $start      = "[url=$1]";
        my $to_replace = $2;
        my $end        = $3 . '[/url]';

        $synopsis =~ s/$1/$start/g; # convert the URL to a valid BBCode URL
        $synopsis =~ s/\Q$to_replace/$end/g; # strip square brackets and append the closing tag
    }

    $synopsis =~ s/`/'/g; # replace backticks ` with single quotes '
    $synopsis =~ s/(^\*.*$)/$1\n/m; # append \n if the line starts with *

    return $p->render($synopsis);
}

1;
