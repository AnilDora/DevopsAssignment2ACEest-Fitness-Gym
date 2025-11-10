# Git Quick Start Guide
## ACEest Fitness & Gym - DevOps Assignment

### 🚀 Repository Ready!

**GitHub Repository**: https://github.com/AnilDora/DevopsAssignment2ACEest-Fitness-Gym

---

## Current Setup

```
✅ Git Repository: Initialized
✅ GitHub Remote: Connected
✅ Branches: main + develop
✅ Tags: v2.1
✅ Commits: Structured with conventional format
✅ Documentation: Complete
```

---

## Quick Commands for Daily Use

### 1. Check Your Status
```powershell
# See what files changed
git status

# View commit history
git log --oneline --graph --all

# See current branch
git branch
```

### 2. Make Changes
```powershell
# Switch to develop branch
git checkout develop

# Pull latest changes
git pull origin develop

# Make your changes to files...

# Check what changed
git diff

# Stage all changes
git add .

# Commit with conventional format
git commit -m "feat(component): add new feature description"

# Push to GitHub
git push origin develop
```

### 3. Feature Development
```powershell
# Create new feature branch
git checkout -b feature/user-profile

# Work on your feature...

# Commit changes
git add .
git commit -m "feat(profile): add user profile page"

# Push feature branch
git push origin feature/user-profile

# When done, merge to develop
git checkout develop
git merge feature/user-profile
git push origin develop
```

### 4. View History
```powershell
# Beautiful graph view
git log --oneline --graph --all --decorate

# See specific file history
git log --follow -- app.py

# View changes in last commit
git show

# See all tags
git tag
```

---

## Commit Message Format

Use this format for all commits:

```
<type>(<scope>): <description>

[optional body]

[optional footer]
```

### Types:
- **feat**: New feature
- **fix**: Bug fix
- **docs**: Documentation
- **style**: Formatting
- **refactor**: Code restructuring
- **test**: Add tests
- **chore**: Maintenance

### Examples:
```bash
feat(auth): add user login functionality
fix(dashboard): resolve chart rendering issue
docs(readme): update installation instructions
refactor(api): simplify workout endpoint logic
test(app): add unit tests for BMI calculation
```

---

## Branching Strategy

```
main (production)
  ├── v2.1 (current tag)
  │
  └── develop (integration)
       ├── feature/new-feature
       ├── feature/another-feature
       └── hotfix/urgent-fix
```

### Creating Branches:
```powershell
# Feature branch
git checkout -b feature/workout-analytics develop

# Hotfix branch (from main)
git checkout -b hotfix/security-patch main

# Release branch
git checkout -b release/v2.2 develop
```

---

## Common Workflows

### Adding a New Feature
```powershell
# 1. Start from develop
git checkout develop
git pull origin develop

# 2. Create feature branch
git checkout -b feature/diet-calculator

# 3. Work and commit
git add .
git commit -m "feat(diet): add calorie calculator"

# 4. Push to GitHub
git push origin feature/diet-calculator

# 5. Create Pull Request on GitHub
# (or merge locally)
git checkout develop
git merge feature/diet-calculator
git push origin develop
```

### Creating a Release
```powershell
# 1. Create release branch
git checkout -b release/v2.2 develop

# 2. Update version numbers
# Edit CHANGELOG.md, version files...
git commit -m "chore(release): bump version to 2.2"

# 3. Merge to main
git checkout main
git merge --no-ff release/v2.2

# 4. Tag the release
git tag -a v2.2 -m "Release version 2.2 with new features"

# 5. Push everything
git push origin main --tags

# 6. Merge back to develop
git checkout develop
git merge --no-ff release/v2.2
git push origin develop
```

### Emergency Hotfix
```powershell
# 1. Create hotfix from main
git checkout -b hotfix/critical-bug main

# 2. Fix the issue
git commit -m "fix(critical): resolve security vulnerability"

# 3. Merge to main
git checkout main
git merge hotfix/critical-bug
git tag -a v2.1.1 -m "Hotfix: Security patch"
git push origin main --tags

# 4. Merge to develop
git checkout develop
git merge hotfix/critical-bug
git push origin develop
```

