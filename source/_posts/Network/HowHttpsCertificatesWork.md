---
title: How HTTPS Certificates Work (with Certbot)
date: 2026-03-26 00:00:00
categories: NetWork
description: Basic usage of Certbot and how it work with Let's Encrypt
tags:
- Certbot
---

When using tools like Certbot to enable HTTPS, the process is mostly automated, but the underlying idea is quite simple: proving domain ownership and obtaining a trusted certificate.

First, Certbot generates a key pair (a private key and a public key) and sends a certificate request to a Certificate Authority (CA), such as Let’s Encrypt.

Before issuing the certificate, the CA needs to verify that you actually control the domain. This is done through a challenge process (for example, an HTTP challenge). Certbot automatically handles this by temporarily configuring the web server (e.g., Nginx) so that a specific URL under your domain returns a validation token. The CA then sends a request to that URL. If the expected response is returned, it confirms that you control the domain.

Once the domain is verified, the CA issues a certificate by signing your public key and domain information using its private key. Certbot stores this certificate on your server.

The certificate itself contains the domain name and a public key, and is signed by the CA using its private key. This signature allows browsers to verify that the certificate is trusted. In public key cryptography, the private key is used to create a signature, while the corresponding public key is used to verify it. This is different from encryption, where the public key encrypts data and the private key decrypts it.

When a browser connects to your site over HTTPS, your server sends the certificate. The browser then verifies it using trusted CA certificates already built into the system. If the verification succeeds, a secure connection is established.

In short, HTTPS is not about trusting the server directly, but about trusting the Certificate Authority that verifies the domain ownership.