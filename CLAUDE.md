# RSC Sample Content Repository

## Project Overview

This repository contains sample R, Python, and Quarto content for deployment to Posit RStudio Connect. It includes a comprehensive deployment automation system using a `justfile` that handles environment setup and deployment for all supported content types.

## Repository Structure

```
rsc-sample-content/
├── justfile              # Main deployment automation
├── DEPLOYMENT.md         # User-facing documentation
├── CLAUDE.md             # This file - Claude context
└── content/              # All deployable content (24+ items)
    ├── r-shiny/          # R Shiny applications
    ├── r-plumber-api/    # R Plumber APIs
    ├── r-rmd/            # R Markdown reports
    ├── python-fastapi/   # Python FastAPI applications
    ├── python-shiny/     # Shiny for Python apps
    ├── python-dash/      # Dash applications
    ├── python-streamlit/ # Streamlit apps
    ├── jupyter-notebook/ # Jupyter notebooks
    ├── quarto-site/      # Quarto websites
    └── ...
```

## Important Context

### Content Organization

- **Single content directory**: All deployable content is in `content/`
- **No off-host directory**: Previously had `local/` and `off-host/` directories, now consolidated to just `content/`
- **Mixed content types**: R, Python, and Quarto content coexist in the same directory

### Deployment Philosophy

**Key Principle**: Deployment tools generate `manifest.json` files during deployment. The justfile does NOT rely on pre-existing manifests for detection or deployment.

**Content Type Detection**: File-pattern based detection (checks for `app.R`, `plumber.R`, `app.py` with imports, `*.qmd`, etc.)

**Environment Management**:
- **R**: Uses `rig` for version management (optional), `renv` for package management, global `rsconnect` package installation
- **Python**: Uses `uv` for ephemeral environments (NO persistent `.venv` directories), `rsconnect-python` via `uv tool run`
- **Quarto**: Uses `quarto publish connect` for deployment

### Justfile Architecture

The justfile is organized into sections:

1. **Environment Variables**
   - `CONNECT_SERVER_URL`: Connect server URL
   - `CONNECT_API_KEY`: API key for authentication
   - `R_VERSION`: Default R version (4.5.2)
   - `PY_VERSION`: Default Python version (3.11.3)

2. **Core Recipes**
   - `help`, `config`, `check-tools`: Utilities
   - `detect`: Content type detection
   - `setup`, `setup-r`, `setup-python`: Environment setup
   - `lock`, `lock-r`, `lock-python`: Dependency lock file management
   - `manifest`, `manifest-r`, `manifest-python`: Manifest generation
   - `list-content`: List all deployable content
   - `install-rsconnect`: One-time R package installation

3. **Helper Recipes** (prefixed with `_`, hidden from `just --list`)
   - `_python-deploy-type`: Determine rsconnect deployment type for Python
   - `_python-entrypoint`: Determine entrypoint for Python apps
   - `_python-main-file`: Find main Python/notebook file
   - `_r-app-mode`: Determine app mode for R content

4. **Deployment Recipes**
   - `deploy`: Main entry point (auto-detects type)
   - `deploy-r`: R-specific deployment
   - `deploy-python`: Python-specific deployment
   - `deploy-quarto`: Quarto-specific deployment

**Design Note**: Helper recipes eliminate code duplication between deployment and manifest generation by providing shared logic for determining content types, entrypoints, and configuration.

## Content Type Detection Logic

**Priority Order** (implemented in `detect` recipe):

**Important**: Detection is based on file extensions and library imports, NOT filenames. Only the file extension matters (`.R`, `.py`, `.qmd`, `.Rmd`, `.ipynb`).

1. **Quarto** (checked first as it can contain R/Python code)
   - `_quarto.yml` file OR `*.qmd` files → `quarto`

2. **R Markdown**
   - `*.Rmd` files → `r-rmd`

3. **Jupyter Notebooks**
   - `*.ipynb` files → `jupyter-notebook`

4. **R Content** (examines ALL `.R` files, checks library imports)
   - ANY `.R` file with `library(shiny)` or `require(shiny)` → `r-shiny`
   - ANY `.R` file with `library(plumber)` or `require(plumber)` → `r-plumber`
   - ANY `.R` file with Plumber decorators (`#* @api`, `#* @get`, `#* @post`, etc.) → `r-plumber`
   - Has `.R` files but no recognized imports → `r-script`

5. **Python Content** (examines ALL `.py` files, checks imports)
   - ANY `.py` file with `import fastapi` or `from fastapi import` or `fastapitableau` → `python-fastapi`
   - ANY `.py` file with `import shiny` or `from shiny` → `python-shiny`
   - ANY `.py` file with `import dash` or `from dash import` → `python-dash`
   - ANY `.py` file with `import streamlit` → `python-streamlit`
   - Has `.py` files but no recognized imports → `python-script`

