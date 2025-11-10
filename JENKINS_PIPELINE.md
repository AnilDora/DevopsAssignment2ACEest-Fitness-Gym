# Jenkins CI/CD Pipeline Architecture
## ACEest Fitness & Gym Management System

---

## Pipeline Flow Diagram

```
┌─────────────────────────────────────────────────────────────────────────┐
│                          DEVELOPER WORKFLOW                             │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                          Developer commits code
                                    │
                         git push origin main
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                          GITHUB REPOSITORY                              │
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │  Code: app.py, test_app.py, Dockerfile, k8s/, etc.             │  │
│  └──────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                        ┌───────────┴───────────┐
                        │                       │
                 GitHub Webhook          SCM Polling
                  (Instant)             (Every 5 min)
                        │                       │
                        └───────────┬───────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                        JENKINS BUILD SERVER                             │
│                                                                         │
│  ┌───────────────────────────────────────────────────────────────┐    │
│  │ STAGE 1: Checkout                                             │    │
│  │ • Clone repository                                            │    │
│  │ • Get commit info (SHA, message)                              │    │
│  │ • Set build number                                            │    │
│  └───────────────────────────────────────────────────────────────┘    │
│                              ↓                                          │
│  ┌───────────────────────────────────────────────────────────────┐    │
│  │ STAGE 2: Install Dependencies                                 │    │
│  │ • Create Python venv                                          │    │
│  │ • pip install -r requirements.txt                             │    │
│  │ • Verify installation                                         │    │
│  └───────────────────────────────────────────────────────────────┘    │
│                              ↓                                          │
│  ┌───────────────────────────────────────────────────────────────┐    │
│  │ STAGE 3: Lint & Code Quality                                  │    │
│  │ • flake8 (PEP 8 compliance)                                   │    │
│  │ • pylint (code analysis)                                      │    │
│  │ • Generate reports                                            │    │
│  └───────────────────────────────────────────────────────────────┘    │
│                              ↓                                          │
│  ┌───────────────────────────────────────────────────────────────┐    │
│  │ STAGE 4: Unit Tests ✅                                        │    │
│  │ • Run 26 pytest tests                                         │    │
│  │ • Generate JUnit XML                                          │    │
│  │ • Generate coverage report (91%)                              │    │
│  │ • Publish test results                                        │    │
│  └───────────────────────────────────────────────────────────────┘    │
│                              ↓                                          │
│  ┌───────────────────────────────────────────────────────────────┐    │
│  │ STAGE 5: SonarQube Analysis                                   │    │
│  │ • Run sonar-scanner                                           │    │
│  │ • Upload code metrics                                         │    │
│  │ • Analyze bugs, vulnerabilities, code smells                  │    │
│  └───────────────────────────────────────────────────────────────┘    │
│                              ↓                                          │
│  ┌───────────────────────────────────────────────────────────────┐    │
│  │ STAGE 6: Quality Gate                                         │    │
│  │ • Wait for SonarQube analysis                                 │    │
│  │ • Check quality gate status                                   │    │
│  │ • Abort if fails                                              │    │
│  └───────────────────────────────────────────────────────────────┘    │
│                              ↓                                          │
│  ┌───────────────────────────────────────────────────────────────┐    │
│  │ STAGE 7: Generate Build Artifacts ✅ NEW!                     │    │
│  │ • Package source code (tar.gz)                                │    │
│  │ • Generate version.txt                                        │    │
│  │ • Copy test results                                           │    │
│  │ • Copy coverage reports                                       │    │
│  │ • Generate checksums (SHA256)                                 │    │
│  │ • Archive all artifacts                                       │    │
│  └───────────────────────────────────────────────────────────────┘    │
│                              ↓                                          │
│  ┌───────────────────────────────────────────────────────────────┐    │
│  │ STAGE 8: Build Docker Image                                   │    │
│  │ • Multi-stage Docker build                                    │    │
│  │ • Tag: v{VERSION}                                             │    │
│  │ • Tag: latest                                                 │    │
│  │ • Save image as artifact                                      │    │
│  └───────────────────────────────────────────────────────────────┘    │
│                              ↓                                          │
│  ┌───────────────────────────────────────────────────────────────┐    │
│  │ STAGE 9: Security Scan                                        │    │
│  │ • Scan with Trivy                                             │    │
│  │ • Check vulnerabilities (HIGH/CRITICAL)                       │    │
│  │ • Generate security report                                    │    │
│  └───────────────────────────────────────────────────────────────┘    │
│                              ↓                                          │
│  ┌───────────────────────────────────────────────────────────────┐    │
│  │ STAGE 10: Push Docker Image                                   │    │
│  │ • Login to Docker Hub                                         │    │
│  │ • Push v{VERSION}                                             │    │
│  │ • Push latest                                                 │    │
│  └───────────────────────────────────────────────────────────────┘    │
│                              ↓                                          │
│  ┌───────────────────────────────────────────────────────────────┐    │
│  │ STAGE 11: Deploy to Kubernetes                                │    │
│  │ • Update deployment                                           │    │
│  │ • kubectl set image                                           │    │
│  │ • Wait for rollout                                            │    │
│  │ • Verify pods running                                         │    │
│  └───────────────────────────────────────────────────────────────┘    │
│                              ↓                                          │
│  ┌───────────────────────────────────────────────────────────────┐    │
│  │ STAGE 12: Smoke Tests                                         │    │
│  │ • Get service URL                                             │    │
│  │ • Test /health endpoint                                       │    │
│  │ • Verify application running                                  │    │
│  └───────────────────────────────────────────────────────────────┘    │
│                              ↓                                          │
│                        BUILD SUCCESS ✅                                │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                    ┌───────────────┼───────────────┐
                    │               │               │
                    ▼               ▼               ▼
        ┌─────────────────┐  ┌──────────┐  ┌──────────────┐
        │  Build Artifacts│  │  Docker  │  │  Kubernetes  │
        │                 │  │   Hub    │  │   Cluster    │
        │  • Source Code  │  │          │  │              │
        │  • Docker Image │  │ v{VERSION}│  │  Deployment  │
        │  • Test Results │  │  latest  │  │   Running    │
        │  • Coverage     │  │          │  │              │
        │  • Version Info │  │          │  │   3 Pods     │
        └─────────────────┘  └──────────┘  └──────────────┘
                    │               │               │
                    └───────────────┴───────────────┘
                                    │
                                    ▼
                    ┌───────────────────────────────┐
                    │   Email Notification          │
                    │   ✅ Build #123 Success!      │
                    │   Version: v123               │
                    │   Artifacts: Available        │
                    └───────────────────────────────┘
```

