---
name: Root certificate
---

We're going to generate SSL certs for various services later on. These will need
to be signed by a CA. If you're feeling particularly rich or for some reason don't
want to go through the hassle of adding your own root cert to a bunch of client
machines, go ahead and buy one from a legitimate CA.

Otherwise you can generate a custom CA cert as follows:

{%highlight bash%}
openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:4096 -out cakey.pem -des3
chmod 600 cakey.pem
openssl req -x509 -new -nodes -key cakey.key -days 3650 -out cacert.pem
cp cacert.pem /etc/ssl/certs/
cp cakey.pem /etc/ssl/private/
{%endhighlight%}

**Keep your CA key safe and encrypt it with a strong passphrase**

On every client machine (i.e. one from which you will later want to read or write
emails) you will need to add `cacert.pem` to the list of trusted certificates.

On Linux, and most other flavors of UNIX, this is as simple as copying that file
to `/etc/ssl/certs`. Make sure to give it a name that won't clash with existing
certs (your own name is probably a safe choice).

Save the following script as `gencert.sh` alongside your CA cert. It will be
used later on to sign new certificates.

{%highlight bash%}
#!/bin/sh

key=$1
cert=$2
csr=temp.csr
cakey=cakey.pem
cacert=cacert.pem

touch $key
chmod 600 $key
openssl genrsa 2048 > $key
openssl req -new -key $key -out $csr
openssl x509 -req -in $csr -CA $cacert -CAkey $cakey -CAcreateserial \
    -out $cert -days 3650
rm $csr
{%endhighlight%}

Dont't forget to make it executable:

{%highlight bash%}
chmod +x gencert.sh
{%endhighlight%}

**NOTE:** All the certs generated by the above command are valid for 10 years.
You might want to increase or decrease that value depending on what security vs
convenience trade-off you're willing to make.
