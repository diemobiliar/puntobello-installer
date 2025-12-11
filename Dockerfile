# This Dockerfile is based on PowerShell Docker files
# Source: https://github.com/PowerShell/PowerShell-Docker/

ARG ARCH=amd64

## if mobi
FROM diemobiliar.azurecr.io/cac-cacerts-image:29 AS mobi-cacerts
FROM --platform=linux/${ARCH} mcr.microsoft.com/cbl-mariner/base/core:2.0 AS installer-env

    # Define Args for the needed to add the package
    ARG ARCH=amd64 \
        PS_VERSION=7.5.4 \
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
            && pwsh_sha256='4b32d4cb86a43dfb83d5602d0294295bf22fafbf9e0785d1aaef81938cda92f8' \
            && echo "$pwsh_sha256  /tmp/powershell.tar.gz" | sha256sum -c - ; \
        else \
            curl -L https://github.com/PowerShell/PowerShell/releases/download/v${PS_VERSION}/powershell-${PS_VERSION}-linux-x64.tar.gz -o /tmp/powershell.tar.gz \
            && pwsh_sha256='1fd7983fe56ca9e6233f126925edb24bf6b6b33e356b69996d925c4db94e2fef' \
            && echo "$pwsh_sha256  /tmp/powershell.tar.gz" | sha256sum -c - ; \
        fi && \
        tar zxf /tmp/powershell.tar.gz -C ${PS_INSTALL_FOLDER}

FROM --platform=linux/${ARCH} mcr.microsoft.com/cbl-mariner/base/core:2.0 AS final-image

    # Define Args and Env needed to create links
    ARG ARCH=amd64 \
    PS_INSTALL_VERSION=7 \
    PS_VERSION=7.5.4 \
    SPFX_VERSION=1.21.1 \
    YEOMAN_VERSION=5.1.0 \
    M365CLI_VERSION=10.9.0 \
    PNP_VERSION=3.1.0 \
    AZ_VERSION=14.2.0 \
    NODE_VERSION=22.15.0

    ENV PS_INSTALL_FOLDER=/opt/microsoft/powershell/$PS_INSTALL_VERSION \
        \
        # Define ENVs for Localization/Globalization
        DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=false \
        LC_ALL=en_US.UTF-8 \
        LANG=en_US.UTF-8 \
        # set a fixed location for the Module analysis cache
        PSModuleAnalysisCachePath=/var/cache/microsoft/powershell/PSModuleAnalysisCache/ModuleAnalysisCache \
        POWERSHELL_DISTRIBUTION_CHANNEL=PSDocker-${ARCH}-Mariner-2 \
        PNPPOWERSHELL_UPDATECHECK=false

    # Copy only the files we need from the previous stage
    COPY --from=installer-env ["/opt/microsoft/powershell", "/opt/microsoft/powershell"]

    RUN --mount=type=cache,target=/var/cache/tdnf,rw \
        tdnf update -y \
        && tdnf install -y icu less openssh-clients ca-certificates git dotnet-runtime-7.0 tar awk shadow-utils terraform azure-cli \
        && tdnf upgrade -y \
        && tdnf clean all

    RUN NODE_ARCH=$([ "${ARCH}" = "amd64" ] && echo "x64" || echo "${ARCH}") && \
        curl -fsSL https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-${NODE_ARCH}.tar.xz -o /tmp/node.tar.xz \
        && mkdir -p /usr/local/lib/nodejs \
        && tar -xJf /tmp/node.tar.xz -C /usr/local/lib/nodejs \
        && ln -s /usr/local/lib/nodejs/node-v${NODE_VERSION}-linux-${NODE_ARCH}/bin/node /usr/bin/node \
        && ln -s /usr/local/lib/nodejs/node-v${NODE_VERSION}-linux-${NODE_ARCH}/bin/npm /usr/bin/npm \
        && ln -s /usr/local/lib/nodejs/node-v${NODE_VERSION}-linux-${NODE_ARCH}/bin/npx /usr/bin/npx \
        && node --version && npm --version

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