6. **Fallback**
   - `renv.lock` exists → `r-unknown`
   - `requirements.txt` exists → `python-unknown`
   - Otherwise → `unknown` (error)

**Key Insight**: The detection concatenates ALL source files of the appropriate extension and searches for library imports. This means filename conventions (like `app.R`, `plumber.R`, `app.py`) are not significant - only the imports matter.

## Deployment Workflow

### Standard Deployment Command

```bash
just deploy content/r-shiny
```

**Steps executed**:
1. Convert path to absolute path
2. Auto-detect content type (or use specified type)
3. Validate environment variables (`CONNECT_SERVER_URL`, `CONNECT_API_KEY`)
4. Setup dependencies via `just setup`
5. Deploy using tool-specific command:
   - **R**: `Rscript -e 'rsconnect::deployApp(...)'`
   - **Python**: `uv tool run --with rsconnect-python rsconnect deploy <type>`
   - **Quarto**: `quarto publish connect`

### Environment Setup

**R Setup** (`setup-r` recipe):
- Extract R version from `renv.lock` (or use `R_VERSION` env var)
- Install R version with `rig` if needed (optional)
- Restore renv packages: `Rscript -e 'renv::restore()'`

**Python Setup** (`setup-python` recipe):
- Use `PY_VERSION` environment variable
- Install dependencies: `uv pip install --python <version> -r requirements.txt`
- No persistent `.venv` created (ephemeral environments)

**Quarto Setup**:
- Auto-detects if R and/or Python dependencies exist
- Calls `setup-r` and/or `setup-python` as needed

## Common Patterns

### Content Directory Naming

- `r-*` prefix: R content (e.g., `r-shiny`, `r-plumber-api`)
- `python-*` prefix: Python content (e.g., `python-fastapi`, `python-dash`)
- `quarto-*` prefix: Quarto content (e.g., `quarto-site`, `quarto-shiny`)
- `reticulated-*` prefix: Mixed R/Python content

### Dependency Files

- **R**: `renv.lock`, `.Rprofile`, `renv/` directory
- **Python**: `requirements.txt`
- **Quarto**: `_quarto.yml`, `*.qmd` files

### Deployment-Generated Files

- `manifest.json`: Generated by deployment tools in each content directory
- `rsconnect-python/`: Created by rsconnect-python (contains deployment metadata)
- `rsconnect/`: Created by rsconnect R package (contains deployment metadata)

## Modification Guidelines

### Adding New Content Types

To add support for a new content type:

1. **Update detection logic** in `detect` recipe:
   ```bash
   elif [[ -f "$path/new-file-pattern" ]]; then
       echo "new-content-type"
   ```

2. **Add deployment case** in `deploy` recipe:
   ```bash
   new-content-type)
       # Deployment command
       ;;
   ```

3. **Create type-specific deploy recipe** (optional):
   ```bash
   @deploy-newtype PATH:
       # Implementation
   ```

### Modifying Deployment Commands

**Important**: Deployment commands must:
- Use `$CONNECT_SERVER_URL` and `$CONNECT_API_KEY` environment variables
- Generate `manifest.json` during deployment
- Support updating existing deployments (not just creating new ones)
- Handle absolute paths (use `cd` to change to content directory if needed)

**DRY Principle**: The justfile uses helper recipes (prefixed with `_`) to eliminate duplication:
- If you need to add logic that determines deployment types, entrypoints, or configuration, consider creating a helper recipe
- Both `deploy-python` and `manifest-python` use the same helpers (`_python-deploy-type`, `_python-entrypoint`, `_python-main-file`)
- This ensures consistency and reduces maintenance burden when deployment logic changes
- Helper recipes are hidden from `just --list` by convention (underscore prefix)

### Path Handling

**Critical**: Always convert relative paths to absolute paths:
```bash
if [[ "$path" != /* ]]; then
    path="$(pwd)/$path"
fi
```

This is necessary because bash recipe invocations reset the working directory.

## Tool Requirements

### Required Tools

- **R** and **Rscript**: For R content deployment
- **uv**: Python package manager (ephemeral environments)
- **rsconnect R package**: Must be installed globally (one-time setup)

### Optional Tools

- **rig**: R version manager (recommended but not required)
- **quarto**: Required only for Quarto content deployment
- **jq**: JSON processor (helpful for parsing `renv.lock` and other JSON files)

### Tool Installation Verification

Use `just check-tools` to verify all tools are installed. This recipe:
- Checks for each required tool
- Displays version information
- Provides installation instructions for missing tools
- Verifies rsconnect R package is installed

## Common Issues and Solutions

### Content Type Detection Issues

**Problem**: Content not detected correctly
**Solution**: Check file patterns in the content directory. The detection logic is strict:
- R Shiny requires `app.R` OR `ui.R`+`server.R` OR `*-shiny.R`
- Python requires `app.py` with recognized imports
- Quarto requires `_quarto.yml` OR `*.qmd` files

