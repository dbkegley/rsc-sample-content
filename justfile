# Reusable Justfile for deploying R, Python, and Quarto content to Posit RStudio Connect
# Uses rig for R version management, uv for Python, and tool-specific deployment commands
# ============================================================================
# Environment Variables
# ============================================================================

export CONNECT_API_KEY := env("CONNECT_API_KEY", "21232f297a57a5a743894a0e4a801fc3")
export CONNECT_SERVER_URL := env("CONNECT_SERVER_URL", "http://localhost:3939")
export R_VERSION := env("R_VERSION", "4.5.2")
export PY_VERSION := env("PY_VERSION", "3.11.3")

# ============================================================================
# Default Recipe - Show Help
# ============================================================================

# Show available commands and usage
@default:
    just --list

# ============================================================================
# Core Recipes
# ============================================================================

# Show detailed help and usage examples
@help:
    echo "Posit RStudio Connect Deployment Tool"
    echo "======================================"
    echo ""
    echo "Configuration (set via environment variables):"
    echo "  CONNECT_SERVER_URL  : {{ CONNECT_SERVER_URL }}"
    echo "  CONNECT_API_KEY     : [set]"
    echo "  R_VERSION           : {{ R_VERSION }}"
    echo "  PY_VERSION          : {{ PY_VERSION }}"
    echo ""
    echo "Common Commands:"
    echo "  just help                     - Show this help message"
    echo "  just check-tools              - Verify required tools are installed"
    echo "  just install-rsconnect        - Install rsconnect R package globally"
    echo "  just detect PATH              - Detect content type in directory"
    echo "  just setup PATH               - Install dependencies for content"
    echo "  just deploy PATH [TYPE]       - Deploy content (auto-detects type)"
    echo "  just list-content             - List all deployable content"
    echo "  just lock PATH                - Create/update dependency lock files"
    echo "  just manifest PATH            - Generate manifest.json (requires lock file)"
    echo ""
    echo "Examples:"
    echo "  just deploy content/r-shiny"
    echo "  just deploy content/python-fastapi"
    echo "  just deploy content/quarto-site"
    echo ""
    echo "Type-Specific Commands:"
    echo "  just deploy-r PATH            - Deploy R content (Shiny, Plumber, RMD)"
    echo "  just deploy-python PATH TYPE  - Deploy Python content (fastapi, shiny, dash, etc.)"
    echo "  just deploy-quarto PATH       - Deploy Quarto content"

# Display current configuration
@config:
    #!/usr/bin/env bash
    echo "Connect Configuration:"
    echo "====================="
    echo "Server URL: {{ CONNECT_SERVER_URL }}"
    if [ -n "$CONNECT_API_KEY" ]; then
        echo "API Key: [set - ${CONNECT_API_KEY:0:8}...]"
    else
        echo "API Key: [not set]"
    fi
    echo "R Version: {{ R_VERSION }}"
    echo "Python Version: {{ PY_VERSION }}"

# Check if required tools are installed
@check-tools:
    #!/usr/bin/env bash
    set -euo pipefail

    echo "Checking required tools..."
    echo ""

    all_found=true

    # Check basic tools
    if command -v R &>/dev/null; then
        echo "✓ R found: $(R --version | head -1)"
    else
        echo "✗ R not found - Install from https://www.r-project.org/"
        all_found=false
    fi

    if command -v Rscript &>/dev/null; then
        echo "✓ Rscript found"
    else
        echo "✗ Rscript not found"
        all_found=false
    fi

    if command -v rig &>/dev/null; then
        echo "✓ rig found: $(rig --version 2>&1 | head -1 || echo 'version unknown')"
    else
        echo "⚠ rig not found (optional) - Install from https://github.com/r-lib/rig"
    fi

    if command -v uv &>/dev/null; then
        echo "✓ uv found: $(uv --version)"
    else
        echo "✗ uv not found - Install: curl -LsSf https://astral.sh/uv/install.sh | sh"
        all_found=false
    fi

    if command -v quarto &>/dev/null; then
        echo "✓ quarto found: $(quarto --version)"
    else
        echo "⚠ quarto not found (optional) - Install from https://quarto.org/"
    fi

    if command -v jq &>/dev/null; then
        echo "✓ jq found: $(jq --version)"
    else
        echo "⚠ jq not found (optional) - Install: apt/brew install jq"
    fi

    # Check rsconnect R package
    echo ""
    if Rscript -e 'packageVersion("rsconnect")' &>/dev/null; then
        version=$(Rscript -e 'cat(as.character(packageVersion("rsconnect")))' 2>/dev/null)
        echo "✓ rsconnect R package found: v$version"
    else
        echo "✗ rsconnect R package not found - Run: just install-rsconnect"
        all_found=false
    fi

    echo ""
    if [ "$all_found" = true ]; then
        echo "All required tools are installed!"
    else
        echo "Some required tools are missing. Please install them."
        exit 1
    fi

