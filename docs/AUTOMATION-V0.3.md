# Deploy v0.3 — restricted SSH gate + GitHub environment approval

**Status: proposed implementation, NOT installed on VPS.** Do not run before security review and staging test.

## Flow
1. Author changes in a PR; Architecture CI validates.
2. Merge to protected `main`.
3. Trigger `Architecture - approved deployment` via Actions `workflow_dispatch` on `main`.
4. Job `validate` must pass. Job `deploy` waits for approval from environment `architecture-production` (configure required reviewers and prevent self-review).
5. On approval, GitHub-hosted runner uses a dedicated SSH key whose public counterpart is forced-command restricted on the VPS.
6. Local forced-command gate permits only `deploy <exact SHA>`; only the root-owned deployer can write to the site. It compares the SHA to the latest `origin/main`, takes a backup, runs content checks, deploys, checks HTTPS, and rolls back on error.

## Required administrator setup (not performed automatically)
- Configure branch protection/ruleset for `main`: PRs, required CI, restricted workflow edits and review.
- In GitHub Settings > Environments, create `architecture-production`, restrict to `main`, require authorized reviewers, and **disallow self-review**.
- Generate a **new dedicated** ED25519 keypair for the deployment gate. Do not reuse VPS login or GitHub deploy keys. Save private key as Environment secret `ARCHITECTURE_DEPLOY_KEY`; public key is installed only on the dedicated VPS account.
- Set Environment variable `ARCHITECTURE_DEPLOY_HOST` to approved server DNS/IP and Environment secret `ARCHITECTURE_DEPLOY_KNOWN_HOSTS` to the **independently verified pinned** SSH host key. Never populate it using blind `ssh-keyscan` from the runner.
- Create Linux account `iatb-arch-deploy`, no sudo privileges except the single exact root-owned executable via carefully scoped sudoers; install both audited scripts as root-owned outside the repository, immutable to the deploy account. Configure the deploy key in its authorized_keys with `command="/usr/local/sbin/iatb-arch-ssh-gate",restrict`.
- Ensure `iatbadmin` retains its existing read/write scoped GitHub deploy key; root wrapper invokes Git only via `runuser`.
- Audit existing target Caddy root, site ownership, backups, firewall and service isolation.
- Test rejection of malformed commands and non-main SHAs, successful staging deploy and rollback on health failure before enabling the production workflow.

## Important limitations
- This is **not a general SSH console**; GitHub runner gets only the forced command for an exact SHA.
- GitHub Actions workflow definitions are code; use branch protection and environment approval to limit untrusted changes. A protected environment approval is a required step, not something ChatGPT can silently bypass.
- Initial root script uses in-place rsync. Further hardening: release directories and atomic activation, stronger validation for all static assets, health-check content markers, and negative security tests.
- No change was made to MCP DEBUG, MCP Architecture, Caddy, or live site as part of this source-code commit.
- Make a dry run on a disposable staging host before allowing production SSH key, sudoers or automatic deployment.