### Deployment Failures

**Problem**: rsconnect R package not found
**Solution**: Run `just install-rsconnect` to install globally

**Problem**: Environment variables not set
**Solution**: Export `CONNECT_SERVER_URL` and `CONNECT_API_KEY` before deploying

**Problem**: Dependencies not installed
**Solution**: Run `just setup content/<name>` before deploying

## Testing New Changes

When modifying the justfile:

1. **Test detection**: `just detect content/<name>`
2. **Test setup**: `just setup content/<name>`
3. **Verify tools**: `just check-tools`
4. **List content**: `just list-content` (should show your content)
5. **Dry-run validation**: Check syntax with `just --list`

## Environment Variables Reference

```bash
# Required for deployment
export CONNECT_SERVER_URL="https://connect.example.com"
export CONNECT_API_KEY="your-api-key"

# Optional version overrides
export R_VERSION="4.5.2"
export PY_VERSION="3.11.3"
```

## Recipe Reference

### User-Facing Recipes

- `just help` - Show detailed usage information
- `just config` - Display current configuration
- `just check-tools` - Verify tool installation
- `just detect PATH` - Auto-detect content type
- `just setup PATH` - Install dependencies
- `just deploy PATH [TYPE]` - Deploy content (main command)
- `just list-content` - List all deployable content
- `just install-rsconnect` - Install rsconnect R package
- `just lock PATH` - Create/update dependency lock files
- `just manifest PATH` - Generate manifest.json (requires lock file)

### Type-Specific Recipes

- `just deploy-r PATH` - Deploy R content
- `just deploy-python PATH TYPE` - Deploy Python content (requires type: fastapi, shiny, dash, streamlit, notebook)
- `just deploy-quarto PATH` - Deploy Quarto content
- `just setup-r PATH` - Setup R environment
- `just setup-python PATH` - Setup Python environment
- `just lock-r PATH` - Create/update renv.lock
- `just lock-python PATH` - Create/update requirements.txt
- `just manifest-r PATH` - Generate manifest.json for R content
- `just manifest-python PATH` - Generate manifest.json for Python content

## Dependency Lock File Management

### Creating/Updating Lock Files

**R Content (renv.lock):**
```bash
just lock-r content/r-shiny
```
- If `renv.lock` exists: runs `renv::snapshot()` to update
- If no `renv.lock`: runs `renv::init()` to initialize renv project
- Captures all installed R packages with exact versions

**Python Content (requirements.txt):**
```bash
just lock-python content/python-fastapi
```
- If `requirements.txt` exists: runs `uv pip compile` to lock versions
- If no `requirements.txt`: runs `uv pip freeze` to capture current environment
- Generates pinned versions for reproducible deployments

**Auto-detect Type:**
```bash
just lock content/r-shiny          # Detects R, creates renv.lock
just lock content/python-fastapi   # Detects Python, creates requirements.txt
```

### Workflow for New Content

1. **Create content**: Add your R/Python source files
2. **Install dependencies**: Manually install packages you need
3. **Lock dependencies**: `just lock content/my-content`
4. **Deploy**: `just deploy content/my-content`

### Workflow for Updating Dependencies

1. **Install new packages**: Add packages to your R/Python environment
2. **Update lock file**: `just lock content/my-content`
3. **Test locally**: Verify everything works
4. **Deploy**: `just deploy content/my-content`

## Manifest Generation

### Creating manifest.json

The `manifest` command generates a `manifest.json` file for content without deploying it. This is useful for:
- Validating content structure before deployment
- Pre-generating manifests for CI/CD pipelines
- Testing content configuration

**Generate manifest (auto-detects type):**
```bash
just manifest content/r-shiny
just manifest content/python-fastapi
```

**Workflow:**
1. First ensures lock file is up to date (calls `just lock`)
2. Then generates `manifest.json` using appropriate tool:
   - **R**: Uses `rsconnect::writeManifest()`
   - **Python**: Uses `rsconnect write-manifest` via uv

**Type-specific commands:**
```bash
just manifest-r content/r-shiny          # Generate for R content
just manifest-python content/python-fastapi  # Generate for Python content
```

**Note**: The manifest command always updates the lock file first to ensure the manifest reflects current dependencies.

## Best Practices

1. **Always use relative paths from repository root**: `content/r-shiny` not `./content/r-shiny`
2. **Let detection work**: Don't specify type unless detection fails
3. **Lock dependencies**: Create lock files before first deployment
4. **Setup before deploy**: Run `just setup` if dependencies change
5. **Use check-tools**: Verify environment before troubleshooting
6. **Read deployment output**: Tool-specific errors are displayed inline

## Future Considerations

**Not Currently Implemented** (potential enhancements):

- Batch deployment (`deploy-all` recipe)
- Dry-run mode
- Content validation beyond type detection
- Deployment rollback support
- CI/CD-specific recipes
- Content promotion between environments
