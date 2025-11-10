# Git Version Control Strategy
## ACEest Fitness & Gym - DevOps Assignment

### Repository Information
- **Repository Name**: DevopsAssignment2ACEest-Fitness-Gym
- **Owner**: AnilDora
- **URL**: https://github.com/AnilDora/DevopsAssignment2ACEest-Fitness-Gym.git
- **Current Branch**: main
- **Latest Tag**: v2.1

---

## Branching Strategy (Git Flow)

### Main Branches

#### 1. **main** (Production)
- **Purpose**: Production-ready code
- **Protection**: Always stable, deployable
- **Merge From**: release/* and hotfix/* branches only
- **Tags**: All version tags (v1.0, v2.0, v2.1, etc.)

#### 2. **develop** (Development)
- **Purpose**: Integration branch for features
- **Protection**: Should be stable enough for testing
- **Merge From**: feature/* branches
- **Merge To**: release/* branches

### Supporting Branches

#### 3. **feature/** (Feature Development)
- **Naming**: `feature/<feature-name>`
- **Examples**: 
  - `feature/user-authentication`
  - `feature/workout-tracking`
  - `feature/diet-calculator`
- **Created From**: develop
- **Merged To**: develop
- **Lifetime**: Deleted after merge

#### 4. **release/** (Release Preparation)
- **Naming**: `release/<version>`
- **Examples**: `release/v2.2`, `release/v3.0`
- **Created From**: develop
- **Merged To**: main AND develop
- **Purpose**: Final testing, bug fixes, version bumps
- **Lifetime**: Deleted after release

#### 5. **hotfix/** (Production Fixes)
- **Naming**: `hotfix/<issue-name>`
- **Examples**: `hotfix/security-patch`, `hotfix/login-bug`
- **Created From**: main
- **Merged To**: main AND develop
- **Purpose**: Critical production bug fixes
- **Lifetime**: Deleted after merge

---

## Commit Message Convention

Following **Conventional Commits** specification:

### Format
```
<type>(<scope>): <subject>

<body>

<footer>
```

### Types
- **feat**: New feature
- **fix**: Bug fix
- **docs**: Documentation changes
- **style**: Code style changes (formatting, no logic change)
- **refactor**: Code refactoring
- **perf**: Performance improvements
- **test**: Adding or updating tests
- **build**: Build system changes
- **ci**: CI/CD pipeline changes
- **chore**: Maintenance tasks

### Examples
```bash
feat(dashboard): add workout progress chart

- Integrate Chart.js for data visualization
- Add API endpoint for workout summary
- Create progress chart component

Closes #123

---

fix(auth): resolve login session timeout issue

- Increase session timeout to 30 minutes
- Add session refresh mechanism
- Update security headers

Fixes #456

---

docs(readme): update deployment instructions

- Add Docker deployment steps
- Include Kubernetes manifests guide
- Update environment variable docs

---

ci(jenkins): add SonarQube quality gate

- Configure SonarQube scanner
- Set coverage threshold to 80%
- Add quality gate check stage

BREAKING CHANGE: Pipeline now fails on quality gate violations
```

---

## Tagging Strategy (Semantic Versioning)

### Format: `vMAJOR.MINOR.PATCH`

#### Version Components
- **MAJOR**: Incompatible API changes (v1.0 → v2.0)
- **MINOR**: New features, backward compatible (v2.0 → v2.1)
- **PATCH**: Bug fixes, backward compatible (v2.1.0 → v2.1.1)

### Tagging Commands
```bash
# Create annotated tag
git tag -a v2.1 -m "Version 2.1: Description"

# Push tag to remote
git push origin v2.1

# Push all tags
git push --tags

# List all tags
git tag

# Delete local tag
git tag -d v2.1

# Delete remote tag
git push origin :refs/tags/v2.1
```

### Version History
- **v1.0**: Initial Tkinter application
- **v2.0**: Flask web application with DevOps pipeline
- **v2.1**: Simplified UI for college assignment

---

## Branch Management Commands

### Creating Branches
```bash
# Create and switch to develop branch
git checkout -b develop main

# Create feature branch from develop
git checkout -b feature/new-feature develop

# Create release branch
git checkout -b release/v2.2 develop

# Create hotfix branch from main
git checkout -b hotfix/critical-bug main
```

### Merging Branches
```bash
# Merge feature into develop
git checkout develop
git merge --no-ff feature/new-feature

# Merge release into main
git checkout main
git merge --no-ff release/v2.2
git tag -a v2.2 -m "Release version 2.2"

# Merge release back into develop
git checkout develop
git merge --no-ff release/v2.2

# Delete merged branch
git branch -d feature/new-feature
```

### Branch Operations
```bash
# List all branches
git branch -a

# Switch branches
git checkout branch-name

# Delete local branch
git branch -d branch-name

# Delete remote branch
git push origin --delete branch-name

# Rename current branch
git branch -m new-name
```

---

## Workflow Examples

### Feature Development Workflow
```bash
# 1. Start from develop
git checkout develop
git pull origin develop

# 2. Create feature branch
git checkout -b feature/workout-analytics

# 3. Make changes and commit
git add .
git commit -m "feat(analytics): add workout analytics dashboard"

# 4. Push feature branch
git push origin feature/workout-analytics

# 5. Create Pull Request on GitHub
# (Review and approve)

# 6. Merge into develop
git checkout develop
git merge --no-ff feature/workout-analytics

# 7. Push develop
git push origin develop

# 8. Delete feature branch
git branch -d feature/workout-analytics
git push origin --delete feature/workout-analytics
```

### Release Workflow
```bash
# 1. Create release branch from develop
git checkout develop
git pull origin develop
git checkout -b release/v2.2

# 2. Update version numbers and changelog
# Edit files...
git commit -m "chore(release): bump version to 2.2"

# 3. Test and fix bugs
git commit -m "fix(release): resolve pre-release bugs"

# 4. Merge into main
git checkout main
git merge --no-ff release/v2.2
git tag -a v2.2 -m "Release version 2.2"
git push origin main --tags

# 5. Merge back into develop
git checkout develop
git merge --no-ff release/v2.2
git push origin develop

# 6. Delete release branch
git branch -d release/v2.2
```

### Hotfix Workflow
```bash
# 1. Create hotfix from main
git checkout main
git checkout -b hotfix/security-patch

# 2. Fix the issue
git commit -m "fix(security): patch authentication vulnerability"

# 3. Merge into main
git checkout main
git merge --no-ff hotfix/security-patch
git tag -a v2.1.1 -m "Hotfix: Security patch"
git push origin main --tags

# 4. Merge into develop
git checkout develop
git merge --no-ff hotfix/security-patch
git push origin develop

# 5. Delete hotfix branch
git branch -d hotfix/security-patch
```

---

## Pull Request Guidelines

### PR Template
```markdown
## Description
Brief description of changes

## Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation update

## Testing
- [ ] Unit tests pass
- [ ] Integration tests pass
- [ ] Manual testing completed

## Checklist
- [ ] Code follows style guidelines
- [ ] Self-review completed
- [ ] Comments added for complex code
- [ ] Documentation updated
- [ ] No new warnings generated
```

### PR Review Process
1. Code review by team member
2. Automated tests must pass
3. CI/CD pipeline must succeed
4. Approved by at least one reviewer
5. Squash and merge (or merge commit)

---

## Git Hooks (Optional)

### Pre-commit Hook
```bash
#!/bin/sh
# Run tests before commit
pytest

# Run linter
flake8 app.py test_app.py

# Check commit message format
# (Add commit-msg hook)
```

### Commit-msg Hook
```bash
#!/bin/sh
# Validate commit message format
commit_msg=$(cat "$1")
pattern="^(feat|fix|docs|style|refactor|perf|test|build|ci|chore)(\([a-z]+\))?: .+"

if ! echo "$commit_msg" | grep -qE "$pattern"; then
    echo "Error: Commit message doesn't follow conventional commits format"
    echo "Format: type(scope): subject"
    exit 1
fi
```

---

## Best Practices

### Do's ✅
- Commit frequently with meaningful messages
- Keep commits atomic (one logical change)
- Write descriptive commit messages
- Always pull before push
- Use feature branches for development
- Tag all releases
- Delete merged branches
- Review code before merging

### Don'ts ❌
- Don't commit directly to main
- Don't force push to shared branches
- Don't commit large binary files
- Don't commit sensitive data (passwords, keys)
- Don't use generic commit messages ("fix", "update")
- Don't merge without testing
- Don't leave stale branches

---

## GitHub Integration

### Repository Settings
- **Branch Protection**: Enable for main branch
- **Require PR Reviews**: At least 1 approval
- **Status Checks**: CI/CD must pass
- **Linear History**: Enforce
- **Delete Branch on Merge**: Enable

### GitHub Actions (CI/CD)
Already configured in Jenkinsfile, can also use:
```yaml
# .github/workflows/ci.yml
name: CI Pipeline
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Run tests
        run: pytest
```

---

## Quick Reference

### Daily Commands
```bash
# Check status
git status

# Pull latest changes
git pull origin develop

# Create feature branch
git checkout -b feature/my-feature

# Add and commit
git add .
git commit -m "feat(scope): description"

# Push changes
git push origin feature/my-feature

# View log
git log --oneline --graph --all

# View changes
git diff
```

### Emergency Commands
```bash
# Undo last commit (keep changes)
git reset --soft HEAD~1

# Undo last commit (discard changes)
git reset --hard HEAD~1

# Discard local changes
git restore .

# Stash changes
git stash
git stash pop

# View commit history
git reflog
```

---

## Monitoring & Maintenance

### Regular Tasks
- **Weekly**: Review and clean up merged branches
- **Monthly**: Review and update .gitignore
- **Per Release**: Update CHANGELOG.md
- **Quarterly**: Audit repository size and history

### Health Checks
```bash
# Check repository size
du -sh .git

# Count commits
git rev-list --count HEAD

# List contributors
git shortlog -sn

# Find large files
git rev-list --objects --all | grep "$(git verify-pack -v .git/objects/pack/*.idx | sort -k 3 -n | tail -10 | awk '{print$1}')"
```

---

## Support & Resources

### Documentation
- [Git Documentation](https://git-scm.com/doc)
- [GitHub Guides](https://guides.github.com/)
- [Conventional Commits](https://www.conventionalcommits.org/)
- [Semantic Versioning](https://semver.org/)

### Team Contacts
- **Repository Owner**: AnilDora
- **Maintainers**: [Add team members]

---

**Last Updated**: November 10, 2025  
**Version**: 1.0  
**Status**: Active
