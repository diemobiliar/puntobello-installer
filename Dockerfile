# This Dockerfile is based on PowerShell Docker files
# Source: https://github.com/PowerShell/PowerShell-Docker/

ARG ARCH=arm64
FROM --platform=linux/${ARCH} mcr.microsoft.com/azurelinux/base/core:3.0 AS installer-env

    # Define Args for the needed to add the package
    ARG ARCH=arm64 \
        PS_VERSION=7.6.5 \
        PS_INSTALL_VERSION=7 \
        PS_PACKAGE_URL_BASE64

    # Define the folder we will be installing PowerShell to.
    ENV PS_INSTALL_FOLDER=/opt/microsoft/powershell/${PS_INSTALL_VERSION}

    # Create the install folder.
    RUN mkdir -p ${PS_INSTALL_FOLDER}

    RUN --mount=type=cache,target=/var/cache/tdnf \
        tdnf update -y \
        && tdnf install -y ca-certificates tar

    RUN if [[ "${ARCH}" == "amd64" ]]; then \
            curl -L https://github.com/PowerShell/PowerShell/releases/download/v${PS_VERSION}/powershell-${PS_VERSION}-linux-x64.tar.gz -o /tmp/powershell.tar.gz \
            && pwsh_sha256='b34ab3b19acac1d3d4d0d3cfdb02acf62f457b0b6a962ff008132033f7566844' \
            && echo "$pwsh_sha256  /tmp/powershell.tar.gz" | sha256sum -c - ; \
        else \
            curl -L https://github.com/PowerShell/PowerShell/releases/download/v${PS_VERSION}/powershell-${PS_VERSION}-linux-arm64.tar.gz -o /tmp/powershell.tar.gz \
            && pwsh_sha256='ed4084f215d8bce2edd23aa7cb1f1e7b0818e41363a635a22065d2701b6141df' \
            && echo "$pwsh_sha256  /tmp/powershell.tar.gz" | sha256sum -c - ; \
        fi && \
        tar zxf /tmp/powershell.tar.gz -C ${PS_INSTALL_FOLDER}

FROM --platform=linux/${ARCH} mcr.microsoft.com/azurelinux/base/core:3.0 AS final-image

    # Define Args and Env needed to create links
    ARG ARCH=arm64 \
    DOTNET_RUNTIME_VERSION=10.0 \
    PS_INSTALL_VERSION=7 \
    PS_VERSION=7.6.5 \
    SPFX_VERSION=1.22.1 \
    YEOMAN_VERSION=5.1.0 \
    M365CLI_VERSION=11.11.0 \
    PNP_VERSION=3.4.1 \
    AZ_VERSION=16.3.0 \
    NODE_VERSION=22.15.0 \
    TERRAFORM_VERSION=1.16.1

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
        && tdnf install -y icu less openssh-clients ca-certificates git unzip dotnet-runtime-${DOTNET_RUNTIME_VERSION} tar awk shadow-utils azure-cli \
        && tdnf upgrade -y \
        && tdnf clean all

    RUN curl -fsSL https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_${ARCH}.zip -o terraform.zip && \
        unzip terraform.zip && \
        mv terraform /usr/local/bin/ && \
        chmod +x /usr/local/bin/terraform && \
        rm terraform.zip

    RUN NODE_ARCH=$([ "${ARCH}" = "amd64" ] && echo "x64" || echo "${ARCH}") && \
        curl -fsSL https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-${NODE_ARCH}.tar.xz -o /tmp/node.tar.xz \
        && mkdir -p /usr/local/lib/nodejs \
        && tar -xJf /tmp/node.tar.xz -C /usr/local/lib/nodejs \
        && ln -s /usr/local/lib/nodejs/node-v${NODE_VERSION}-linux-${NODE_ARCH}/bin/node /usr/bin/node \
        && ln -s /usr/local/lib/nodejs/node-v${NODE_VERSION}-linux-${NODE_ARCH}/bin/npm /usr/bin/npm \
        && ln -s /usr/local/lib/nodejs/node-v${NODE_VERSION}-linux-${NODE_ARCH}/bin/npx /usr/bin/npx \
        && node --version && npm --version

    # # Install NPM Tooling
    RUN npm install yo@${YEOMAN_VERSION} @microsoft/generator-sharepoint@${SPFX_VERSION} @pnp/cli-microsoft365@${M365CLI_VERSION} --global

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