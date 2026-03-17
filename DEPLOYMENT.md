# RSC Deployment Guide

This repository includes a comprehensive `justfile` for deploying R, Python, and Quarto content to Posit RStudio Connect.

## Quick Start

```bash
# Check if required tools are installed
just check-tools

# View configuration
just config

# Deploy content (auto-detects type)
just deploy content/r-shiny
just deploy content/python-fastapi
just deploy content/quarto-site

# List all deployable content
just list-content
```

## Prerequisites

### Required Tools

- **R** and **Rscript** - For R content deployment
- **uv** - Python package manager (install: `curl -LsSf https://astral.sh/uv/install.sh | sh`)
- **rsconnect R package** - Install with: `just install-rsconnect`

### Optional Tools

- **rig** - R version manager (recommended for managing multiple R versions)
- **quarto** - For Quarto content deployment
- **jq** - JSON processor (helpful for parsing metadata)

## Configuration

Set these environment variables:

```bash
export CONNECT_SERVER_URL="https://connect.example.com"
export CONNECT_API_KEY="your-api-key-here"

# Optional: specify R and Python versions
export R_VERSION="4.5.2"
export PY_VERSION="3.11.3"
```

Or create a `.env` file and source it.

## Supported Content Types

The justfile automatically detects and deploys:

### R Content
- **Shiny Apps** - `app.R`, `ui.R`+`server.R`, or `*-shiny.R` files
- **Plumber APIs** - `plumber.R` files
- **R Markdown** - `*.Rmd` files

### Python Content
- **FastAPI** - Detects `fastapi` imports in `app.py`
- **Shiny for Python** - Detects `shiny` imports
- **Dash** - Detects `dash` imports
- **Streamlit** - Detects `streamlit` imports
- **Jupyter Notebooks** - `*.ipynb` files

### Quarto Content
- **Quarto Sites** - Detects `_quarto.yml` or `*.qmd` files
- **Quarto + Shiny** - Interactive Quarto documents

## Common Commands

### Deployment

```bash
# Auto-detect and deploy
just deploy content/r-shiny

# Specify content type explicitly
just deploy content/python-fastapi python-fastapi

# Type-specific deployment commands
just deploy-r content/r-plumber-api
just deploy-python content/python-dash dash
just deploy-quarto content/quarto-site
```

### Setup Dependencies

```bash
# Setup all dependencies (R packages, Python packages)
just setup content/r-shiny

# Setup only R dependencies
just setup-r content/r-shiny

# Setup only Python dependencies
just setup-python content/python-fastapi
```

### Lock Dependencies

```bash
# Create or update dependency lock files (auto-detects type)
just lock content/r-shiny           # Creates/updates renv.lock
just lock content/python-fastapi    # Creates/updates requirements.txt

# Create/update R lock file
just lock-r content/r-shiny

# Create/update Python lock file
just lock-python content/python-fastapi
```

### Generate Manifests

```bash
# Generate manifest.json (auto-detects type, updates lock file first)
just manifest content/r-shiny
just manifest content/python-fastapi

# Generate manifest for R content
just manifest-r content/r-shiny

# Generate manifest for Python content
just manifest-python content/python-fastapi
```

### Utility Commands

```bash
# Detect content type
just detect content/r-shiny
# Output: r-shiny

# Check tool installation
just check-tools

# View current configuration
just config

# List all deployable content
just list-content

# Install rsconnect R package globally
just install-rsconnect

# Create/update dependency lock files
just lock content/r-shiny
just lock content/python-fastapi

# Show help
just help
```

## How It Works

### Content Type Detection

The justfile detects content types by examining file extensions and library imports:

**Key Principle**: Only file extensions matter (`.R`, `.py`, `.qmd`, `.Rmd`, `.ipynb`), not filenames.

1. **Quarto** (checked first): `_quarto.yml` or `*.qmd` files
2. **R Markdown**: `*.Rmd` files
3. **Jupyter**: `*.ipynb` files
4. **R content**: Examines ALL `.R` files for library imports
   - `library(shiny)` or `require(shiny)` → R Shiny
   - `library(plumber)` or `require(plumber)` → R Plumber
   - Plumber decorators (`#* @get`, `#* @post`, etc.) → R Plumber
   - No recognized framework → R script
5. **Python content**: Examines ALL `.py` files for imports
   - `import fastapi` or `from fastapi import` → FastAPI
   - `import shiny` or `from shiny` → Shiny for Python
   - `import dash` or `from dash import` → Dash
   - `import streamlit` → Streamlit
   - No recognized framework → Python script

### Deployment Process

1. **Detect content type** (if not specified)
2. **Setup dependencies**:
   - For R: Restore renv packages if `renv.lock` exists
   - For Python: Install requirements with uv (ephemeral environment)
3. **Deploy using appropriate tool**:
   - R content: `rsconnect` R package
   - Python content: `rsconnect-python` via `uv tool run` (ephemeral)
   - Quarto: `quarto publish connect`

