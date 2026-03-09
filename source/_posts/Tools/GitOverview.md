---
title: Git Overview
date: 2023-08-10 00:00:00
categories: Tools
description: A concise overview of Git, including snapshots, the three states, basic workflow, branching, remotes, and rebase
tags:
- Git
---

## What Is Git

Git is a distributed version control system.

Before Git, version control systems were usually divided into three types:

- local version control systems
- centralized version control systems
- distributed version control systems

A local version control system stores versions only on one machine. A centralized version control system depends on a central server, which creates a single point of failure. A distributed version control system, such as Git, allows every developer to have a full local copy of the repository and work with one or more remotes.

---

## Key Features of Git

### 1. Snapshots, Not Differences

Traditional systems often store data as differences between files over time.

Git thinks differently. It stores data more like a series of snapshots. Each commit records what the project looks like at that moment.

### 2. Nearly Every Operation Is Local

Most Git operations only need local files and local history. This makes Git fast and convenient, because many operations do not depend on a network connection.

### 3. Git Has Integrity

Everything in Git is checksummed before it is stored, and then referred to by that checksum. This helps Git detect data corruption and maintain consistency.

### 4. Git Generally Only Adds Data

Most operations in Git add new data rather than modifying old history directly. This makes experimentation much safer.

---

## The Three States in Git

A file in Git usually exists in one of three states:

- **Modified**: the file has been changed, but not committed yet
- **Staged**: the file has been marked to be included in the next commit
- **Committed**: the file is safely stored in the local Git database

These three states correspond to three important areas:

- working directory
- staging area
- Git repository

---

## Basic Git Workflow

A typical Git workflow looks like this:

1. modify files in the working directory
2. stage selected changes
3. commit the staged snapshot to the repository

Some common commands are:

```bash
git status
git add .
git commit -m "Initial project version"
```

---

## First-Time Setup

Before using Git, it is common to configure your identity and some default settings.

```bash
git config --global user.name "Your Name"
git config --global user.email "you@example.com"
git config --global init.defaultBranch main
```

To check your current settings:

```bash
git config --list
```

To check a specific key:

```bash
git config user.name
```

---

## Creating a Repository

There are two common ways to get a Git repository.

### Initialize a Repository in an Existing Directory

```bash
git init
git add .
git commit -m "Initial project version"
```

### Clone an Existing Repository

```bash
git clone https://example.com/project.git
```

---

## Checking Changes

To check the current status of your files:

```bash
git status
git status -s
```

To see unstaged changes:

```bash
git diff
```

To see staged changes:

```bash
git diff --staged
```

---

## Ignoring Files

Git can ignore files that should not be tracked, such as build output, logs, or dependencies. These rules are written in `.gitignore`.

Example:

```gitignore
node_modules/
dist/
*.log
.env
```

This is especially useful in real projects, because many generated files should never be committed.

---

## Committing Changes

Once changes are staged, they can be committed.

```bash
git commit -m "Add login page"
```

You can also skip the staging step for already tracked files:

```bash
git commit -a -m "Fix bug in login flow"
```

This is convenient, but it should be used carefully, because it may include changes you did not intend to commit.

---

## Viewing Commit History

The most basic history command is:

```bash
git log
```

Useful variations include:

```bash
git log -p -2
git log --stat
git log --pretty=oneline
git log --graph
```

These options help show recent commits, code differences, file statistics, and branch structure.

---

## Undoing Changes

Git provides several ways to undo mistakes.

### Amend the Last Commit

```bash
git commit --amend
```

This is useful when you forgot to include something in the previous commit or want to edit the commit message.

### Unstage a File

```bash
git restore --staged <filename>
```

### Discard Local Changes

```bash
git restore <filename>
```

This is a dangerous command because local changes will be lost.

---

## Working with Remotes

To see your remotes:

```bash
git remote -v
```

To fetch from a remote:

```bash
git fetch origin
```

To pull changes:

```bash
git pull
```

To push changes:

```bash
git push origin main
```

The difference between `fetch` and `pull` is important:

- `git fetch` only downloads remote data
- `git pull` downloads and merges it into the current branch

---

## Branches

Branches are one of Git’s most powerful features.

To create a branch:

```bash
git branch feature-login
```

To switch branches:

```bash
git switch feature-login
```

Or create and switch in one step:

```bash
git switch -c feature-login
```

Git keeps a special pointer called `HEAD`, which points to the branch you are currently on.

---

## Merging

A common workflow is to create a feature branch, do some work there, and then merge it back.

```bash
git switch main
git merge feature-login
```

If the target branch has not moved forward independently, Git may perform a **fast-forward** merge. Otherwise, it creates a **merge commit**.

If both branches modify the same part of a file, a merge conflict may happen. In that case, Git will ask you to resolve the conflict manually.

---

## Rebase

Rebase is another way to integrate changes.

```bash
git switch feature
git rebase main
```

Rebase rewrites the branch history so that your commits appear as if they were based directly on the latest `main`.

This often creates a cleaner history than merge, but it must be used carefully.

A very important rule is:

**Do not rebase commits that have already been shared and that other people may have based work on.**

In practice:

- rebase local, unpublished work to keep history clean
- use merge for shared history when rewriting would be risky

---

## Stash

Sometimes you need to temporarily save unfinished work without committing it.

```bash
git stash
```

To see saved stashes:

```bash
git stash list
```

To reapply the latest stash:

```bash
git stash apply
```

To apply and remove it at the same time:

```bash
git stash pop
```

This is useful when you need to quickly switch tasks.

---

## Final Notes

Git is powerful, but the core idea is actually simple:

- your files start in the working directory
- selected changes move into the staging area
- commits store snapshots in the repository
- branches help you work in parallel
- remotes help you collaborate
- rebase and merge are two different ways to integrate history

For daily work, understanding these few concepts is more important than memorizing every command.

---

## References

- https://git-scm.com/book/en/v2