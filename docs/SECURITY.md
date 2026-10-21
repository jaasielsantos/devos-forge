# DevOS Forge — Security Baseline

## Security objective

DevOS Forge will hold source code, credentials used by automation, deployment capability, and potentially privileged execution paths.

A private forge is security-sensitive infrastructure, not merely another web application.

## Primary threat areas

1. unauthorized repository access;
2. credential/token theft;
3. malicious or compromised CI workflow execution;
4. runner escape or excessive host privilege;
5. exposed database/storage services;
6. supply-chain compromise through external Actions/images/dependencies;
7. accidental destructive administration;
8. loss or corruption without recoverable backup.

## Access model

Initial posture:

- private installation;
- public registration disabled unless explicitly required later;
- least-privilege user permissions;
- separate human accounts rather than shared credentials;
- SSH keys for Git access where appropriate;
- strong authentication for web/admin access;
- administrative access limited to people who actually operate the forge.

## Network exposure

Expose only services required for normal use.

Expected public surface:

- HTTPS for web/API/Git-over-HTTPS;
- SSH endpoint for Git if enabled.

Keep PostgreSQL and internal service ports off the public internet.

Runner control traffic should use the narrowest practical network access.

## Secrets

Never commit:

- passwords;
- private SSH keys;
- API tokens;
- runner registration secrets;
- database passwords;
- deploy credentials;
- TLS private keys;
- backup encryption keys.

Use an approved secret injection/storage mechanism for runtime secrets.

Infrastructure documentation may define secret names and purpose, but not values.

## Runner trust boundary

The runner is a high-risk component because repository workflows execute code.

Principles:

- isolate jobs from the Forgejo application container/process;
- prefer containerized/ephemeral job environments;
- avoid mounting the host Docker socket into generic untrusted jobs unless the risk is explicitly accepted;
- do not provide production credentials to every workflow;
- separate generic CI from privileged deploy jobs when practical;
- restrict runner labels so privileged runners cannot be selected accidentally;
- clean workspaces and sensitive artifacts after jobs.

## Workflow security

For CI/CD workflows:

- pin or deliberately control external Actions/images where practical;
- review workflows that request privileged execution;
- scope secrets to the smallest required context;
- do not expose secrets to untrusted pull-request code;
- make deployment jobs require explicit branch/event conditions;
- retain enough logs to audit failed or suspicious automation.

## Forge administration

Administrative changes that can affect availability or data integrity should be deliberate.

Examples:

- deleting repositories;
- changing authentication policy;
- changing repository visibility;
- rotating instance secrets;
- changing runner trust/labels;
- disabling backups;
- changing storage paths;
- destructive database maintenance.

Use backups and rollback plans before high-impact maintenance.

## Host security

The VPS baseline should include:

- supported OS packages;
- regular security updates;
- firewall rules;
- SSH hardening;
- limited administrative users;
- key-based administration where practical;
- minimal unnecessary services;
- disk/capacity monitoring;
- time synchronization;
- centralized or persistent logs sufficient for troubleshooting.

Exact host-hardening choices must be compatible with the existing VPS environment and documented before production.

## Database security

PostgreSQL should:

- listen only where needed;
- use authenticated connections;
- have credentials unique to the forge;
- avoid public exposure;
- be backed up independently of container lifecycle;
- have restore tested.

## Backup security

Backups may contain the full intellectual property and operational state of the forge.

Therefore:

- protect backup credentials;
- encrypt backup data where appropriate;
- keep at least one independent copy;
- restrict access to backup storage;
- test recovery without weakening production controls;
- ensure secret recovery material is itself recoverable and protected.

## Dependency and image policy

Before production deployment:

- identify base container images;
- pin deployment versions deliberately;
- avoid `latest` as an uncontrolled production upgrade mechanism;
- document upgrade cadence;
- review critical security releases promptly.

## Security acceptance criteria for Phase 1

Before treating DevOS Forge as production-ready:

- [ ] registration/access policy configured;
- [ ] TLS valid;
- [ ] PostgreSQL not publicly exposed;
- [ ] secrets absent from repository;
- [ ] runner isolation reviewed;
- [ ] generic CI cannot access privileged deploy credentials by default;
- [ ] backup destination protected;
- [ ] restore path tested;
- [ ] firewall/public ports reviewed;
- [ ] admin access documented;
- [ ] production versions pinned intentionally.

## Principle

Owning the infrastructure gives us control, but it also moves the security responsibility to us. DevOS Forge is only more independent if it is also recoverable and defensible.