FROM alpine:latest

RUN mkdir -p /structured_sbom_outputs

RUN ( \
   apk add --no-cache --update \
   git bash curl openssl-dev readline-dev zlib-dev autoconf bison build-base yaml-dev ncurses-dev libffi-dev gdbm-dev jq ruby \
   ruby-dev make musl-dev go npm py3-pip php php-mbstring php-dom composer \
)

# Install cyclonedx-ruby-gem

RUN ( \
    git clone https://github.com/CycloneDX/cyclonedx-ruby-gem.git /opt/cyclonedx-ruby-gem && \
    cd /opt/cyclonedx-ruby-gem && gem build cyclonedx-ruby.gemspec && \
    gem install cyclonedx-ruby-1.1.0.gem && gem install activesupport bundler \
)

# Install cyclonedx-gomod

ENV GOROOT /usr/lib/go
ENV GOPATH /go
ENV PATH /go/bin:$PATH

RUN mkdir -p ${GOPATH}/src ${GOPATH}/bin

RUN go install github.com/CycloneDX/cyclonedx-gomod/cmd/cyclonedx-gomod@latest

# Install cyclonedx-node

RUN npm install -y @cyclonedx/bom -g

# Install cyclonedx-python

RUN pip install cyclonedx-bom

# Install cyclonedx-php-composer

RUN composer global config --no-plugins allow-plugins.cyclonedx/cyclonedx-php-composer true
RUN composer global require cyclonedx/cyclonedx-php-composer

# Install cyclonedx-conan

RUN ( \
    pip install git+https://github.com/CycloneDX/cyclonedx-conan@main && \
    conan config set general.revisions_enabled=1 && \
    conan remote add bincrafters https://bincrafters.jfrog.io/artifactory/api/conan/public-conan \
)

# Install cyclonedx-cli

RUN curl -fSL -o cyclonedx-cli "https://github.com/CycloneDX/cyclonedx-cli/releases/download/v0.24.2/cyclonedx-linux-musl-x64" \
  && mv cyclonedx-cli /usr/local/bin/cyclonedx-cli \
  && chmod +x /usr/local/bin/cyclonedx-cli

# Install syft

RUN curl -sSfL https://raw.githubusercontent.com/anchore/syft/main/install.sh | sh -s -- -b /usr/local/bin

COPY generate-sbom.sh /usr/local/bin

ENTRYPOINT ["/usr/local/bin/generate-sbom.sh"]
