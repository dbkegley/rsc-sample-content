# Dockerfile ref: https://github.com/rstudio/rstudio-docker-products/blob/main/content/base/bionic/Dockerfile 
FROM ubuntu:bionic

LABEL Author="David Kegley <david.kegley@rstudio.com>"

# Installation prerequisites --------------------------------------------------#
# curl is used to download things.
# libev-dev is required for most interactive Python applications.
RUN export DEBIAN_FRONTEND=noninteractive && \
        apt-get update \
        && \
        apt-get install -y \
        curl \
        libev-dev \
        && \
        rm -rf /var/lib/apt/lists/*

# System dependencies needed by popular R packages
# https://docs.rstudio.com/rsc/post-setup-tool/#install-system-dependencies

# Now, install the system requirements for R packages.
RUN export DEBIAN_FRONTEND=noninteractive && \
        apt-get update \
        && \
        apt-get install -y \
        default-jdk \
        gdal-bin \
        gdebi-core \
        git \
        gsfonts \
        imagemagick \
        libcairo2-dev \
        libcurl4-openssl-dev \
        libfontconfig1-dev \
        libfreetype6-dev \
        libfribidi-dev \
        libgdal-dev \
        libgeos-dev \
        libgl1-mesa-dev \
        libglpk-dev \
        libglu1-mesa-dev \
        libgmp3-dev \
        libharfbuzz-dev \
        libicu-dev \
        libjpeg-dev \
        libmagick++-dev \
        libmysqlclient-dev \
        libpng-dev \
        libpq-dev \
        libproj-dev \
        libsodium-dev \
        libssh2-1-dev \
        libssl-dev \
        libtiff-dev \
        libudunits2-dev \
        libv8-dev \
        libicu-dev \
        libxml2-dev \
        make \
        perl \
        tcl \
        tk \
        tk-dev \
        tk-table \
        unixodbc-dev \
        zlib1g-dev \
        && \
        rm -rf /var/lib/apt/lists/*

# Install TinyTeX -------------------------------------------------------------#
# From https://github.com/rstudio/r-docker/blob/master/base/bionic/Dockerfile

RUN export DEBIAN_FRONTEND=noninteractive && \
    apt-get update && \
    apt-get install -y wget && \
    rm -rf /var/lib/apt/lists/* && \
    wget -qO- "https://yihui.org/tinytex/install-bin-unix.sh" | sh && \
    /root/.TinyTeX/bin/*/tlmgr path remove && \
    mv /root/.TinyTeX/ /opt/TinyTeX && \
    /opt/TinyTeX/bin/*/tlmgr option sys_bin /usr/local/bin && \
    /opt/TinyTeX/bin/*/tlmgr path add && \
    rm -rf /var/lib/apt/lists/*

# Install Python --------------------------------------------------------------#
ARG PYTHON_VERSION=3.8.12

# https://deploy-preview-943--rstudio-docs.netlify.app/resources/install-python/#download-and-install-python
RUN curl -O https://cdn.rstudio.com/python/ubuntu-1804/pkgs/python-${PYTHON_VERSION}_1_amd64.deb && \
    gdebi --non-interactive python-${PYTHON_VERSION}_1_amd64.deb && \
    /opt/python/${PYTHON_VERSION}/bin/pip install --upgrade pip setuptools wheel && \
    rm python-${PYTHON_VERSION}_1_amd64.deb

# Install R -------------------------------------------------------------------#
# Reference: https://docs.rstudio.com/resources/install-r/

# We are NOT linking one of these R versions into the PATH.

ARG R_DISTRIBUTION=ubuntu-1804

ARG R_VERSION=4.1.2
ARG R_INSTALLER=r-${R_VERSION}_1_amd64.deb
RUN curl -fsSL -O https://cdn.rstudio.com/r/${R_DISTRIBUTION}/pkgs/${R_INSTALLER} && \
    export DEBIAN_FRONTEND=noninteractive && \
    apt-get update && \
    apt-get install -f -y ./${R_INSTALLER} && \
    rm ${R_INSTALLER} && \
    rm -rf /var/lib/apt/lists/*

# Install Quarto --------------------------------------------------------------#
ARG QUARTO_VERSION=1.0.37
RUN curl -L -o /quarto.deb https://github.com/quarto-dev/quarto-cli/releases/download/v${QUARTO_VERSION}/quarto-${QUARTO_VERSION}-linux-amd64.deb && \
  apt install /quarto.deb && \
  rm -f /quarto.deb

# Install Content Dependencies ------------------------------------------------#
### R
ENV R_LIBS_SITE=/opt/rpkgs
RUN mkdir -p ${R_LIBS_SITE} && chmod 755 ${R_LIBS_SITE}
COPY bootstrap.R /tmp/
RUN /opt/R/${R_VERSION}/bin/Rscript --no-save /tmp/bootstrap.R && \
    rm /tmp/bootstrap.R

### PYTHON
COPY requirements.txt /tmp/requirements.txt
RUN /opt/python/${PYTHON_VERSION}/bin/pip install -r /tmp/requirements.txt && \
    rm /tmp/requirements.txt
