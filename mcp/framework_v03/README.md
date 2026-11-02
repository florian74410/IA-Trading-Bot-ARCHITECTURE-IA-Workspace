# IA-TB MCP Framework v0.3 — development candidate

This directory vendors the same framework implemented in the DEBUG workspace.
It **does not replace** the existing `mcp/server.py` or open any network port.

## Available and tested
- workspace identity check: only `debug` or `architecture`
- lexical path restriction, symlink refusal, size- and result-bounded reads
- allowlisted Git status, diff, log, branch listing (no shell interpolation)
- syntax-only Python validation; fixed `python_compile` test ID
- custom operation *request preview only*; no approval grant and no custom execution.

## Deliberately not supported yet
- no live MCP adapter routing these operations into an exposed service
- no Git push, commit, fetch, root commands, SSH or production deployment
- no remote ChatGPT connection, no admin MFA approval implementation
- no autonomous retry loop or Mission Controller
- no access to RELEASE

## Required before promotion
1. Retrieve **exact** currently running DEBUG server source under `/opt/iatb-mcp/server.py` without secrets. It is not yet represented in its repository. Capture a hash and preserve tool compatibility.
2. Validate policy against distinct real workspace mounts and Linux service identities.
3. Add safe Git write transactions and network authentication separately, with scoped keys.
4. Integrate MCP tools in a new staging service; validate compatibility, auth, isolation, audit and denial tests.
5. Configure and verify separate administrator approval channel; never let an MCP tool self-approve.
6. Prepare snapshot/rollback. Deploy only with explicit administrator consent.

## Test
From this directory run `python3 -m unittest discover -v`.
GitHub Actions runs the same tests automatically. The framework is source, not a deployed service.
