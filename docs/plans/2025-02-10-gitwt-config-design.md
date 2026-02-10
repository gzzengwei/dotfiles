# Git Worktree Config Management Design

**Date**: 2025-02-10
**Status**: Approved
**Author**: User

## Overview

Enhance the `gitwt` script to automatically copy configuration files to new git worktrees based on a `.gitwt` configuration file in the repository root.

## Requirements

1. Read a `.gitwt` config file in the repository root
2. Fetch a list of config/environment files and copy them to target worktree folder
3. Provide suggestions for what `.gitwt` should contain based on common config files

## Configuration File Format

The `.gitwt` file uses git config syntax and should be placed in the repository root:

```ini
[gitwt.copy]
    # Individual files to copy
    include = .envrc
    include = .tool-versions
    include = .nvmrc
    include = .editorconfig

[gitwt.exclude]
    # Files to explicitly exclude even if matched by patterns
    exclude = .env.local
    exclude = .env
```

**Parsing**: Use `git config -f .gitwt --get-all gitwt.copy.include` to read all include patterns, and `git config -f .gitwt --get-all gitwt.exclude` for exclusions.

## Functions

### load_gitwt_config

Loads configuration from `.gitwt` file and populates global variables `GITWT_INCLUDES` and `GITWT_EXCLUDES`.

```bash
load_gitwt_config() {
  local git_root="$1"
  local config_file="${git_root}/.gitwt"

  GITWT_INCLUDES=""
  GITWT_EXCLUDES=""

  if [ -f "$config_file" ]; then
    while IFS= read -r pattern; do
      [ -n "$pattern" ] && GITWT_INCLUDES="${GITWT_INCLUDES}${pattern}"$'\n'
    done < <(git config -f "$config_file" --get-all gitwt.copy.include 2>/dev/null || true)

    while IFS= read -r pattern; do
      [ -n "$pattern" ] && GITWT_EXCLUDES="${GITWT_EXCLUDES}${pattern}"$'\n'
    done < <(git config -f "$config_file" --get-all gitwt.exclude 2>/dev/null || true)
  fi
}
```

### is_excluded

Checks if a file should be excluded based on exclusion patterns.

```bash
is_excluded() {
  local file="$1"

  while IFS= read -r pattern; do
    [ -z "$pattern" ] && continue
    case "$file" in
      $pattern) return 0 ;;
    esac
  done <<< "$GITWT_EXCLUDES"

  return 1
}
```

### copy_config_files

Copies config files from source to destination worktree directory.

```bash
copy_config_files() {
  local src_dir="$1"
  local dst_dir="$2"

  [ -z "$GITWT_INCLUDES" ] && return 0

  local copied_count=0
  local skipped_count=0
  local error_count=0

  while IFS= read -r pattern; do
    [ -z "$pattern" ] && continue

    # Validate pattern (no absolute paths or parent traversal)
    case "$pattern" in
      /*|*/../*|../*|*/..|..)
        echo "Warning: Skipping unsafe pattern: $pattern" >&2
        ((error_count++))
        continue
        ;;
    esac

    # Find matching files
    local files_found=0
    for file in "$src_dir"/$pattern 2>/dev/null; do
      [[ "$file" == "$src_dir"/$pattern ]] && [ ! -e "$file" ] && continue
      ((files_found++))

      local rel_path="${file#$src_dir/}"
      if is_excluded "$rel_path"; then
        ((skipped_count++))
        continue
      fi

      [ -d "$file" ] && continue

      local dst_file="$dst_dir/$rel_path"

      if ! mkdir -p "$(dirname "$dst_file")" 2>/dev/null; then
        echo "Warning: Failed to create directory for: $rel_path" >&2
        ((error_count++))
        continue
      fi

      if cp "$file" "$dst_file" 2>/dev/null; then
        ((copied_count++))
      else
        echo "Warning: Failed to copy: $rel_path" >&2
        ((error_count++))
      fi
    done

    if [ "$files_found" -eq 0 ] && ! [[ "$pattern" == *\** ]]; then
      echo "Warning: No files found matching pattern: $pattern" >&2
    fi
  done <<< "$GITWT_INCLUDES"

  if [ "$copied_count" -gt 0 ]; then
    echo "Copied $copied_count config file(s) to worktree"
  fi
  if [ "$skipped_count" -gt 0 ]; then
    echo "Skipped $skipped_count excluded file(s)"
  fi
  if [ "$error_count" -gt 0 ]; then
    echo "Warning: $error_count error(s) occurred while copying config files" >&2
  fi

  return 0
}
```

