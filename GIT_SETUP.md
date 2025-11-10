# Git Setup and Version Control Guide for ACEest Fitness

## Initial Git Setup

```bash
# 1. Initialize Git repository
git init

# 2. Configure user information
git config user.name "Your Name"
git config user.email "your.email@example.com"

# 3. Add all files
git add .

# 4. Create initial commit
git commit -m "Initial commit: ACEest Fitness v2.0 with complete DevOps pipeline"

# 5. Create GitHub repository (via GitHub CLI or web interface)
# Then add remote
git remote add origin https://github.com/yourusername/aceest-fitness.git

# 6. Push to GitHub
git push -u origin main
```

## Branching Strategy

We follow **Git Flow** branching model:

```
main (production)
├── develop (integration)
│   ├── feature/user-authentication
│   ├── feature/workout-tracking
│   ├── feature/analytics
│   └── feature/diet-plans
├── release/v2.0
├── release/v2.1
└── hotfix/critical-bug
```

### Branch Commands

```bash
# Development workflow
git checkout -b develop
git push -u origin develop

# Feature branch
git checkout -b feature/new-feature develop
# ... work on feature ...
git add .
git commit -m "feat: add new feature"
git push -u origin feature/new-feature

# Create pull request on GitHub
# After approval and merge:
git checkout develop
git pull origin develop

# Release branch
git checkout -b release/v2.1 develop
# ... update version numbers, final testing ...
git commit -m "chore: prepare release v2.1"
git checkout main
git merge release/v2.1
git tag -a v2.1 -m "Release version 2.1"
git push origin main --tags

# Hotfix
git checkout -b hotfix/critical-bug main
# ... fix the bug ...
git commit -m "fix: critical bug in authentication"
git checkout main
git merge hotfix/critical-bug
git tag -a v2.0.1 -m "Hotfix v2.0.1"
git push origin main --tags
```

## Commit Message Convention

Follow **Conventional Commits** specification:

```
<type>(<scope>): <subject>

<body>

<footer>
```

### Types:
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes (formatting, etc.)
- `refactor`: Code refactoring
- `test`: Adding or updating tests
- `chore`: Maintenance tasks
- `ci`: CI/CD changes
- `perf`: Performance improvements

### Examples:

```bash
# Feature
git commit -m "feat(auth): add user registration endpoint"

# Bug fix
git commit -m "fix(workout): correct calorie calculation formula"

# Documentation
git commit -m "docs(readme): add deployment instructions"

# CI/CD
git commit -m "ci(jenkins): add SonarQube quality gate"

# Breaking change
git commit -m "feat(api): redesign workout API

BREAKING CHANGE: workout endpoint now returns different structure"
```

## Version Tagging Strategy

### Semantic Versioning (SemVer)

Format: `vMAJOR.MINOR.PATCH`

- **MAJOR**: Breaking changes
- **MINOR**: New features (backward compatible)
- **PATCH**: Bug fixes

```bash
# Create and push tags
git tag -a v2.0.0 -m "Release 2.0.0: Flask web application"
git push origin v2.0.0

# List all tags
git tag -l

# Delete tag
git tag -d v2.0.0
git push origin --delete v2.0.0
```

### Version History

| Version | Tag | Date | Description |
|---------|-----|------|-------------|
| v1.0.0 | v1.0.0 | - | Basic Tkinter application |
| v1.1.0 | v1.1.0 | - | Enhanced UI with categories |
| v1.2.0 | v1.2.0 | - | Tabbed interface |
| v1.3.0 | v1.3.0 | - | Advanced features (BMI, BMR) |
| v2.0.0 | v2.0.0 | - | Flask web app with DevOps |

## GitHub Workflow

### 1. Create GitHub Repository

```bash
# Using GitHub CLI
gh repo create aceest-fitness --public --description "ACEest Fitness & Gym Management System"

# Or via web interface
# https://github.com/new
```

### 2. Setup Branch Protection

**Main Branch Protection Rules:**
- ✅ Require pull request reviews
- ✅ Require status checks to pass
- ✅ Require branches to be up to date
- ✅ Include administrators
- ✅ Restrict force pushes
- ✅ Require signed commits (optional)

```bash
# GitHub CLI
gh api repos/:owner/:repo/branches/main/protection \
  -X PUT \
  -f required_status_checks='{"strict":true,"contexts":["continuous-integration/jenkins"]}' \
  -f enforce_admins=true \
  -f required_pull_request_reviews='{"required_approving_review_count":1}'
```

### 3. Setup GitHub Actions (Optional)