### Environment Management

- **R**: Uses `rig` to manage R versions (if available), restores packages with `renv`
- **Python**: Uses `uv` for ephemeral environments (no persistent `.venv` created)
- **Quarto**: Handles mixed R/Python dependencies automatically

### Manifest Generation

**Important**: The deployment tools (rsconnect, rsconnect-python, quarto) generate `manifest.json` files during deployment. The justfile does NOT rely on pre-existing manifests for detection or deployment.

## Examples

### Deploy R Shiny App

```bash
just deploy content/r-shiny
```

This will:
1. Detect it as `r-shiny` content
2. Restore R packages from `renv.lock`
3. Deploy using `rsconnect::deployApp()`

### Deploy Python FastAPI

```bash
just deploy content/python-fastapi
```

This will:
1. Detect it as `python-fastapi` content
2. Install Python dependencies with `uv` (ephemeral)
3. Deploy using `uv tool run rsconnect-python deploy fastapi`

### Deploy Quarto Site

```bash
just deploy content/quarto-site
```

This will:
1. Detect it as `quarto` content
2. Setup any R/Python dependencies if needed
3. Deploy using `quarto publish connect`

### Batch Deployment

```bash
# List all content first
just list-content

# Deploy multiple items
just deploy content/r-shiny
just deploy content/python-fastapi
just deploy content/quarto-site
```

### Creating New Content

When creating new content from scratch:

```bash
# 1. Create directory and add your source files
mkdir content/my-new-app
cd content/my-new-app
# ... write your R or Python code ...

# 2. Install packages you need
# For R: install.packages("shiny")
# For Python: uv pip install shiny

# 3. Create dependency lock file
just lock content/my-new-app

# 4. Deploy to Connect
just deploy content/my-new-app
```

### Updating Dependencies

When you add new package dependencies to existing content:

```bash
# 1. Install the new packages in your environment
# For R: install.packages("dplyr")
# For Python: uv pip install pandas

# 2. Update the lock file
just lock content/my-existing-app

# 3. Redeploy with new dependencies
just deploy content/my-existing-app
```

### Generating Manifests Without Deploying

Sometimes you want to generate a `manifest.json` file without deploying (e.g., for validation, CI/CD pre-checks, or testing):

```bash
# Generate manifest (automatically updates lock file first)
just manifest content/my-app

# This is useful for:
# - Validating content structure before deployment
# - Pre-generating manifests in CI/CD pipelines
# - Testing content configuration
```

The manifest command ensures your lock file is up to date, then generates the manifest using:
- **R content**: `rsconnect::writeManifest()`
- **Python content**: `rsconnect write-manifest` (via uv)

**Workflow:**
1. Calls `just lock` to ensure dependencies are locked
2. Generates `manifest.json` with correct metadata
3. Manifest is ready for deployment or validation

## Troubleshooting

### Missing rsconnect R package

```bash
just install-rsconnect
```

### Missing tools

```bash
just check-tools
# Follow installation instructions for missing tools
```

### Content type not detected

```bash
# Check what type is detected
just detect content/my-content

# If unknown, specify type explicitly
just deploy content/my-content r-shiny
```

### Deployment fails

1. Check environment variables are set:
   ```bash
   just config
   ```

2. Verify dependencies are installed:
   ```bash
   just setup content/my-content
   ```

3. Check Connect server connectivity and API key

## Advanced Usage

### Custom R/Python Versions

Set version environment variables before deploying:

```bash
export R_VERSION="4.5.2"
export PY_VERSION="3.11.3"
just deploy content/my-content
```

### Force Update Existing Content

The deployment automatically updates existing content. To force a fresh deployment, you may need to modify the deployment commands in the justfile.

### CI/CD Integration

The justfile can be used in CI/CD pipelines:

```yaml
# Example GitHub Actions workflow
- name: Deploy to Connect
  env:
    CONNECT_SERVER_URL: ${{ secrets.CONNECT_SERVER_URL }}
    CONNECT_API_KEY: ${{ secrets.CONNECT_API_KEY }}
  run: |
    just check-tools
    just deploy content/r-shiny
```

## Project Structure

```
rsc-sample-content/
├── justfile              # Main deployment automation
├── DEPLOYMENT.md         # This file
└── content/                # Deployable content
    ├── r-shiny/
    ├── python-fastapi/
    └── quarto-site/
```

## Additional Resources

- [Just Command Runner](https://github.com/casey/just)
- [Posit Connect Documentation](https://docs.posit.co/connect/)
- [rsconnect R Package](https://github.com/rstudio/rsconnect)
- [rsconnect-python](https://github.com/rstudio/rsconnect-python)
- [Quarto Publishing](https://quarto.org/docs/publishing/rstudio-connect.html)
- [rig - R Installation Manager](https://github.com/r-lib/rig)
- [uv - Python Package Manager](https://github.com/astral-sh/uv)