### suggest_configs

Suggests common config files found in the repository.

```bash
declare -a COMMON_CONFIG_FILES=(
  ".envrc"
  ".tool-versions"
  ".nvmrc"
  ".python-version"
  ".ruby-version"
  ".go-version"
  ".rust-toolchain.toml"
  ".miserc.toml"
  ".mise.toml"
  ".editorconfig"
  ".eslintrc"
  ".prettierrc"
  ".env.example"
  ".dockerignore"
  "Makefile"
)

suggest_configs() {
  local git_root="$1"
  local found_files=()

  for file in "${COMMON_CONFIG_FILES[@]}"; do
    if [ -f "$git_root/$file" ]; then
      found_files+=("$file")
    fi
  done

  if [ ${#found_files[@]} -eq 0 ]; then
    echo "No common config files found in repository."
    echo ""
    echo "Common config files you might want to use:"
    printf "  - %s\n" "${COMMON_CONFIG_FILES[@]}"
  else
    echo "Found ${#found_files[@]} config file(s) in repository:"
    printf "  - %s\n" "${found_files[@]}"
    echo ""

    if [ -f "$git_root/.gitwt" ]; then
      local already_included=""
      while IFS= read -r pattern; do
        [ -z "$pattern" ] && continue
        for file in "${found_files[@]}"; do
          if [[ "$file" == $pattern ]]; then
            already_included="${already_included}${file}"$'\n'
            break
          fi
        done
      done < <(git config -f "$git_root/.gitwt" --get-all gitwt.copy.include 2>/dev/null || true)

      if [ -n "$already_included" ]; then
        echo "Already included in .gitwt:"
        printf "  - %s\n" $already_included
        echo ""

        local not_included=""
        for file in "${found_files[@]}"; do
          local included=false
          while IFS= read -r inc; do
            [ -z "$inc" ] && continue
            [[ "$file" == $inc ]] && { included=true; break; }
          done <<< "$already_included"
          $included || not_included="${not_included}${file}"$'\n'
        done

        if [ -n "$not_included" ]; then
          echo "Not yet included (consider adding):"
          printf "  - %s\n" $not_included
        fi
      fi
    fi

    echo ""
    echo "To include these files in .gitwt, run:"
    echo "  gitwt init"
  fi
}
```

### init_gitwt_config

Creates or updates the `.gitwt` configuration file.

```bash
init_gitwt_config() {
  local git_root="$1"
  local config_file="${git_root}/.gitwt"

  if [ -f "$config_file" ]; then
    echo "Config file already exists: $config_file"
    echo ""
    suggest_configs "$git_root"
    return 0
  fi

  echo "# Git Worktree Config" > "$config_file"
  echo "# Files listed below will be copied to new worktrees" >> "$config_file"
  echo "" >> "$config_file"
  echo "[gitwt.copy]" >> "$config_file"

  local found_any=false
  for file in "${COMMON_CONFIG_FILES[@]}"; do
    if [ -f "$git_root/$file" ]; then
      echo "    include = $file" >> "$config_file"
      found_any=true
    fi
  done

  if ! $found_any; then
    echo "# Uncomment and add files you want to copy:" >> "$config_file"
    echo "#     include = .envrc" >> "$config_file"
    echo "#     include = .tool-versions" >> "$config_file"
  fi

  echo "" >> "$config_file"
  echo "[gitwt.exclude]" >> "$config_file"
  echo "#     exclude = .env.local" >> "$config_file"

  echo "Created .gitwt config file"
  echo ""
  suggest_configs "$git_root"
}
```

## Integration

### Updated add_worktree Function

```bash
add_worktree() {
  local branch_name="$1"
  local worktree_path="$2"

  if ! git show-ref --verify --quiet "refs/heads/$branch_name"; then
    git branch "$branch_name"
  fi

  ensure_directory "$(dirname "$worktree_path")"

  if ! git worktree add "$worktree_path" "$branch_name"; then
    echo "Error: Failed to create worktree"
    exit 1
  fi

  # Load .gitwt configuration
  local git_root=$(get_git_root)
  load_gitwt_config "$git_root"

  # Copy config files if configured
  if [ -n "$GITWT_INCLUDES" ]; then
    copy_config_files "$git_root" "$worktree_path"
  fi

  echo "Worktree created at: $worktree_path"
}
```

### Updated track_worktree Function

