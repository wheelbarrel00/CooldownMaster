# Code Comment Style

Only the rare, genuinely-needed one-liner code note. Default to NO comment. Keep a comment only when it's a short why/gotcha that prevents a bug or explains a non-obvious decision the code can't express (taint workaround, Blizzard API quirk, event-ordering requirement, source of a magic constant, "required empty stub — do not remove"). Remove restating/narration/banner-divider/docstring-header/end-of-block comments and commented-out code. Applies to all authored Lua/XML/TOC; never touch vendored Libs/ or generated/locale files.

# Custom Commands

## Command: "git sequence"

When I ask you to perform a "git sequence", execute the following steps in this exact order. Do not skip any step. Do not combine commands with `&&` — run each command separately (PowerShell does not support `&&`).

### Step 1 — Bump Version
Search the ENTIRE project for every file containing the current version number. This includes but is not limited to:
- The `.toc` file (`## Version:`)
- All `.lua` files that reference the version string
- Any other config or metadata files containing the version

Update ALL of them to the new version number.

### Step 2 — Update `CHANGELOG.md`
Add a new entry at the TOP of `CHANGELOG.md` with:
- The new version number as the heading
- Today's date
- A clear summary of what changed, grouped by category (Bug Fixes, New Features, Improvements, etc.)
- Match the existing changelog format and style exactly

### Step 3 — Stage Changes
```
git add -A
```

### Step 4 — Commit
```
git commit -m "v[new-version] — [short description of changes]"
```

### Step 5 — Push Commit
```
git push origin main
```

### Step 6 — Create Tag
```
git tag -a v[new-version] -m "Release v[new-version]"
```

### Step 7 — Push Tag
```
git push --tags
```
The tag push is what triggers the GitHub Actions release workflow and publishes to CurseForge. This step is critical — never skip it.

### Notes
- Always confirm the new version number with me before starting if I haven't specified it
- Semantic versioning rules: bug fixes = patch (1.0.x), new features = minor (1.x.0), breaking changes = major (x.0.0)
- Do NOT use `&&` to chain commands — run each one separately
- Do NOT create a new tag if one already exists for this version — ask me first
