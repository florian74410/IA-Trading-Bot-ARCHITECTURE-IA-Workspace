# IA-TB Architecture — validated deployment v0.2

## Current safety model
- GitHub-hosted CI checks code; it never connects to the VPS or uses production credentials.
- Production deployment is **manual approval of an exact 40-character SHA** on the VPS.
- Deployment runs from an immutable `git archive`, not working-tree edits.
- Root permissions are used only for writing the existing root-owned public site and backups; Git fetch runs as `iatbadmin`.
- Atomic concurrent-deploy lock, predeploy backup, dry run and postdeploy HTTPS smoke check.
- A failed smoke check attempts to restore the backup. If host/network is down, a healthy site can still be rolled back; inspect before retrying.

## Initial workflow
1. Open a PR with changes to `site/` and wait for `Architecture - CI` to pass.
2. Review and merge into `main`.
3. On VPS (logged in as `iatbadmin`), fetch: `git -C ~/iatb-architecture-workspace fetch origin main`.
4. Copy the reviewed **full commit SHA** from GitHub and compare to `git -C ~/iatb-architecture-workspace rev-parse origin/main`.
5. Check that the CI for that commit is green and **manually** invoke:
   `sudo bash ~/iatb-architecture-workspace/scripts/deploy-approved.sh <FULL_SHA>`
6. Read the dry-run, then type `DEPLOY` to approve.
7. Verify HTTPS and service health. Caddy and MCP systemd services are not restarted.

## Restore
The deploy prints an absolute backup path. Use:
`sudo bash ~/iatb-architecture-workspace/scripts/rollback-site.sh /srv/iatb-architecture/backups/site-<timestamp>-before-<sha>.tar.gz`
Then type `ROLLBACK`.

## Limitations
- There is deliberately **no unattended production deployment** yet. CI test success is not cryptographically attested to the VPS; human verifies it before the deployment. This avoids deploying attacker-controlled changes from GitHub on a production host.
- The site is static, with in-place rsync; short transient states remain possible during copying. Later release directories + an atomic Caddy root switch can address that.
- Confirm the actual CI workflow is recognized by GitHub, install `rsync` if missing, and run a disposable staging test before the first production use.
- The separate local MCP at 127.0.0.1:8810 remains private and must not be exposed without tested authentication.
