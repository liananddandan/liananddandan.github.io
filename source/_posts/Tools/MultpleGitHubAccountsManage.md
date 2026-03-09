---
title: Managing Multiple GitHub Accounts on One Computer
date: 2024-05-22 00:00:00
categories: Technology
description: How to manage multiple GitHub accounts and repositories using SSH keys
tags:
- GitHub
- SSH
- Git
- DevTools
---

## Introduction

Sometimes we need to manage multiple GitHub accounts on the same computer, for example:

- personal account
- work account
- school account

A reliable solution is to use **SSH keys with host aliases**.

This guide shows how to configure multiple GitHub accounts using SSH.

---

# 1. Create One SSH Key Per GitHub Account

Each GitHub account should have its own SSH key.

Example:

```bash
ssh-keygen -t ed25519 -C "account1_email@address" -f ~/.ssh/id_ed25519_account1

ssh-keygen -t ed25519 -C "account2_email@address" -f ~/.ssh/id_ed25519_account2
```

Notes:

- `account1` and `account2` are just identifiers.
- They help you remember which key belongs to which account.

If `ed25519` is not supported in your environment:

```bash
ssh-keygen -t rsa -b 4096
```

---

# 2. Start the SSH Agent and Add Keys

Start the SSH agent:

```bash
eval "$(ssh-agent -s)"
```

### macOS

```bash
ssh-add --apple-use-keychain ~/.ssh/id_ed25519_account1
ssh-add --apple-use-keychain ~/.ssh/id_ed25519_account2
```

### Windows (Git Bash)

If `~` does not work correctly, use the absolute path.

```bash
ssh-add ~\.ssh\id_ed25519_account1
ssh-add ~\.ssh\id_ed25519_account2
```

---

# 3. Upload the Public Keys to GitHub

Each account must receive its corresponding **public key**.

Go to:

```
GitHub → Settings → SSH and GPG keys
```

Add the public key.

### macOS

```bash
pbcopy < ~/.ssh/id_ed25519_account1.pub
pbcopy < ~/.ssh/id_ed25519_account2.pub
```

### Windows

```bash
cat ~/.ssh/id_ed25519_account1.pub
cat ~/.ssh/id_ed25519_account2.pub
```

Copy the output and paste it into GitHub.

Important:

> One public key cannot be used by two different GitHub accounts.

---

# 4. Create SSH Host Aliases

Edit or create the SSH config file:

```
~/.ssh/config
```

Example configuration:

```
Host account1
  HostName github.com
  User git
  IdentityFile ~/.ssh/id_ed25519_account1
  IdentitiesOnly yes

Host account2
  HostName github.com
  User git
  IdentityFile ~/.ssh/id_ed25519_account2
  IdentitiesOnly yes
```

Explanation:

| Field | Meaning |
|------|------|
| Host | alias name |
| HostName | real server |
| User | git |
| IdentityFile | SSH key used |
| IdentitiesOnly | force SSH to use this key |

---

# 5. Use the Alias When Cloning Repositories

Instead of cloning with:

```
git@github.com:user/repo.git
```

Use your alias.

Example:

```bash
git clone git@account1:org/repo.git
git clone git@account2:username/repo.git
```

---

# 6. Change the Remote URL of an Existing Repository

If a repository already exists locally, update its remote.

Example:

```bash
git remote set-url origin git@account1:org/repo.git
```

Or:

```bash
git remote set-url origin git@account2:username/repo.git
```

Check the configuration:

```bash
git remote -v
```

Example:

```
git@account1:liananddandan/csmax596-group-2.git
```

This means the repository will use the SSH key associated with **account1**.

---

# Why This Works

GitHub authentication is based on **SSH keys**, not email addresses.

When you connect to GitHub:

1. Your SSH client selects a private key.
2. GitHub verifies the corresponding public key.
3. GitHub maps the key to the correct account.

Host aliases ensure that the correct key is used.

Example:

```
git@account1:org/repo.git
```

This tells SSH:

- use the `account1` configuration
- load `id_ed25519_account1`

---

# Why `IdentitiesOnly yes` Matters

Without this option, SSH may try multiple keys automatically.

This can cause problems such as:

- authentication failures
- connecting to the wrong account
- "too many authentication failures"

Setting:

```
IdentitiesOnly yes
```

forces SSH to use only the specified key.

---

# SSH Agent Behavior

The **ssh-agent** stores decrypted keys in memory so that you do not need to enter the passphrase repeatedly.

### macOS

The `--apple-use-keychain` option stores the passphrase in the system Keychain.

### Windows

The OpenSSH agent service stores keys during the session.

---

# Summary

To manage multiple GitHub accounts on one computer:

1. Create a separate SSH key for each account.
2. Add keys to the SSH agent.
3. Upload public keys to the corresponding GitHub accounts.
4. Configure SSH host aliases.
5. Use the alias when cloning or updating repositories.

This approach ensures that each repository uses the correct GitHub identity.