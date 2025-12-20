---
weight: 2
name: Domain and Host
---
Select a registar and a hosting provider, pick a domain name and a VPS configuration,
take out your credit card (or bitcoins or whatever means of payment are accepted),
confirm your order and get ready for a serious command line session.

I used [Gandi](https://gandi.net) as both my registar and my VPS provider because
it has very competitive pricing, good service and servers in the EU.

You'll need to configure the DNS records of your freshly acquired domain name to point
to your VPS. Most providers will offer some kind of fancy graphical way of editing
DNS records but I prefer editing the zone file by hand:

```text
@ 10800 IN A 46.226.109.60
* 10800 IN A 46.226.109.60
@ 10800 IN AAAA 2001:4b98:dc2:41:216:3eff:fefd:bf1
* 10800 IN AAAA 2001:4b98:dc2:41:216:3eff:fefd:bf1
@ 10800 IN MX 10 @
```

The first line points the domain name to the static IP address assigned to the VPS.
The second line points all subdomains to the same address.

The next two lines have the exact same role but for [IPv6](http://en.wikipedia.org/wiki/IPv6).
You may not need them if you choose not to configure your server to use IPv6.

Finally, the last line is an [MX record](http://en.wikipedia.org/wiki/Mx_record),
to indicate the existence of a mail server. It is commonly pointed to a subdomain
but I intentionally kept my setup simple.
