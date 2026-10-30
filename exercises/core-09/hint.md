Use the `docker run` command with the `-v` flag for bind mounts. The format is `-v <host-path>:<container-path>`.

- To get the absolute path of the current directory, you can use `$(pwd)`.
- To make a mount read-only, add `:ro` at the end.

Here is the full command structure:
```bash
docker run -d \
  --name c9-dev-server \
  -p 8009:80 \
  -v "$(pwd)/app":/usr/share/nginx/html:ro \
  nginx
```

**Windows (Git Bash) users:** Git Bash rewrites POSIX-style paths in command arguments, which breaks the `-v` value above. Use the Windows-style path from `pwd -W` instead:
```bash
docker run -d \
  --name c9-dev-server \
  -p 8009:80 \
  -v "$(pwd -W)/app:/usr/share/nginx/html:ro" \
  nginx
```
