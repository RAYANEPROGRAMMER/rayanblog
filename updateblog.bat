@echo off
setlocal enabledelayedexpansion

REM Set variables
set "sourcePath=C:\Users\pc\Documents\Obsidian Vault\posts"
set "destinationPath=C:\Users\pc\Documents\rayanblog\content\posts"
set "myrepo=https://github.com/yourusername/rayanblog.git"

REM Error handling
if not exist "%sourcePath%" (
    echo Error: Source path does not exist: %sourcePath%
    exit /b 1
)
if not exist "%destinationPath%" (
    echo Error: Destination path does not exist: %destinationPath%
    exit /b 1
)

REM Check for required commands
for %%C in (git hugo python) do (
    where %%C >nul 2>&1
    if errorlevel 1 (
        echo Error: %%C is not installed or not in PATH.
        exit /b 1
    )
)

REM Step 1: Initialize Git if necessary
if not exist ".git" (
    echo Initializing Git repository...
    git init
    git remote add origin %myrepo%
) else (
    echo Git repository already initialized.
    for /f "tokens=*" %%R in ('git remote') do (
        if /i not "%%R"=="origin" (
            echo Adding remote origin...
            git remote add origin %myrepo%
        )
    )
)

REM Step 2: Sync posts using Robocopy
echo Syncing posts from Obsidian...
robocopy "%sourcePath%" "%destinationPath%" /MIR /Z /W:5 /R:3
if errorlevel 8 (
    echo Error: Robocopy failed with exit code %errorlevel%.
    exit /b 1
)

REM Step 3: Process Markdown files
if not exist "images.py" (
    echo Error: Python script images.py not found.
    exit /b 1
)

echo Processing image links in Markdown files...
python images.py
if errorlevel 1 (
    echo Error: Failed to process image links.
    exit /b 1
)

REM Step 4: Build the Hugo site
echo Building the Hugo site...
hugo
if errorlevel 1 (
    echo Error: Hugo build failed.
    exit /b 1
)

REM Step 5: Stage changes for Git
echo Staging changes for Git...
for /f "tokens=*" %%S in ('git status --porcelain') do set "hasChanges=1"
if not defined hasChanges (
    echo No changes to stage.
) else (
    git add .
)

REM Step 6: Commit changes
set commitMessage=New Blog Post on %date% %time%
for /f "tokens=*" %%C in ('git diff --cached --name-only') do set "hasStagedChanges=1"
if not defined hasStagedChanges (
    echo No changes to commit.
) else (
    echo Committing changes...
    git commit -m "%commitMessage%"
)

REM Step 7: Push to main branch
echo Deploying to GitHub Master...
git push origin master
if errorlevel 1 (
    echo Error: Failed to push to Master branch.
    exit /b 1
)

REM Step 8: Deploy to Hostinger branch
echo Deploying to GitHub Hostinger...
for /f "tokens=*" %%B in ('git branch --list hostinger-deploy') do git branch -D hostinger-deploy

git subtree split --prefix public -b hostinger-deploy
if errorlevel 1 (
    echo Error: Subtree split failed.
    exit /b 1
)

git push origin hostinger-deploy:hostinger --force
if errorlevel 1 (
    echo Error: Failed to push to hostinger branch.
    git branch -D hostinger-deploy
    exit /b 1
)

git branch -D hostinger-deploy
echo All done! Site synced, processed, committed, built, and deployed.
