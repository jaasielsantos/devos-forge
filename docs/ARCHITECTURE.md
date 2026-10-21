# DevOS Forge — Architecture

## 1. Objective

Define a small, private, self-hosted software forge for our own projects, optimized for operational independence and future DevOS integration.

The architecture must be simple enough to operate on a VPS, but explicit enough to evolve without forcing a rewrite.

## 2. System context

```text
Developer / DevOS / Agent
          |
          | SSH / HTTPS / API
          v
+-----------------------------+
|        Public endpoint      |
|     git.<our-domain>        |
+-------------+---------------+
              |
              v
+-----------------------------+
|       Reverse proxy/TLS     |
+-------------+---------------+
              |
              v
+-----------------------------+
|           Forgejo           |
|                             |
| repos / PRs / issues / API  |
| actions / packages / hooks  |
+-------+---------------+-----+
        |               |
        v               v
+---------------+   +----------------+
| PostgreSQL    |   | Persistent Git |
| metadata      |   | data / assets  |
+---------------+   +----------------+
        |
        +-----------------------------+
                                      |
                                      v
                              +---------------+
                              | Forgejo       |
                              | Runner(s)     |
                              +-------+-------+
                                      |
                                      v
                              isolated jobs /
                              Docker workloads
```

## 3. Initial components

### 3.1 Forgejo

Responsibilities:

- repository hosting;
- authentication and authorization;
- Git over SSH/HTTPS;
- repository browser;
- branches, tags and releases;
- issues;
- pull requests and reviews;
- webhooks;
- API;
- Actions control plane;
- package/container registry where useful.

Forgejo is an implementation choice, not a permanent architectural boundary.

### 3.2 PostgreSQL

Stores application metadata and forge state that does not belong in Git repository objects.

Requirements:

- persistent volume;
- authenticated local/private network access;
- regular logical backup;
- restore procedure tested before migration is considered complete.

### 3.3 Runner layer

Runners execute automation requested by the forge.

Initial principles:

- self-hosted;
- under our administrative control;
- jobs isolated from the Forgejo application process;
- prefer ephemeral or containerized job environments;
- do not grant a generic runner unrestricted host access unless a specific workflow requires it;
- allow more runners to be added later without redesigning the forge.

Logical model:

```text
Forgejo Actions
      |
      v
 Job Queue
      |
  +---+-----------------+
  |                     |
  v                     v
Runner: general     Runner: privileged/deploy
  |                     |
container jobs       controlled deployment jobs
```

The initial deployment may start with one runner while preserving this separation conceptually.

### 3.4 Reverse proxy and TLS

The forge should expose a stable HTTPS endpoint while preserving SSH Git access.

The exact reverse proxy implementation remains `TBD` until aligned with the existing VPS ingress stack.

Requirements:

- automated TLS renewal;
- strict HTTPS for web/API;
- upload/body-size limits compatible with Git operations;
- correct proxy headers;
- rate limiting where appropriate;
- clean separation between HTTP(S) and SSH traffic.

### 3.5 Persistent storage

At minimum, persist:

- Git repositories;
- Forgejo configuration/data;
- package artifacts if enabled;
- PostgreSQL data;
- runner state only when actually required.

Application containers are disposable. Data is not.

## 4. Backup architecture

A self-hosted forge without independent backups is merely a new single point of failure.

Minimum model:

```text
VPS primary data
      |
      +--> local snapshot / backup set
      |
      `--> offsite backup destination
```

Backup scope must include everything required to recreate the service:

- repositories;
- database;
- configuration;
- secrets through an approved secure backup mechanism;
- relevant package/artifact data;
- infrastructure manifests.

The project is not considered independent merely because GitHub is no longer the primary host. Restore capability is part of independence.

## 5. DevOS integration boundary

DevOS should not couple directly to Forgejo-specific assumptions wherever avoidable.

Target interface:

```text
DevOS
  |
  v
ForgeProvider
  |
  +-- createRepository()
  +-- getRepository()
  +-- createBranch()
  +-- createIssue()
  +-- createPullRequest()
  +-- mergePullRequest()
  +-- dispatchWorkflow()
  +-- getRunStatus()
  +-- getCommit()
  +-- getDiff()
  `-- receiveEvent()
        |
        v
 ForgejoAdapter
        |
        v
     Forgejo API
```

This interface is conceptual until DevOS integration work begins. It should be driven by actual operations we need, not speculative completeness.

## 6. Agent-native evolution

The future layer belongs above Git/Forgejo:

```text
+------------------------------------------+
|             DevOS Agent Layer            |
|                                          |
| Intent / Decisions / PDS / PBI / PBP     |
| Policies / Agents / Evidence / Provenance|
+----------------------+-------------------+
                       |
                       v
+------------------------------------------+
|                Forge Layer               |
| repositories / PRs / CI / runners / API  |
+----------------------+-------------------+
                       |
                       v
+------------------------------------------+
|                    Git                   |
+------------------------------------------+
```

Possible future first-class objects include:

- human intent;
- machine-readable decisions;
- execution plans;
- agent identity;
- execution lineage;
- policy evaluations;
- test evidence;
- approval provenance;
- links from commits/PRs to PDS/PBI/PBP.

These are not Phase 1 requirements.

## 7. Trust boundaries

The initial system has at least these trust zones:

```text
Internet
   |
   v
[ reverse proxy ]
   |
   v
[ Forgejo application ]
   |
   +--> [ PostgreSQL ]
   |
   +--> [ repository storage ]
   |
   `--> [ runner boundary ] --> untrusted build/test code
```

Runner workloads must be treated as more dangerous than the Forgejo web application because they execute repository-defined code.

## 8. Failure model

Initial single-VPS deployment accepts that the VPS is a runtime failure domain.

We mitigate this with:

- offsite backups;
- reproducible deployment manifests;
- documented restore procedure;
- optional GitHub mirror during transition;
- ability to redeploy the stack on another VPS.

High availability is not an initial requirement.

Recoverability is.

## 9. Design constraints

- Small private installation, not internet-scale SaaS.
- Prefer boring, well-supported components.
- Keep infrastructure reproducible.
- Avoid unnecessary distributed systems.
- Separate durable data from disposable compute.
- Minimize vendor lock-in.
- Preserve standard Git interoperability.
- Build custom functionality only where DevOS creates unique value.