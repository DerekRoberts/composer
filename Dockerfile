# Dockerfile for the PDC's Composer service
#
#
# Composer for aggregate data queries. Links to ComposerDb.
#
# Example:
# sudo docker pull mongo:3.2.9
# sudo docker pull hdcbc/composer
# sudo docker run -d --name composerDb -h composerDb --restart=always \
#   -v /path/for/composerDb/:/data/:rw \
#   mongo:3.2.9
# sudo docker run -d --name=composer -h composer --restart=always \
#   --link composerdb:database \
#   -p 2774:22 \
#   -p 3002:3002 \
#   -v </path/>/composer:/config:rw \
#   hdcbc/composer
#
# Linked containers
# - Mongo database:  --link composerdb:database
#
# External ports
# - AutoSSH:         -p <hostPort>:22
# - Web UI:          -p <hostPort>:3002
#
# Folder paths
# - config:          -v </path/>:/config/:rw
#
#
FROM phusion/passenger-ruby19
MAINTAINER derek.roberts@gmail.com


################################################################################
# System
################################################################################


# Environment variables, users and packages
#
ENV TERM xterm
ENV DEBIAN_FRONTEND noninteractive
RUN adduser --disabled-password --gecos '' autossh
RUN sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv EA312927; \
    echo "deb http://repo.mongodb.org/apt/ubuntu trusty/mongodb-org/3.2 multiverse" \
      | sudo tee /etc/apt/sources.list.d/mongodb-org-3.2.list; \
    apt-get update; \
    apt-get install -y \
      mongodb-org-shell=3.2.9 \
      mongodb-org-tools=3.2.9; \
    apt-get autoclean; \
    apt-get clean; \
    rm -rf \
      /var/tmp/* \
      /var/lib/apt/lists/* \
      /tmp/* \
      /usr/share/doc/ \
      /usr/share/doc-base/ \
      /usr/share/man/


# SSH config
#
RUN rm -f /etc/service/sshd/down; \
  sed -i \
    -e 's/#HostKey \/etc/HostKey \/config/' \
    -e 's/^#AuthorizedKeysFile.*/AuthorizedKeysFile\t\/config\/authorized_keys/' \
    /etc/ssh/sshd_config; \
  ( \
      echo ''; \
      echo '# Keep connections alive, 60 second interval'; \
      echo '# '; \
      echo 'Host *'; \
      echo 'ServerAliveInterval 60'; \
  ) | tee -a /etc/ssh/ssh_config


################################################################################
# Application
################################################################################


# Prepare /app/ folder
#
WORKDIR /app/
COPY . .
RUN sed -i -e 's/localhost:27017/database:27017/' config/mongoid.yml; \
    chown -R app:app /app/; \
    /sbin/setuser app bundle install --path vendor/bundle


################################################################################
# Runit Service Scripts
################################################################################


# Create startup script and make it executable
#
RUN SRV=rails; \
    mkdir -p /etc/service/${SRV}/; \
    ( \
      echo '#!/bin/bash'; \
      echo ''; \
      echo ''; \
      echo '# Start service'; \
      echo '#'; \
      echo 'cd /app/'; \
      echo 'exec /sbin/setuser app bundle exec rails server -p 3002'; \
    )  \
      >> /etc/service/${SRV}/run; \
    chmod +x /etc/service/${SRV}/run


# Support script for delayed_job and ssh-keygen
#
RUN SRV=support; \
    mkdir -p /etc/service/${SRV}/; \
    ( \
      echo '#!/bin/bash'; \
      echo ''; \
      echo ''; \
      echo '# Create job_params.json if not present'; \
      echo 'if [ ! -s /config/job_params.json ]'; \
      echo 'then'; \
      echo '  ('; \
      echo '    echo -e '"'"'{'"'"; \
      echo '    echo -e '"'"'\t"username": "maintenance",'"'"; \
      echo '    echo -e '"'"'\t"endpoint_names": [ "00" ],'"'"; \
      echo '    echo -e '"'"'\t"query_titles": [ "HDC-0001" ]'"'"; \
      echo '    echo -e '"'"'}'"'"; \
      echo '  ) \'; \
      echo '    > /config/job_params.json'; \
      echo 'fi'; \
      echo ''; \
      echo ''; \
      echo '# Create authorized_keys if not present'; \
      echo 'touch /config/authorized_keys'; \
      echo ''; \
      echo ''; \
      echo '# Create ssh keys if not present'; \
      echo 'if [ ! -s /config/ssh_host_rsa_key ]'; \
      echo 'then'; \
      echo '  ssh-keygen -b 4096 -t rsa -f /config/ssh_host_rsa_key -q -N ""'; \
      echo 'fi'; \
      echo ''; \
      echo ''; \
      echo '# Start delayed job'; \
      echo '#'; \
      echo 'cd /app/'; \
      echo 'rm /app/tmp/pids/server.pid > /dev/null'; \
      echo 'exec /sbin/setuser app bundle exec /app/script/delayed_job run'; \
      echo '/sbin/setuser app bundle exec /app/script/delayed_job stop > /dev/null'; \
    )  \
      >> /etc/service/${SRV}/run; \
    chmod +x /etc/service/${SRV}/run


################################################################################
# Cron and Scripts
################################################################################


# Batch query scheduling in cron
#
RUN ( \
      echo '# Run batch queries (23 PST = 7 UTC)'; \
      echo '0 7 * * * /app/util/run_batch_queries.sh'; \
    ) \
      | crontab -


# Create Mongo maintenance script and add to cron
#
RUN SCRIPT=/mongoMaintenance.sh; \
  ( \
    echo '#!/bin/bash'; \
    echo '#'; \
    echo 'set -e -o nounset'; \
    echo ''; \
    echo ''; \
    echo '# Mongo eval command with server, database and port'; \
    echo '#'; \
    echo 'EVAL="/usr/bin/mongo database:27017/query_composer_development --eval"'; \
    echo ''; \
    echo ''; \
    echo '# Set indexes to prevent duplicates'; \
    echo '#'; \
    echo '${EVAL} "db.endpoints.ensureIndex({ base_url : 1 }, { unique: true });"'; \
    echo '${EVAL} "db.queries.ensureIndex({ title : 1 }, { unique: true });"'; \
    echo '${EVAL} "db.users.ensureIndex({ username : 1 }, { unique: true });"'; \
    echo ''; \
    echo ''; \
    echo '# Maintenance account'; \
    echo '#'; \
    echo '${EVAL} '"'"'db.users.insert({ '; \
    echo '  "first_name" : "HDC", "last_name" : "Maintenance", "username" : '; \
    echo '  "maintenance", "email" : "admin@hdcbc.ca", "encrypted_password" : '; \
    echo '  "\$2a\$10\$mWm0Lp5dcbtX1IzH2C0ayOefiAxO7ZlNCPJqFT10ZlZBQeK31PnbW", '; \
    echo '  "agree_license" : true, "approved" : true, admin : "false" '; \
    echo '});'"'"; \
    echo ''; \
    echo '# Dump DB'; \
    echo '#'; \
    echo 'mongodump --host database --db query_composer_development --out /dump/'; \
  )  \
    >> ${SCRIPT}; \
  chmod +x ${SCRIPT}; \
  ( \
    echo '# Run database dump script (boot, 2 PST = 10 UTC)'; \
    echo '@reboot '${SCRIPT}; \
    echo '0 10 * * * '${SCRIPT}; \
  ) \
    | crontab -


################################################################################
# Volumes, ports and start command
################################################################################


# Run Command
#
CMD ["/sbin/my_init"]


# Ports and volumes
#
EXPOSE 2774 3002
VOLUME /config
