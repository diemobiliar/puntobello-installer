# This Dockerfile is based on PowerShell Docker files
# Source: https://github.com/PowerShell/PowerShell-Docker/

ARG ARCH=amd64
FROM --platform=linux/${ARCH} mcr.microsoft.com/cbl-mariner/base/core:2.0 AS installer-env

    # Define Args for the needed to add the package
    ARG ARCH=amd64 \
        PS_VERSION=7.4.5 \
        PS_INSTALL_VERSION=7 \
        PS_PACKAGE_URL_BASE64

    # Define the folder we will be installing PowerShell to.
    ENV PS_INSTALL_FOLDER=/opt/microsoft/powershell/${PS_INSTALL_VERSION}

    # Create the install folder.
    RUN mkdir -p ${PS_INSTALL_FOLDER}

    RUN --mount=type=cache,target=/var/cache/tdnf \
        tdnf update -y \
        && tdnf install -y ca-certificates tar

    RUN if [[ "${ARCH}" == "arm64" ]]; then \
            curl -L https://github.com/PowerShell/PowerShell/releases/download/v${PS_VERSION}/powershell-${PS_VERSION}-linux-arm64.tar.gz -o /tmp/powershell.tar.gz \
            && pwsh_sha256='f0968649ecd47d5500ccb766c4ff4da34e0d78254cce9098c7f42d0e5484b513' \
            && echo "$pwsh_sha256  /tmp/powershell.tar.gz" | sha256sum -c - ; \
        else \
            curl -L https://github.com/PowerShell/PowerShell/releases/download/v${PS_VERSION}/powershell-${PS_VERSION}-linux-x64.tar.gz -o /tmp/powershell.tar.gz \
            && pwsh_sha256='c23509cc4d08c62b9ff6ea26f579ee4c50f978aa34269334a85eda2fec36f45b' \
            && echo "$pwsh_sha256  /tmp/powershell.tar.gz" | sha256sum -c - ; \
        fi && \
        tar zxf /tmp/powershell.tar.gz -C ${PS_INSTALL_FOLDER}

FROM --platform=linux/${ARCH} mcr.microsoft.com/cbl-mariner/base/nodejs:18.20.3-1-cm2.0.20240731-${ARCH} AS final-image

    # Define Args and Env needed to create links
    ARG ARCH=amd64 \
    PS_INSTALL_VERSION=7 \
    PS_VERSION=7.4.5 \
    SPFX_VERSION=1.18.2 \
    YEOMAN_VERSION=5.0.0 \
    M365CLI_VERSION=7.3.0 \
    PNP_VERSION=2.12.0 \
    AZ_VERSION=12.2.0

    ENV PS_INSTALL_FOLDER=/opt/microsoft/powershell/$PS_INSTALL_VERSION \
        \
        # Define ENVs for Localization/Globalization
        DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=false \
        LC_ALL=en_US.UTF-8 \
        LANG=en_US.UTF-8 \
        # set a fixed location for the Module analysis cache
        PSModuleAnalysisCachePath=/var/cache/microsoft/powershell/PSModuleAnalysisCache/ModuleAnalysisCache \
        POWERSHELL_DISTRIBUTION_CHANNEL=PSDocker-${ARCH}-Mariner-2

    # Copy only the files we need from the previous stage
    COPY --from=installer-env ["/opt/microsoft/powershell", "/opt/microsoft/powershell"]

    RUN --mount=type=cache,target=/var/cache/tdnf,rw \
        tdnf update -y \
        && tdnf install -y icu less openssh-clients ca-certificates git dotnet-runtime-7.0 tar awk shadow-utils terraform azure-cli \
        && tdnf upgrade -y \
        && tdnf clean all

    # # Install NPM Tooling
    RUN npm install gulp-cli yo@${YEOMAN_VERSION} @microsoft/generator-sharepoint@${SPFX_VERSION} @pnp/cli-microsoft365@${M365CLI_VERSION} --global

    # Install azd
    RUN curl -fsSL https://aka.ms/install-azd.sh | bash

        # Give all user execute permissions and remove write permissions for others
    RUN chmod a+x,o-w ${PS_INSTALL_FOLDER}/pwsh \
        # Create the pwsh symbolic link that points to powershell
        && ln -s ${PS_INSTALL_FOLDER}/pwsh /usr/bin/pwsh \
        && pwsh -Command Set-PSRepository -Name PSGallery -InstallationPolicy Trusted \
        && pwsh -Command Install-Module PnP.PowerShell -Scope AllUsers -RequiredVersion ${PNP_VERSION} \
        && pwsh -Command Install-Module Az -Scope AllUsers -RequiredVersion ${AZ_VERSION}

        # Create a non-root user and group 'node'
    RUN groupadd --gid 1000 node \
    && useradd --uid 1000 --gid node --shell /bin/bash --create-home node

    # Add scripts used within the pipeline and make them executable
    COPY scripts/ /usr/local/bin/
    RUN chown -R node:node /usr/local/bin \
        && chmod +x /usr/local/bin/*
    
    # Change ownership of home directory (if needed)
    RUN chown -R node:node /home/node

    # Set the working directory to the home directory of 'node'
    WORKDIR /home/node

    # Switch to the 'node' user
    USER node

    # Use PowerShell as the default shell
    # Use array to avoid Docker prepending /bin/sh -c
    CMD [ "pwsh" ]