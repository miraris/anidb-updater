FROM perl:latest

RUN apt-get update && apt-get -y install -qq --force-yes cron
RUN curl -L http://cpanmin.us | perl - App::cpanminus
RUN cpanm --notest --force DBI DateTime JSON Pod::Usage XML::LibXML IO::Uncompress::Gunzip Regexp::Common Term::ProgressBar Try::Tiny LWP::Simple LWP DBD::Pg

# Add crontab file in the cron directory
ADD crontab /etc/cron.d/updater

# Give execution rights on the cron job
RUN chmod 0644 /etc/cron.d/updater

# Create the log file to be able to run tail
RUN touch /var/log/cron.log

# Run the command on container startup
CMD cron && tail -f /var/log/cron.log
