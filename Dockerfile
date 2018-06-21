FROM perl:latest

RUN curl -L http://cpanmin.us | perl - App::cpanminus
RUN cpanm --notest --force DBI DateTime JSON Pod::Usage XML::LibXML IO::Uncompress::Gunzip Regexp::Common Term::ProgressBar Try::Tiny LWP::Simple LWP DBD::Pg
