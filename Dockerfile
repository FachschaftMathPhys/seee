
FROM phusion/passenger-full
LABEL vendor="Fachschaft MathPhys"
MAINTAINER Henrik Reinstädtler <henrik@mathphys.stura.uni-heidelberg.de>
RUN bash -lc 'rvm --default use ruby-2.5.1'


RUN apt-get update && apt-get install -qq -y --no-install-recommends \
build-essential  libpq-dev wget git cron libmagick++-dev
ENV HOME /root

# Use baseimage-docker's init process.
CMD ["/bin/bash","-c","/sbin/my_init | tee /home/app/seee/log/stdout.log"]
#update nodejs
ENV INSTALL_PATH /home/app/seee/web

#Ordner erstellen und wechseln
RUN mkdir -p $INSTALL_PATH
WORKDIR $INSTALL_PATH

#Gemfile kopieren
COPY web/Gemfile web/Gemfile.lock ./
#bundles installieren
RUN gem install bundler
RUN DEBUG_RESOLVER=1 bundler install --binstubs --verbose
#und den rest kopieren
COPY . ..
RUN rm -rf /kummerkasten/tmp/pids
RUN rm -f /etc/service/nginx/down
ADD webapp.conf /etc/nginx/sites-enabled/webapp.conf
ADD postgres-env.conf /etc/nginx/main.d/postgres-env.conf
# Queue classic für mails
RUN chown -R app /home/app
RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