---

## Troubleshooting

### Undo Last Commit (keep changes)
```powershell
git reset --soft HEAD~1
```

### Undo Last Commit (discard changes)
```powershell
git reset --hard HEAD~1
```

### Discard Local Changes
```powershell
# Single file
git restore filename

# All files
git restore .
```

### Stash Changes Temporarily
```powershell
# Save changes
git stash

# View stashed changes
git stash list

# Restore stashed changes
git stash pop
```

### Update from Remote
```powershell
# Fetch changes
git fetch origin

# Pull and merge
git pull origin main
```

### View Remote Info
```powershell
git remote -v
git remote show origin
```

---

## GitHub Operations

### Clone Repository (for team members)
```powershell
git clone https://github.com/AnilDora/DevopsAssignment2ACEest-Fitness-Gym.git
cd DevopsAssignment2ACEest-Fitness-Gym
```

### Update Your Fork
```powershell
git fetch origin
git checkout main
git merge origin/main
```

### Create Pull Request
1. Push your branch to GitHub
2. Go to repository on GitHub
3. Click "Pull requests" → "New pull request"
4. Select your branch
5. Add description and create PR

---

## File Status Reference

```
?? - Untracked file
A  - Added file
M  - Modified file
D  - Deleted file
R  - Renamed file
C  - Copied file
U  - Updated but unmerged
```

---

## Git Aliases (Optional)

Add to `.gitconfig` for shortcuts:

```ini
[alias]
    st = status
    co = checkout
    br = branch
    ci = commit
    lg = log --oneline --graph --all --decorate
    last = log -1 HEAD
    unstage = reset HEAD --
```

Usage:
```powershell
git st        # instead of git status
git co main   # instead of git checkout main
git lg        # beautiful log graph
```

---

## Best Practices

### ✅ Do:
- Commit frequently with clear messages
- Pull before push
- Use feature branches
- Write descriptive commit messages
- Tag releases
- Keep main branch stable

### ❌ Don't:
- Commit directly to main
- Use generic messages ("fix", "update")
- Force push to shared branches
- Commit large binary files
- Leave branches unmerged

---

## Repository Statistics

Current status of your repository:

```
Repository: DevopsAssignment2ACEest-Fitness-Gym
Owner: AnilDora
Branches: 2 (main, develop)
Tags: 1 (v2.1)
Commits: 4
Files: 30+
Size: ~1 MB
```

---

## Need Help?

### Documentation Files:
- **GIT_WORKFLOW.md** - Complete workflow guide
- **GIT_STATUS.md** - Current status and setup
- **GIT_SETUP.md** - Initial setup instructions
- **CHANGELOG.md** - Version history

### External Resources:
- [Git Basics](https://git-scm.com/book/en/v2/Getting-Started-Git-Basics)
- [GitHub Docs](https://docs.github.com/)
- [Git Cheat Sheet](https://education.github.com/git-cheat-sheet-education.pdf)

### GitHub Repository:
https://github.com/AnilDora/DevopsAssignment2ACEest-Fitness-Gym

---

## Quick Reference Card

```
┌─────────────────────────────────────────────────┐
│  COMMON GIT COMMANDS                             │
├─────────────────────────────────────────────────┤
│  git status          - Check status              │
│  git add .           - Stage all changes         │
│  git commit -m ""    - Commit changes            │
│  git push            - Push to remote            │
│  git pull            - Pull from remote          │
│  git checkout        - Switch branch             │
│  git branch          - List branches             │
│  git log             - View history              │
│  git diff            - View changes              │
│  git tag             - List tags                 │
└─────────────────────────────────────────────────┘
```

---

**Last Updated**: November 10, 2025  
**Version**: 1.0  
**Repository**: https://github.com/AnilDora/DevopsAssignment2ACEest-Fitness-Gym
