#!/bin/sh

#Configuring Postfix with external environment variables
postconf -e "myhostname = $MYHOSTNAME" \
            "mydomain = $MYDOMAIN" \
            "mydestination = " \
            "myorigin = $MYHOSTNAME" \
            "mynetworks =" \
            "inet_protocols = ipv4" \
            "inet_interfaces = all" \
            "relayhost = $RELAYHOST" \
            "smtp_sasl_auth_enable = yes" \
            "smtp_sasl_password_maps = hash:/etc/postfix/relay_passwords" \
            "always_bcc = $REDIRECTEMAIL" \
            "smtpd_sasl_auth_enable = no" \
            "smtpd_use_tls = yes" \
            "smtpd_tls_CAfile = /etc/postfix/cacert.pem" \
            "smtpd_tls_key_file = /etc/postfix/mail_cert.private.pem" \
            "smtpd_tls_cert_file = /etc/postfix/mail_cert.public.pem" \
            "smtpd_tls_security_level = encrypt" \
            "smtpd_tls_req_ccert = yes" \
            "smtpd_tls_ccert_verifydepth = 2" \
            "smtpd_tls_auth_only = yes" \
            "smtpd_tls_loglevel = 2" \
            "smtpd_starttls_timeout = 300s" \
            "smtpd_relay_restrictions = permit_mynetworks,permit_tls_clientcerts,reject_unauth_destination" \
            "relay_clientcerts = hash:/etc/postfix/relay_clientcerts" \
            "smtpd_tls_fingerprint_digest = sha1"

#Creating auth data for relay-server
echo $RELAYHOST $RELAYUSER:$RELAYPASSWD >/etc/postfix/relay_passwords

#Join to Consul server or cluster
consul agent -data-dir /tmp/consul -client 127.0.0.1 -join $CONSUL_IP &
sleep 10

#Register Postfix as service
curl -XPUT -d @/etc/postfix/reg.json 127.0.0.1:8500/v1/agent/service/register

#Retrieving Root certificate
curl http://127.0.0.1:8500/v1/connect/ca/roots |jq --raw-output '.Roots[] .RootCert' > /etc/postfix/cacert.pem

#Retrieving Postfix's certificate and key
curl http://127.0.0.1:8500/v1/agent/connect/ca/leaf/postfix-relay | jq --raw-output '.CertPEM' > /etc/postfix/mail_cert.public.pem
curl http://127.0.0.1:8500/v1/agent/connect/ca/leaf/postfix-relay | jq --raw-output '.PrivateKeyPEM' > /etc/postfix/mail_cert.private.pem

#Retrieving all service's certifitates for auth
FILE=/etc/postfix/relay_clientcerts
rm -f "$FILE"

for s in $(consul catalog services)
do
  count=1
  for i in $(curl -s 127.0.0.1:8500/v1/catalog/service/$s |jq '.[] .ID' | tr -d \")
  do
    echo `curl http://127.0.0.1:8500/v1/agent/connect/ca/leaf/$i \
      | jq --raw-output '.CertPEM' \
      | openssl x509 -noout -pubkey \
      | openssl pkey -pubin -outform DER \
      | openssl dgst -sha1 -c \
      | sed 's/^.* //'` $s-$count >> /etc/postfix/relay_clientcerts
    count=$(($count+1))
  done
done

#Remapping...
cd /etc/postfix && postmap ./relay_clientcerts && postmap ./relay_passwords

#Starting services
service rsyslog start && service postfix start