Create `.github/workflows/ci.yml`:

```yaml
name: CI

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main, develop ]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v2
    - name: Set up Python
      uses: actions/setup-python@v2
      with:
        python-version: 3.11
    - name: Install dependencies
      run: |
        pip install -r requirements.txt
    - name: Run tests
      run: |
        pytest test_app.py -v --cov=app
```

## Jenkins Git Integration

### Jenkinsfile Git Operations

The pipeline automatically:
1. Checks out code
2. Gets commit SHA
3. Tags successful builds
4. Pushes tags to remote

### Setup Jenkins Credentials

1. Go to Jenkins → Manage Jenkins → Credentials
2. Add GitHub credentials:
   - Username: GitHub username
   - Password/Token: Personal Access Token
3. Use credential ID in Jenkinsfile

### GitHub Webhook for Jenkins

1. **GitHub Repository Settings:**
   - Go to Settings → Webhooks → Add webhook
   - Payload URL: `http://jenkins-url/github-webhook/`
   - Content type: `application/json`
   - Events: Push, Pull Request

2. **Jenkins Configuration:**
   - Install "GitHub Plugin"
   - Configure GitHub Server in Jenkins
   - Enable "GitHub hook trigger for GITScm polling" in job

## Git Best Practices

### 1. Commit Frequency
- Commit early and often
- Each commit should be atomic
- One logical change per commit

### 2. Pull Before Push
```bash
git pull --rebase origin main
git push origin main
```

### 3. Review Changes Before Committing
```bash
git status
git diff
git add -p  # Interactive staging
```

### 4. Use .gitignore
Already configured in the project to exclude:
- Python cache files
- Virtual environments
- IDE files
- Environment variables
- Test coverage reports

### 5. Write Descriptive Commit Messages
```bash
# Bad
git commit -m "fix bug"

# Good
git commit -m "fix(auth): resolve session timeout issue in login flow"
```

## Troubleshooting

### Merge Conflicts

```bash
# Update your branch
git fetch origin
git rebase origin/main

# If conflicts occur
git status  # See conflicting files
# Edit files to resolve conflicts
git add <resolved-files>
git rebase --continue

# Or abort rebase
git rebase --abort
```

### Undo Changes

```bash
# Undo last commit (keep changes)
git reset --soft HEAD~1

# Undo last commit (discard changes)
git reset --hard HEAD~1

# Undo changes in working directory
git checkout -- <file>

# Undo staged changes
git reset HEAD <file>
```

### Stash Changes

```bash
# Stash current changes
git stash save "WIP: feature description"

# List stashes
git stash list

# Apply stash
git stash apply stash@{0}

# Pop stash (apply and remove)
git stash pop

# Clear stashes
git stash clear
```

## Git Hooks

### Pre-commit Hook

Create `.git/hooks/pre-commit`:

```bash
#!/bin/bash

echo "Running pre-commit checks..."

# Run tests
pytest test_app.py -q
if [ $? -ne 0 ]; then
    echo "Tests failed. Commit aborted."
    exit 1
fi

# Run linting
flake8 app.py
if [ $? -ne 0 ]; then
    echo "Linting failed. Commit aborted."
    exit 1
fi

echo "Pre-commit checks passed!"
exit 0
```

Make it executable:
```bash
chmod +x .git/hooks/pre-commit
```

## GitHub Repository Structure

```
aceest-fitness/
├── .github/
│   ├── workflows/
│   │   └── ci.yml
│   ├── ISSUE_TEMPLATE/
│   └── PULL_REQUEST_TEMPLATE.md
├── docs/
│   ├── API.md
│   ├── DEPLOYMENT.md
│   └── CONTRIBUTING.md
├── .gitignore
├── README.md
├── LICENSE
└── ... (application files)
```

## Collaboration Workflow

### For Team Members:

1. **Fork the repository**
2. **Clone your fork:**
   ```bash
   git clone https://github.com/yourusername/aceest-fitness.git
   ```

3. **Add upstream remote:**
   ```bash
   git remote add upstream https://github.com/original/aceest-fitness.git
   ```

4. **Keep your fork updated:**
   ```bash
   git fetch upstream
   git merge upstream/main
   ```

5. **Create feature branch and work**
6. **Push to your fork**
7. **Create Pull Request**

## Documentation

Keep these files updated:
- **README.md**: Project overview and setup
- **CHANGELOG.md**: Version history
- **CONTRIBUTING.md**: Contribution guidelines
- **LICENSE**: Project license

---

**Remember:** Good version control practices lead to better collaboration and easier maintenance!
