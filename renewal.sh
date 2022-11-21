#!/bin/bash
#Author: Damian Golał

#Obsługa flagi -d
while getopts d: flag
do
    case "${flag}" in
        d) domain=${OPTARG};;
    esac
done

#Weryfikacja czy ważność certyfikatu dla domeny jest minimum 5 dniowa
certbot certificates -d $domain |grep -E 'VALID: 1 days|VALID: 2 days|VALID: 3 days|VALID: 4 days|VALID: 5 days'

#Jeśli powyższe polecenie ma exit_code=0 to wykonaj odnowienie, jeśli nie to zamknij skrypt
if [ $? -eq 0 ]
then
#Zatrzymanie usługi
  systemctl stop haproxy.service
# Generowanie certyfikatu
  certbot certonly --standalone -d $domain --non-interactive --agree-tos --email alarmy@dataspace.pl
#Wznowienie działania haproxy
  systemctl start haproxy.service
#Przerabianie certyfikatu i klucza
  cat /etc/letsencrypt/live/$domain/fullchain.pem /etc/letsencrypt/live/$domain/privkey.pem | tee /etc/haproxy/ssl/certificates/"$domain"2.pem
#Przenoszenie certyfikatu
  mv /etc/haproxy/ssl/certificates/"$domain".pem /etc/haproxy/ssl/certificates/"$domain"3.pem
#Zmiana nazwy właściwego certyfikatu
  mv /etc/haproxy/ssl/certificates/"$domain".pem /etc/haproxy/ssl/certificates/"$domain".pem
#Restart haproxy
  systemctl restart haproxy.service
#Usuwanie starego certyfikatu
  rm -rf /etc/haproxy/ssl/certificates/"$domain"3.pem

#Logowanie zdarzenia - sukces
  echo "[$(date)] SSL Certificate for ${domain} properly renewed." >> /var/log/renewal_script
  exit 0
else
  echo "Certificate not yet due for renewal; no action taken."
  
#Logowanie zdarzenia - pominięcie  
  echo "[$(date)] Certificate for ${domain} not yet due for renewal." >> /var/log/renewal_script
  exit 1
fi
