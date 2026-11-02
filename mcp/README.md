# IA-TB Architecture MCP — prototype local v0.1

**Status:** source code only. Not yet installed, started, exposed, or connected to ChatGPT.

## Scope
- Dedicated process and OS account `iatb-arch-mcp` with no sudo.
- Separate checkout at `/srv/iatb-architecture/workspace`.
- Binds only `127.0.0.1:8810`.
- Tools: list, read, write UTF-8 files **only under `workspace/site/`**.
- No shell, Git push, network APIs, secrets access or production deployment.

## Install prerequisite
The administrator must create the restricted OS user and a separate Git clone owned by that account. Do not grant access to the DEBUG workspace, `/etc/caddy`, `/opt/iatb-mcp` or the live site directory. Install dependencies in a dedicated Python venv.

## Security
**Do not reverse-proxy this prototype to the Internet.** Binding on loopback is not authentication. Before connecting ChatGPT, implement and verify an authenticated MCP gateway (ideally OAuth with authorization for each tool) and ensure access control, audit logs, rate limits, and tested origin/header protections. A generic HTTP bearer token in a public URL is not an adequate substitute for the full integration design.

## Tests before deployment
- Access via localhost succeeds.
- Attempts to read `../../etc/passwd`, absolute paths and symlinks are rejected.
- The MCP OS user cannot read or write the production site.
- Other services and listeners are unchanged.
- Deployments remain explicit and separately approved.

This MCP uses mcp 2.3.0 and uvicorn 0.54.0 as observed on the preexisting DEBUG host; compatibility still needs to be tested independently.