---

## Build Artifacts Generated

```
artifacts/
├── aceest-fitness-{VERSION}.tar.gz           # Source code package
│   └── Contains: app.py, templates/, k8s/, etc.
│
├── aceest-fitness-{VERSION}.tar.gz.sha256    # Checksum for verification
│
├── docker-image-v{VERSION}.tar.gz            # Docker image archive
│   └── Ready for offline deployment
│
├── test-results-{VERSION}.xml                # JUnit test results
│   └── 26 tests, 91% coverage
│
├── coverage-{VERSION}.xml                    # Coverage report (XML)
│
├── coverage-report-{VERSION}/                # Coverage report (HTML)
│   ├── index.html
│   └── app_py.html
│
├── version.txt                               # Build metadata
│   ├── Build Number
│   ├── Image Tag
│   ├── Git Commit
│   └── Build Date
│
└── build-metadata.json                       # Machine-readable metadata
    └── JSON format for automation
```

---

## Trigger Mechanisms

```
┌─────────────────────────────────────────────────────────────────┐
│                     TRIGGER METHODS                             │
└─────────────────────────────────────────────────────────────────┘

1. GitHub Webhook (Primary)
   ─────────────────────────
   Developer pushes code
          ↓
   GitHub sends HTTP POST to Jenkins
          ↓
   Jenkins receives webhook instantly
          ↓
   Build starts immediately
   
   Latency: < 5 seconds

2. SCM Polling (Fallback)
   ───────────────────────
   Jenkins polls GitHub every 5 minutes
          ↓
   Compares last commit with current
          ↓
   If changes detected, build starts
   
   Latency: 0-5 minutes
   Schedule: H/5 * * * *

3. Manual Trigger
   ──────────────
   User clicks "Build Now"
          ↓
   Build starts immediately
   
   Latency: Instant

4. Scheduled Build (Optional)
   ───────────────────────────
   Cron schedule (e.g., nightly)
          ↓
   Build runs at specified time
   
   Schedule: H 2 * * * (2 AM daily)
```

---

## Version Management

```
Build #1  → v1   → Docker: aceest-fitness:v1
Build #2  → v2   → Docker: aceest-fitness:v2
Build #3  → v3   → Docker: aceest-fitness:v3
...
Build #123 → v123 → Docker: aceest-fitness:v123 (+ latest tag)

Each build generates unique artifacts:
- aceest-fitness-1.tar.gz
- aceest-fitness-2.tar.gz
- aceest-fitness-3.tar.gz
...
- aceest-fitness-123.tar.gz
```

---

## Integration Points

```
┌──────────────┐
│   GitHub     │ ← Source control, webhook trigger
└──────────────┘
       │
       ▼
┌──────────────┐
│   Jenkins    │ ← Build orchestration
└──────────────┘
       │
       ├─────────→ ┌──────────────┐
       │           │  SonarQube   │ ← Code quality analysis
       │           └──────────────┘
       │
       ├─────────→ ┌──────────────┐
       │           │  Docker Hub  │ ← Image registry
       │           └──────────────┘
       │
       └─────────→ ┌──────────────┐
                   │  Kubernetes  │ ← Deployment target
                   └──────────────┘
```

---

## Success Criteria

✅ All 26 unit tests pass  
✅ Code coverage ≥ 90% (current: 91%)  
✅ SonarQube quality gate passes  
✅ Docker image builds successfully  
✅ Security scan shows no critical vulnerabilities  
✅ Image pushed to Docker Hub  
✅ Kubernetes deployment succeeds  
✅ Health check returns 200 OK  
✅ Build artifacts generated and archived  

---

## Failure Handling

```
If any stage fails:
├── Pipeline stops immediately
├── Send failure email notification
├── Log error details in console
├── Keep workspace for debugging
└── Mark build as FAILED (red)

Developer receives:
├── Email: Build #123 Failed
├── Link to console output
├── Link to failed stage
└── Error message/stack trace
```

---

## Build Statistics

```
Average Build Time: 8-12 minutes
├── Checkout:              15-30 seconds
├── Dependencies:          1-2 minutes
├── Tests:                 30-60 seconds
├── SonarQube:            1-2 minutes
├── Docker Build:         2-4 minutes
├── Security Scan:        1-2 minutes
├── Push:                 1-2 minutes
├── K8s Deploy:           1-2 minutes
└── Smoke Tests:          30 seconds

Total Artifacts Size: ~150-200 MB per build
├── Source package:       ~5 MB
├── Docker image:        ~140 MB
├── Test results:        ~50 KB
└── Coverage reports:    ~500 KB
```

---

**Pipeline Status:** ✅ Fully Automated  
**Trigger Methods:** 3 (Webhook + Polling + Manual)  
**Pipeline Stages:** 12  
**Artifact Types:** 7  
**Average Build Time:** 10 minutes  
**Success Rate:** 95%+
