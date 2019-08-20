FROM ubuntu:xenial

ENV MYHOSTNAME=mail.example.com \
    MYDOMAIN=example.com \
    RELAYHOST=smtp.foo.com \
    RELAYUSER=bar@foo.com \
    RELAYPASSWD=barpasswd \
    REDIRECTEMAIL=foo@bar.com \
    CONSUL_DOWNLOAD_PATH=https://releases.hashicorp.com/consul/1.5.3/consul_1.5.3_linux_amd64.zip \
    CONSUL_IP=10.10.10.10
    
RUN apt-get update && apt-get -y install postfix rsyslog jq curl unzip wget && \
    cd /usr/local/bin && wget $CONSUL_DOWNLOAD_PATH && unzip *.zip && rm *.zip && chmod +x consul

COPY ./files/* /etc/postfix/
  
CMD /etc/postfix/run.sh && tail -f /var/log/mail.log
