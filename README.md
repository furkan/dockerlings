# Dockerlings
**Learn Docker by doing – the fun, interactive way**

[discord](https://discord.gg/4hUbVHG7we)

---

[![asciicast](https://asciinema.org/a/758902.svg)](https://asciinema.org/a/758902)

---

- **100% interactive TUI** – Beautiful terminal interface powered by Bubble Tea  
- **Instant verification** – Run `check` and know immediately if you're right  
- **Progressive curriculum** – 15+ carefully crafted exercises that build on each other  
- **Real-world skills** – From basic images to multi-stage builds, volumes, networks, and Compose  
- **Zero friction** – Just clone, build, and start learning

---

## What you'll master

| Exercise     | You’ll learn                                                                 |
|--------------|-------------------------------------------------------------------------------|
| core-01–04   | Running containers, logs, exec, file operations                              |
| core-05–07   | Writing Dockerfiles, COPY, EXPOSE, ENV, LABEL                                |
| core-08–09   | Persistent volumes & live-reloading bind mounts                              |
| core-10–11   | Container networking and port publishing                                     |
| core-12–14   | Docker Compose, multi-service apps, named volumes, custom networks          |
| core-15      | Multi-stage builds for tiny, secure production images                        |

## Get started in 30 seconds

> You need `go` and `docker` installed.

```bash
git clone https://github.com/furkan/dockerlings.git
cd dockerlings
go build -o bin/dockerlings ./cmd/dockerlings
./bin/dockerlings watch
```

Use ↑↓ to navigate • c to check your solution • h for hints • q to quit

## Test a solution manually (optional)

```bash
cd exercises/core-01
bash check.sh   # see detailed feedback
```

## Made for

- Beginners who want to understand Docker commands
- Intermediate devs preparing for real-world container workflows
- Anyone who learns best by breaking and fixing things
