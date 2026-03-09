---
title: Introduction to TLS and HTTPS
date: 2023-09-01 00:00:00
categories: Network
description: A concise introduction to TLS, HTTPS, SSL certificates and the TLS handshake
tags:
- TLS
- HTTPS
---

## What is TLS / SSL

SSL (Secure Sockets Layer) is an encryption-based Internet security protocol.  
It was originally designed to protect data transmitted between users and web servers.

Before SSL existed, most web traffic was transmitted in **plaintext**, meaning anyone who intercepted the communication could read it.

SSL solved this problem by encrypting data between the client and the server. Even if attackers intercept the traffic, they only see encrypted data.

SSL also provides **authentication**, allowing users to verify that they are communicating with the correct server instead of a fake website.

However, SSL is now obsolete. The last version, **SSL 3.0**, was released in 1996 and is considered insecure today.

Modern secure communication uses **TLS (Transport Layer Security)**, which is the successor to SSL.

---

## What is an SSL Certificate

To enable HTTPS, a website must install an **SSL/TLS certificate** on its server.

The certificate serves two purposes:

- It proves the identity of the website
- It provides the public key used for encryption

SSL certificates are issued by trusted organizations called **Certificate Authorities (CAs)**.

### Types of certificates

Different certificates support different domain scopes:

- **Single-domain certificate**  
  Protects one specific domain.

- **Wildcard certificate**  
  Protects a domain and all of its subdomains.

- **Multi-domain certificate**  
  Protects multiple unrelated domains.

### Validation levels

Certificates also have different levels of validation:

**Domain Validation (DV)**  
The CA verifies that the requester controls the domain.

**Organization Validation (OV)**  
The CA verifies the organization behind the domain.

**Extended Validation (EV)**  
The CA performs a full background verification of the organization.

---

## HTTP vs HTTPS

HTTP and HTTPS are almost the same protocol, but HTTPS adds encryption and authentication.

| Protocol | Port | Security |
|--------|------|------|
| HTTP | 80 | No encryption |
| HTTPS | 443 | Encrypted using TLS |

HTTPS works by wrapping normal HTTP communication inside a **TLS encrypted connection**.

All HTTP requests and responses are encrypted before transmission.

---

## Public Key Cryptography

TLS uses **public key cryptography**.

This system relies on two keys:

- **Public key**
- **Private key**

The public key is included in the server’s TLS certificate and shared with clients.

The private key is kept secret on the server.

When a client connects to a server, both sides use these keys to securely create a **session key**, which will encrypt the rest of the communication.

---

## What is a Session Key

A **session key** is a temporary symmetric encryption key used for a single communication session.

TLS combines two cryptographic approaches:

- **Asymmetric encryption** (public/private keys) to establish trust
- **Symmetric encryption** (session keys) for fast data transfer

Symmetric encryption is much faster, which is why it is used after the handshake completes.

---

## What is a TLS Handshake

A **TLS handshake** is the process used to establish a secure connection between a client and a server.

It occurs whenever a user accesses a website using HTTPS.

The TLS handshake happens **after a TCP connection is established**.

### TLS Handshake Process (Simplified)

1. **Client Hello**

The client sends a message containing:

- supported TLS versions
- supported cipher suites
- a random value called **client random**

---

2. **Server Hello**

The server responds with:

- its TLS certificate
- the selected cipher suite
- a random value called **server random**

---

3. **Certificate Verification**

The client verifies the server certificate using the certificate authority.

This confirms that the server is legitimate.

---

4. **Premaster Secret**

The client generates a random value called the **premaster secret**.

It encrypts this value using the server’s public key and sends it to the server.

---

5. **Server Decrypts the Secret**

The server uses its private key to decrypt the premaster secret.

---

6. **Session Key Generation**

Both client and server generate the same **session keys** using:

- client random
- server random
- premaster secret

---

7. **Handshake Completion**

Both sides send a “Finished” message encrypted with the session key.

After this point, the connection becomes fully encrypted.

---

## TLS 1.3 Improvements

TLS 1.3 introduced several improvements over earlier versions:

- Removed insecure cryptographic algorithms
- Reduced handshake latency
- Simplified negotiation process
- Improved security against downgrade attacks

TLS 1.3 also supports **0-RTT resumption**, which allows clients to reuse information from a previous session and start sending encrypted data immediately.

This reduces connection setup time significantly.

---

## Summary

HTTPS is essentially **HTTP protected by TLS encryption**.

TLS ensures:

- confidentiality (data is encrypted)
- integrity (data cannot be modified)
- authentication (server identity is verified)

In practice, TLS works through a handshake process that establishes secure **session keys**, after which all communication between the client and the server is encrypted.

---

## Reference

Cloudflare Learning Center  
https://www.cloudflare.com/learning/