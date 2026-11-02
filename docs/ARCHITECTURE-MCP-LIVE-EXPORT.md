# GEN-1 Architecture: direct VPS export through MCP v0.3

## Goal
ChatGPT calls `architecture_export_live_site` on an authenticated MCP server.
The tool reads the **published** filesystem at `/srv/iatb-architecture/site`
on the VPS and returns a bounded ZIP, encoded as base64 plus SHA-256.
This is **not** a GitHub source export, nor a backup of the whole machine.

## Source and tests
- `mcp/framework_v03/live_export.py`: no shell, no write, regular files only,
  no symlinks, max 100 files / 4 MiB uncompressed / 3 MiB ZIP, SHA-256.
- `mcp/framework_v03/test_live_export.py`: ZIP roundtrip, symlink, missing
  index and oversized-file rejection.
- `staging_server.py`: opt-in tool registered only for `IATB_MCP_ENV=architecture`
  and `IATB_ARCH_ALLOW_LIVE_EXPORT=1`. Staging bind is `127.0.0.1:8811`.
- `smoke_http.py`: checks tool registration over actual MCP session.

## Deployment gate: still pending
1. Independent approval and review of PR #2.
2. Inspect actual VPS identity, source mounts and owner/mode of live site.
3. Deploy `staging_server.py` as non-root architecture-only service with
   read permission for the static site but no write permission there.
4. Preserve local bind; terminate TLS at an authenticated access layer.
   Require per-user auth / scoped bearer authorization / audit and rate limits.
   The endpoint must not be publicly accessible without authorization.
5. Configure ChatGPT's supported custom MCP connection in the user's workspace
   using HTTPS and authenticated credentials. Do not transmit private SSH keys
   or tokens through chat messages or commit them to Git.
6. Verify `list_tools`, export tool result, SHA-256, ZIP extraction and compare
   against a separately inspected live directory listing. Do NOT claim complete
   VPS access without a successful authenticated call.
7. For larger sites, replace base64 result with a short-lived, authorized
   download artifact service; never publish backups directly in the webroot.

## Scope
This export operation is **read-only**. It does not deploy a new site, edit
production, control DEBUG, access RELEASE, or provide an SSH shell.

## Current status
Implementation and CI smoke tests in GitHub only; not installed on VPS.
