FROM node:18.19.1-alpine3.19
LABEL maintainer="die Mobiliar"

ARG NPM_VERSION=10.4.0 \
    SPFX_VERSION=1.18.2 \
    YEOMAN_VERSION=5.0.0 \
    M365CLI_VERSION=7.3.0 \
    PS_INSTALL_VERSION=7 \
    PS_VERSION=7.4.4 \
    PNP_VERSION=2.2.0 \
    AZ_VERSION=12.1.0

ENV PS_INSTALL_FOLDER=/opt/microsoft/powershell/$PS_INSTALL_VERSION \
    PNPPOWERSHELL_UPDATECHECK=false \
    PATH="${PATH}:/home/node/.npm/bin" \
    NODE_PATH="${NODE_PATH}:/home/node/.npm/lib/node_modules"

# # Install NPM Tooling
RUN apk update && \
    apk add --no-cache --upgrade bash git curl openssl grep openssh-client zip && \
    npm install npm@${NPM_VERSION} gulp-cli yo@${YEOMAN_VERSION} @microsoft/generator-sharepoint@${SPFX_VERSION} @pnp/cli-microsoft365@${M365CLI_VERSION} --global

# Install powershell
RUN apk add --no-cache --upgrade \
    less \
    ncurses-terminfo-base \
    krb5-libs \
    libgcc \
    libintl \
    libstdc++ \
    libssl3 \
    tzdata \
    userspace-rcu \
    zlib \
    icu-libs && \
    apk -X https://dl-cdn.alpinelinux.org/alpine/edge/main add --no-cache \
    lttng-ust && \
    curl -L https://github.com/PowerShell/PowerShell/releases/download/v${PS_VERSION}/powershell-${PS_VERSION}-linux-musl-x64.tar.gz -o /tmp/powershell.tar.gz && \
    mkdir -p ${PS_INSTALL_FOLDER} && \
    tar zxf /tmp/powershell.tar.gz -C ${PS_INSTALL_FOLDER} && \
    chmod +x ${PS_INSTALL_FOLDER}/pwsh && \
    ln -s ${PS_INSTALL_FOLDER}/pwsh /usr/bin/pwsh && \
    pwsh -Command Set-PSRepository -Name PSGallery -InstallationPolicy Trusted && \
    pwsh -Command Install-Module PnP.PowerShell -Scope AllUsers -RequiredVersion ${PNP_VERSION} && \
    pwsh -Command Install-Module Az -Scope AllUsers -RequiredVersion ${AZ_VERSION} && \
    find /usr/local/share/powershell/Modules -name "*.deps.json" -type f -delete

# Add scripts used within the pipeline
COPY scripts/ /usr/local/bin/
# COPY scripts/sh/ /usr/local/bin/
RUN chmod +x /usr/local/bin/*

USER node