```bash
track_worktree() {
  local branch_name="$1"
  local worktree_path="$2"

  if ! git ls-remote --exit-code --heads origin "$branch_name" >/dev/null 2>&1; then
    echo "Error: Remote branch origin/$branch_name does not exist"
    exit 1
  fi

  ensure_directory "$(dirname "$worktree_path")"

  if git show-ref --verify --quiet "refs/heads/$branch_name"; then
    if ! git worktree add "$worktree_path" "$branch_name"; then
      echo "Error: Failed to create worktree"
      exit 1
    fi
  else
    git fetch origin "$branch_name:$branch_name"
    if ! git worktree add "$worktree_path" "$branch_name"; then
      echo "Error: Failed to create worktree"
      exit 1
    fi
  fi

  # Load .gitwt configuration
  local git_root=$(get_git_root)
  load_gitwt_config "$git_root"

  # Copy config files if configured
  if [ -n "$GITWT_INCLUDES" ]; then
    copy_config_files "$git_root" "$worktree_path"
  fi

  echo "Worktree created at: $worktree_path"
}
```

## CLI Interface

### New Actions

- `gitwt init` - Create `.gitwt` config file in repo root with detected config files
- `gitwt suggest` - Show which common config files exist in the repo and which are included in `.gitwt`

### Updated Usage

```bash
usage() {
  echo "Usage: gitwt <action> <branch_name> [worktree_folder]"
  echo "Manage git worktrees with config file copying"
  echo ""
  echo "Actions:"
  echo "  add     Create a new worktree for specified branch"
  echo "  track   Create a new worktree tracking a remote branch"
  echo "  delete  Remove a worktree and its directory"
  echo "  init    Create .gitwt config file in repo root"
  echo "  suggest Show common config files found in this repo"
  echo ""
  echo "Arguments:"
  echo "  branch_name      Name of the git branch (can include prefix, e.g., feature/foo)"
  echo "  worktree_folder  Optional: Custom folder name (defaults to branch name)"
  echo ""
  echo "Config File (.gitwt):"
  echo "  Place in repo root to specify which files to copy to new worktrees"
  echo "  Format: git config syntax with gitwt.copy.include sections"
  echo ""
  echo "Example .gitwt:"
  echo "  [gitwt.copy]"
  echo "      include = .envrc"
  echo "      include = .tool-versions"
  echo "      include = .nvmrc"
  echo ""
  echo "  [gitwt.exclude]"
  echo "      exclude = .env.local"
  echo ""
  echo "Worktree Location:"
  echo "  Worktrees will be created under: $GIT_WORKTREE_FOLDER/<branch_name>"
  echo "  For branches with prefix (e.g., feature/foo), appropriate subdirectories"
  echo "  will be created automatically"
  exit 1
}
```

## Behavior

- **No `.gitwt` file**: No config files are copied (silent)
- **Empty `.gitwt` file**: No config files are copied (silent)
- **With `.gitwt` file**: Copy files listed in `gitwt.copy.include` to new worktrees
- **Pattern matching**: Copy only if file exists in source; silently skip missing files
- **Exclusions**: Files matching `gitwt.exclude` are skipped

## Example Workflow

```bash
# Check what config files exist in repo
gitwt suggest

# Initialize .gitwt with detected files
gitwt init

# Create worktree - config files copied automatically
gitwt add feature/new-feature

# Edit .gitwt to add more files
vim .gitwt

# Create another worktree - includes new config entries
gitwt track remote-branch
```

## Error Handling

- Unsafe patterns (absolute paths, parent traversal): Warning, skip pattern
- Failed directory creation: Warning, skip file
- Failed file copy: Warning, continue with other files
- Pattern matches nothing: Warning (unless wildcard), continue
- Excluded files: Silent skip (counted separately)

## Common Config Files

The following config files are recognized by the `suggest` command:

- `.envrc` - direnv environment configuration
- `.tool-versions` - asdf version manager
- `.nvmrc` - Node Version Manager
- `.python-version` - pyenv
- `.ruby-version` - rbenv
- `.go-version` - Go version
- `.rust-toolchain.toml` - Rust toolchain
- `.miserc.toml` / `.mise.toml` - mise (formerly rtx)
- `.editorconfig` - EditorConfig
- `.eslintrc` - ESLint
- `.prettierrc` - Prettier
- `.env.example` - Environment template
- `.dockerignore` - Docker ignore file
- `Makefile` - Make build configuration
