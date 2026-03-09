---
title: NGINX Basics and Reverse Proxy
date: 2023-11-25 00:00:00
categories: NetWork
description: Basic usage of NGINX including installation, configuration, and reverse proxy behavior
tags:
- NGINX
- DevOps
---

## Installing NGINX

NGINX can be installed easily using **Homebrew** on macOS.  
Other platforms such as Linux also provide straightforward installation methods.

Example:

```bash
brew install nginx
```

After installation, we usually need to edit the **NGINX configuration file**.

A convenient way to edit configuration files is using **VSCode**.

First install the `code` command in VSCode.

In VSCode press:

```
Cmd + Shift + P
```

Then run:

```
Shell Command: Install 'code' command in PATH
```

After that you can open files directly from the terminal.

---

## Finding the NGINX Configuration File

We can use the following command:

```bash
nginx -t
```

Example output:

```
nginx: the configuration file /opt/homebrew/etc/nginx/nginx.conf syntax is ok
nginx: configuration file /opt/homebrew/etc/nginx/nginx.conf test is successful
```

This tells us the path of the configuration file.

Then we can open it with:

```bash
code /opt/homebrew/etc/nginx/nginx.conf
```

---

## Controlling NGINX

NGINX can be controlled using signals.

```
nginx -s <signal>
```

Available signals include:

| Signal | Description |
|------|------|
| quit | graceful shutdown |
| stop | fast shutdown |
| reload | reload configuration |
| reopen | reopen log files |

Example:

```bash
nginx -s reload
```

This command reloads the configuration without stopping the server.

---

## Main Functions of NGINX

NGINX is widely used for several purposes:

- Web Server
- Reverse Proxy
- Load Balancer
- Content Cache
- Security Gateway

In many real systems, NGINX is primarily used as a **reverse proxy**.

---

## Reverse Proxy

When NGINX works as a reverse proxy, it forwards client requests to another server.

The process is:

1. client sends request to NGINX
2. NGINX forwards request to backend server
3. backend server responds
4. NGINX returns response to client

Example configuration:

```nginx
location /some/path/ {
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_pass http://www.example.com/link/;
}
```

In this example:

```
/some/path/page.html
```

will be proxied to

```
http://www.example.com/link/page.html
```

---

## Trailing Slash Behavior

Trailing slashes in `location` and `proxy_pass` are very important.

Consider the following configurations.

### Case 1

```nginx
location /aa {
    proxy_set_header X-Forwarded-For $remote_addr;
    proxy_set_header Host $http_host;
    proxy_pass http://localhost:5172;
}
```

### Case 2

```nginx
location /aa/ {
    proxy_set_header X-Forwarded-For $remote_addr;
    proxy_set_header Host $http_host;
    proxy_pass http://localhost:5172;
}
```

### Case 3

```nginx
location /aa {
    proxy_set_header X-Forwarded-For $remote_addr;
    proxy_set_header Host $http_host;
    proxy_pass http://localhost:5172/;
}
```

Now consider the request:

```
http://localhost:8080/aa/configuration/getConfiguration
```

Will it be forwarded to:

```
http://localhost:5172/configuration/getConfiguration
```

The answer depends on the **trailing slash rules**.

### Behavior Explanation

If `proxy_pass` **does not include a trailing slash**, NGINX will append the entire request URI.

This means `/aa` may remain in the forwarded path.

If both `location` and `proxy_pass` **include trailing slashes**, NGINX will replace the matching part of the path.

---

## Recommended Configuration

To ensure consistent behavior, it is recommended to include trailing slashes in both directives:

```nginx
location /aa/ {
    proxy_set_header X-Forwarded-For $remote_addr;
    proxy_set_header Host $http_host;
    proxy_pass http://localhost:5172/;
}
```

With this configuration:

```
/aa/configuration/getConfiguration
```

will correctly map to

```
http://localhost:5172/configuration/getConfiguration
```

---

## Summary

NGINX is a powerful and lightweight server widely used in modern web architectures.

Key uses include:

- serving static content
- reverse proxying backend services
- load balancing traffic
- caching responses
- improving security

Understanding reverse proxy behavior — especially **URI rewriting and trailing slash rules** — is important for correctly configuring NGINX in real-world systems.

In future work, more advanced topics can be explored, such as:

- load balancing strategies
- caching configuration
- rate limiting
- HTTPS and TLS termination