# Install rsconnect R package globally
@install-rsconnect:
    #!/usr/bin/env bash
    set -euo pipefail

    echo "Installing rsconnect R package globally..."
    Rscript -e 'install.packages("rsconnect", repos="https://cloud.r-project.org")'

    echo ""
    echo "Verifying installation..."
    version=$(Rscript -e 'cat(as.character(packageVersion("rsconnect")))' 2>/dev/null)
    echo "✓ rsconnect v$version installed successfully"

# Detect content type in a directory
@detect PATH:
    #!/usr/bin/env bash
    set -euo pipefail

    path="{{ PATH }}"

    # Convert to absolute path
    if [[ "$path" != /* ]]; then
        path="$(pwd)/$path"
    fi

    if [ ! -d "$path" ]; then
        echo "Error: Directory not found: $path"
        exit 1
    fi

    # Check Quarto first (can contain R/Python)
    if [[ -f "$path/_quarto.yml" ]] || ls "$path"/*.qmd &>/dev/null 2>&1; then
        echo "quarto"
        exit 0
    fi

    # Check for R Markdown
    if ls "$path"/*.Rmd &>/dev/null 2>&1; then
        echo "r-rmd"
        exit 0
    fi

    # Check for Jupyter Notebook
    if ls "$path"/*.ipynb &>/dev/null 2>&1; then
        echo "jupyter-notebook"
        exit 0
    fi

    # Check R content by examining library imports and patterns in any .R files
    if ls "$path"/*.R &>/dev/null 2>&1; then
        # Concatenate all .R files and check for library imports and patterns
        r_content=$(cat "$path"/*.R 2>/dev/null)

        if echo "$r_content" | grep -q "library(shiny)\|library(\"shiny\")\|library('shiny')\|require(shiny)\|require(\"shiny\")\|require('shiny')"; then
            echo "r-shiny"
            exit 0
        elif echo "$r_content" | grep -q "library(plumber)\|library(\"plumber\")\|library('plumber')\|require(plumber)\|require(\"plumber\")\|require('plumber')"; then
            echo "r-plumber"
            exit 0
        # Check for Plumber API decorators (e.g., #* @api, #* @get, #* @post)
        elif echo "$r_content" | grep -q "#\*[[:space:]]*@\(api\|get\|post\|put\|delete\|patch\)"; then
            echo "r-plumber"
            exit 0
        else
            # Has .R files but no recognized framework
            echo "r-script"
            exit 0
        fi
    fi

    # Check Python content by examining imports in any .py files
    if ls "$path"/*.py &>/dev/null 2>&1; then
        # Concatenate all .py files and check for imports
        py_content=$(cat "$path"/*.py 2>/dev/null)

        if echo "$py_content" | grep -q "from fastapi import\|import fastapi\|fastapitableau"; then
            echo "python-fastapi"
        elif echo "$py_content" | grep -q "from shiny\|import shiny"; then
            echo "python-shiny"
        elif echo "$py_content" | grep -q "from dash import\|import dash"; then
            echo "python-dash"
        elif echo "$py_content" | grep -q "import streamlit"; then
            echo "python-streamlit"
        else
            # Has .py files but no recognized framework
            echo "python-script"
        fi
        exit 0
    fi

    # Fallback detection
    if [[ -f "$path/renv.lock" ]]; then
        echo "r-unknown"
        exit 0
    elif [[ -f "$path/requirements.txt" ]]; then
        echo "python-unknown"
        exit 0
    fi

    echo "unknown"
    exit 1

# Setup dependencies for content
@setup PATH:
    #!/usr/bin/env bash
    set -euo pipefail

    path="{{ PATH }}"

    # Convert to absolute path
    if [[ "$path" != /* ]]; then
        path="$(pwd)/$path"
    fi

    # Detect content type
    content_type=$(just detect "$path")

    echo "Setting up dependencies for $content_type content at: $path"

    case "$content_type" in
        r-*|quarto)
            # Setup R environment if renv.lock exists
            if [[ -f "$path/renv.lock" ]]; then
                just setup-r "$path"
            fi

            # Setup Python environment if requirements.txt exists (for quarto with Python)
            if [[ -f "$path/requirements.txt" ]] && [[ "$content_type" == "quarto" ]]; then
                just setup-python "$path"
            fi
            ;;
        python-*|jupyter-notebook)
            if [[ -f "$path/requirements.txt" ]]; then
                just setup-python "$path"
            else
                echo "No requirements.txt found, skipping Python setup"
            fi
            ;;
        *)
            echo "Warning: Unknown content type, skipping setup"
            ;;
    esac

# Setup R environment and restore packages
@setup-r PATH:
    #!/usr/bin/env bash
    set -euo pipefail

    path="{{ PATH }}"

    # Convert to absolute path
    if [[ "$path" != /* ]]; then
        path="$(pwd)/$path"
    fi

    echo "Setting up R environment..."

    # Extract R version from renv.lock if exists
    if [[ -f "$path/renv.lock" ]] && command -v jq &>/dev/null; then
        r_version=$(jq -r '.R.Version' "$path/renv.lock" 2>/dev/null || echo "{{ R_VERSION }}")
    else
        r_version="{{ R_VERSION }}"
    fi

    echo "R version required: $r_version"

    # Check if rig is available to manage R versions
    if command -v rig &>/dev/null; then
        if ! rig list | grep -q "$r_version"; then
            echo "Installing R $r_version with rig..."
            rig add "$r_version"
        fi
    fi

    # Restore renv packages if renv.lock exists
    if [[ -f "$path/renv.lock" ]]; then
        echo "Restoring R packages with renv..."
        cd "$path"
        Rscript -e 'renv::restore()'
    else
        echo "No renv.lock found, skipping package restoration"
    fi

# Setup Python environment with uv (ephemeral)
@setup-python PATH:
    #!/usr/bin/env bash
    set -euo pipefail

    path="{{ PATH }}"

    # Convert to absolute path
    if [[ "$path" != /* ]]; then
        path="$(pwd)/$path"
    fi

    echo "Setting up Python environment..."

    if [[ ! -f "$path/requirements.txt" ]]; then
        echo "No requirements.txt found, skipping Python setup"
        exit 0
    fi

    py_version="{{ PY_VERSION }}"
    echo "Python version: $py_version"

    # Install dependencies with uv (ephemeral environment)
    echo "Installing Python dependencies with uv..."
    cd "$path"
    uv pip install --python "$py_version" -r requirements.txt

    echo "Python dependencies installed"

# Create or update dependency lock files for content
@lock PATH:
    #!/usr/bin/env bash
    set -euo pipefail

    path="{{ PATH }}"

    # Convert to absolute path
    if [[ "$path" != /* ]]; then
        path="$(pwd)/$path"
    fi

    # Detect content type
    content_type=$(just detect "$path")

    echo "Creating/updating lock files for $content_type content at: $path"

    case "$content_type" in
        r-*|quarto)
            just lock-r "$path"
            ;;
        python-*|jupyter-notebook)
            just lock-python "$path"
            ;;
        *)
            echo "Warning: Unknown content type, cannot create lock files"
            exit 1
            ;;
    esac

# Create or update renv.lock for R content
@lock-r PATH:
    #!/usr/bin/env bash
    set -euo pipefail

    path="{{ PATH }}"

    # Convert to absolute path
    if [[ "$path" != /* ]]; then
        path="$(pwd)/$path"
    fi

    echo "Creating/updating renv.lock for R content..."

    cd "$path"

    if [[ -f "renv.lock" ]]; then
        echo "Updating existing renv.lock..."
        Rscript -e 'renv::snapshot()'
    else
        echo "Initializing new renv project..."
        Rscript -e 'renv::init()'
    fi

    echo "✓ renv.lock updated successfully"

# Create or update requirements.txt for Python content
@lock-python PATH:
    #!/usr/bin/env bash
    set -euo pipefail

    path="{{ PATH }}"

    # Convert to absolute path
    if [[ "$path" != /* ]]; then
        path="$(pwd)/$path"
    fi

    echo "Creating/updating requirements.txt for Python content..."

    cd "$path"

    py_version="{{ PY_VERSION }}"

    if [[ -f "requirements.txt" ]]; then
        echo "Updating existing requirements.txt..."
        # Compile requirements to lock versions
        uv pip compile requirements.txt --python "$py_version" --output-file requirements.txt.lock
        mv requirements.txt.lock requirements.txt
    else
        echo "Creating new requirements.txt from installed packages..."
        # Create requirements.txt from current environment
        uv pip freeze --python "$py_version" > requirements.txt
    fi

    echo "✓ requirements.txt updated successfully"

# Generate or update manifest.json for content (requires lock file)
@manifest PATH:
    #!/usr/bin/env bash
    set -euo pipefail

    path="{{ PATH }}"

    # Convert to absolute path
    if [[ "$path" != /* ]]; then
        path="$(pwd)/$path"
    fi

    # Detect content type
    content_type=$(just detect "$path")

    echo "Generating manifest.json for $content_type content at: $path"

    # First, ensure lock files exist
    just lock "$path"

    case "$content_type" in
        r-*|quarto)
            just manifest-r "$path"
            ;;
        python-*|jupyter-notebook)
            just manifest-python "$path"
            ;;
        *)
            echo "Warning: Unknown content type, cannot create manifest"
            exit 1
            ;;
    esac

# Generate manifest.json for R content
@manifest-r PATH:
    #!/usr/bin/env bash
    set -euo pipefail

    path="{{ PATH }}"

    # Convert to absolute path
    if [[ "$path" != /* ]]; then
        path="$(pwd)/$path"
    fi

    echo "Generating manifest.json for R content..."

    app_mode=$(just _r-app-mode "$path")
    echo "App mode: $app_mode"

    cd "$path"

    # Use rsconnect::writeManifest() to generate manifest
    Rscript -e "
    library(rsconnect)
    writeManifest(appMode = '$app_mode')
    "

    echo "✓ manifest.json created successfully"

# Generate manifest.json for Python content
@manifest-python PATH:
    #!/usr/bin/env bash
    set -euo pipefail

    path="{{ PATH }}"

    # Convert to absolute path
    if [[ "$path" != /* ]]; then
        path="$(pwd)/$path"
    fi

    echo "Generating manifest.json for Python content..."

    deploy_type=$(just _python-deploy-type "$path")
    entrypoint=$(just _python-entrypoint "$path")
    main_file=$(just _python-main-file "$path")

    echo "Manifest type: $deploy_type"

    cd "$path"

    # Generate manifest based on type
    case "$deploy_type" in
        fastapi|dash|api)
            echo "Creating manifest for $deploy_type application..."
            uv tool run --with rsconnect-python rsconnect write-manifest "$deploy_type" \
              --entrypoint "$entrypoint" \
              .
            ;;
        shiny)
            echo "Creating manifest for Shiny for Python application..."
            uv tool run --with rsconnect-python rsconnect write-manifest shiny .
            ;;
        streamlit)
            echo "Creating manifest for Streamlit application..."
            uv tool run --with rsconnect-python rsconnect write-manifest api \
              --entrypoint "$entrypoint" \
              .
            ;;
        notebook)
            echo "Creating manifest for Jupyter Notebook..."
            uv tool run --with rsconnect-python rsconnect write-manifest notebook \
              "$main_file"
            ;;
        *)
            echo "Error: Unsupported Python content type: $deploy_type"
            exit 1
            ;;
    esac

    echo "✓ manifest.json created successfully"

# List all deployable content in the repository
@list-content:
    #!/usr/bin/env bash
    set -euo pipefail

    echo "Deployable Content in Repository:"
    echo "=================================="
    echo ""

    # Find content in content/ directory
    if [ -d "content" ]; then
        echo "[content/]"

        # Find directories with deployable content
        for content_dir in content/*; do
            if [ ! -d "$content_dir" ]; then
                continue
            fi

            # Try to detect content type
            content_type=$(just detect "$content_dir" 2>/dev/null || echo "unknown")

            if [ "$content_type" != "unknown" ]; then
                printf "  %-40s %s\n" "$(basename "$content_dir")" "($content_type)"
            fi
        done

        echo ""
    else
        echo "Error: content/ directory not found"
        exit 1
    fi

# Deploy content to Connect (auto-detects type if not specified)
@deploy PATH TYPE="auto":
    #!/usr/bin/env bash
    set -euo pipefail

    path="{{ PATH }}"
    specified_type="{{ TYPE }}"

    # Convert to absolute path
    if [[ "$path" != /* ]]; then
        path="$(pwd)/$path"
    fi

    content_name="$(basename "$path")"

    # Detect content type if not specified
    if [[ "$specified_type" == "auto" ]]; then
        content_type=$(just detect "$path")
        echo "Auto-detected content type: $content_type"
    else
        content_type="$specified_type"
        echo "Using specified content type: $content_type"
    fi

    # Validate environment variables
    if [ -z "$CONNECT_SERVER_URL" ] || [ -z "$CONNECT_API_KEY" ]; then
        echo "Error: CONNECT_SERVER_URL and CONNECT_API_KEY must be set"
        exit 1
    fi

    # Setup dependencies first
    echo "Setting up dependencies..."
    just setup "$path"

    echo ""
    echo "Deploying $content_type content: $content_name"
    echo "From: $path"
    echo "To: $CONNECT_SERVER_URL"
    echo ""

    # Deploy based on content type
    case "$content_type" in
        r-shiny|r-plumber|r-rmd|r-script)
            just deploy-r "$path"
            ;;
        python-*|jupyter-notebook)
            deploy_type=$(just _python-deploy-type "$path")
            just deploy-python "$path" "$deploy_type"
            ;;
        quarto)
            just deploy-quarto "$path"
            ;;
        *)
            echo "Error: Unknown or unsupported content type: $content_type"
            exit 1
            ;;
    esac

    echo ""
    echo "✓ Deployment complete!"

# ============================================================================
# Helper Recipes for Type Detection and Configuration
# ============================================================================

# Get Python rsconnect deployment type for a path
@_python-deploy-type PATH:
    #!/usr/bin/env bash
    set -euo pipefail

    path="{{ PATH }}"
    if [[ "$path" != /* ]]; then
        path="$(pwd)/$path"
    fi

    content_type=$(just detect "$path")

    case "$content_type" in
        python-fastapi) echo "fastapi" ;;
        python-shiny) echo "shiny" ;;
        python-dash) echo "dash" ;;
        python-streamlit) echo "streamlit" ;;
        jupyter-notebook) echo "notebook" ;;
        python-script) echo "api" ;;
        *) echo "unknown" ;;
    esac

# Get Python entrypoint for a path
@_python-entrypoint PATH:
    #!/usr/bin/env bash
    set -euo pipefail

    path="{{ PATH }}"
    if [[ "$path" != /* ]]; then
        path="$(pwd)/$path"
    fi

    cd "$path"

    # Determine entrypoint based on files present
    if [[ -f "app.py" ]]; then
        echo "app:app"
    elif [[ -f "main.py" ]]; then
        echo "main:app"
    elif [[ -f "api.py" ]]; then
        echo "api:app"
    else
        # Use first .py file found
        main_file=$(ls *.py 2>/dev/null | head -1 | sed 's/\.py$//' || echo "app")
        echo "$main_file:app"
    fi

# Get Python main file for a path
@_python-main-file PATH:
    #!/usr/bin/env bash
    set -euo pipefail

    path="{{ PATH }}"
    if [[ "$path" != /* ]]; then
        path="$(pwd)/$path"
    fi

    cd "$path"

    # For streamlit and notebooks
    if ls *.ipynb &>/dev/null 2>&1; then
        ls *.ipynb | head -1
    elif ls *.py &>/dev/null 2>&1; then
        ls *.py | head -1
    else
        echo "app.py"
    fi

# Get R app mode for manifest generation
@_r-app-mode PATH:
    #!/usr/bin/env bash
    set -euo pipefail

    path="{{ PATH }}"
    if [[ "$path" != /* ]]; then
        path="$(pwd)/$path"
    fi

    content_type=$(just detect "$path")

    case "$content_type" in
        r-shiny) echo "shiny" ;;
        r-plumber) echo "api" ;;
        r-rmd) echo "rmd-static" ;;
        quarto) echo "quarto-static" ;;
        *) echo "shiny" ;;  # Default
    esac

# ============================================================================
# Type-Specific Deployment Recipes
# ============================================================================

# Deploy R content (Shiny, Plumber, RMD) using rsconnect R package
@deploy-r PATH:
    #!/usr/bin/env bash
    set -euo pipefail

    path="{{ PATH }}"

    # Convert to absolute path
    if [[ "$path" != /* ]]; then
        path="$(pwd)/$path"
    fi

    content_name="$(basename "$path")"

    echo "Deploying R content with rsconnect R package..."

    # Check if rsconnect is installed
    if ! Rscript -e 'packageVersion("rsconnect")' &>/dev/null; then
        echo "Error: rsconnect R package not installed"
        echo "Run: just install-rsconnect"
        exit 1
    fi

    # Deploy using rsconnect R package
    Rscript -e "
    library(rsconnect)

    # Parse server URL to get host and port
    server_url <- Sys.getenv('CONNECT_SERVER_URL')
    api_key <- Sys.getenv('CONNECT_API_KEY')

    # Set up account
    setAccountInfo(
      name = 'rsconnect',
      server = server_url,
      apiKey = api_key
    )

    # Deploy
    deployApp(
      appDir = '$path',
      appTitle = '$content_name',
      account = 'rsconnect',
      server = server_url,
      forceUpdate = TRUE
    )
    "

# Deploy Python content using rsconnect-python via uv
@deploy-python PATH TYPE:
    #!/usr/bin/env bash
    set -euo pipefail

    path="{{ PATH }}"
    deploy_type="{{ TYPE }}"

    # Convert to absolute path
    if [[ "$path" != /* ]]; then
        path="$(pwd)/$path"
    fi

    content_name="$(basename "$path")"
    entrypoint=$(just _python-entrypoint "$path")
    main_file=$(just _python-main-file "$path")

    echo "Deploying Python content with rsconnect-python (via uv)..."
    echo "Deploy type: $deploy_type"

    cd "$path"

    # Deploy based on type using uv tool run for ephemeral rsconnect-python
    case "$deploy_type" in
        fastapi|dash|api)
            echo "Deploying $deploy_type application..."
            uv tool run --with rsconnect-python rsconnect deploy "$deploy_type" \
              --server "$CONNECT_SERVER_URL" \
              --api-key "$CONNECT_API_KEY" \
              --title "$content_name" \
              --entrypoint "$entrypoint" \
              .
            ;;
        shiny)
            echo "Deploying Shiny for Python application..."
            uv tool run --with rsconnect-python rsconnect deploy shiny \
              --server "$CONNECT_SERVER_URL" \
              --api-key "$CONNECT_API_KEY" \
              --title "$content_name" \
              .
            ;;
        streamlit)
            echo "Deploying Streamlit application..."
            uv tool run --with rsconnect-python rsconnect deploy streamlit \
              --server "$CONNECT_SERVER_URL" \
              --api-key "$CONNECT_API_KEY" \
              --title "$content_name" \
              "$main_file"
            ;;
        notebook)
            echo "Deploying Jupyter Notebook..."
            uv tool run --with rsconnect-python rsconnect deploy notebook \
              --server "$CONNECT_SERVER_URL" \
              --api-key "$CONNECT_API_KEY" \
              --title "$content_name" \
              "$main_file"
            ;;
        *)
            echo "Error: Unknown Python deployment type: $deploy_type"
            echo "Supported types: fastapi, shiny, dash, streamlit, notebook, api"
            exit 1
            ;;
    esac

# Deploy Quarto content
@deploy-quarto PATH:
    #!/usr/bin/env bash
    set -euo pipefail

    path="{{ PATH }}"

    # Convert to absolute path
    if [[ "$path" != /* ]]; then
        path="$(pwd)/$path"
    fi

    content_name="$(basename "$path")"

    echo "Deploying Quarto content..."

    if ! command -v quarto &>/dev/null; then
        echo "Error: quarto not found"
        echo "Install from: https://quarto.org/"
        exit 1
    fi

    cd "$path"

    # Deploy using quarto publish
    quarto publish connect \
      --server "$CONNECT_SERVER_URL" \
      --api-key "$CONNECT_API_KEY" \
      --no-prompt \
      .
