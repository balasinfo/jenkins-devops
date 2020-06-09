FROM jenkins/jenkins:lts

LABEL maintainer "Dharama Rao <bala@consultant.com>"
ENV REFRESHED_AT 2019-06-05

# set variables - *** CHANGE ME ***
ARG docker_compose_version="1.25.0"
ARG packer_version="1.4.1"
ARG terraform_version="0.12.1"
ARG timezone="America/Los_Angeles"
ARG MAVEN_VERSION=3.6.3

ENV DOCKER_COMPOSE_VERSION $docker_compose_version
ENV PACKER_VERSION $packer_version
ENV TERRAFORM_VERSION $terraform_version
ENV TIMEZONE $timezone

# switch to install packages via apt
USER root

# update and install common packages
RUN set +x \
  && env \
  && apt-get update \
  && apt-get -y upgrade \
  && apt-get -y install openrc openntpd tzdata python3 python3-pip jq git

# update and install Docker CE and associated packages
RUN set +x \
  && apt-get install -y \
     lsb-release software-properties-common \
     apt-transport-https ca-certificates curl gnupg2 \
  && curl -fsSL https://download.docker.com/linux/debian/gpg | apt-key add - \
  && add-apt-repository \
    "deb [arch=amd64] https://download.docker.com/linux/debian \
    $(lsb_release -cs) \
    stable" \
  && apt-get update \
  && apt-get -y upgrade \
  && apt-get install -y docker-ce \
  && systemctl enable docker

# Install Maven
ARG MAVEN_VERSION=3.6.3
ARG MAVEN_BINARY_URL=https://www.apache.org/dist/maven/maven-3/${MAVEN_VERSION}/binaries/apache-maven-${MAVEN_VERSION}-bin.tar.gz
ARG MAVEN_BINARY_FILE=apache-maven-${MAVEN_VERSION}-bin.tar.gz
ARG MAVEN_HOME=${RUNNER_USER_HOME}/maven
ENV PATH ${MAVEN_HOME}/bin:${PATH}
RUN cd / && \
    curl -fsSLO --compressed "${MAVEN_BINARY_URL}" && \
    curl -fsSL  --compressed "${MAVEN_BINARY_URL}.sha512" | \
      xargs -I {} echo "{} *${MAVEN_BINARY_FILE}" | \
      sha512sum --check --strict && \
    mkdir -p "${MAVEN_HOME}" && \
    tar -xzf "${MAVEN_BINARY_FILE}" -C "${MAVEN_HOME}" --strip-components 1 && \
    rm "${MAVEN_BINARY_FILE}" && \
    mvn -v


# set permissions for jenkins user
RUN set +x \
    && usermod -aG staff,docker jenkins \
  && exec bash

# install Docker Compose
RUN set +x \
  && curl -L "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-`uname -s`-`uname -m`" > docker-compose \
  && cp docker-compose /bin/docker-compose \
  && chmod +x /bin/docker-compose

# install AWS CLI
RUN set +x \
  && pip3 install awscli --upgrade \
  && exec bash \
  && pip3 install ecs-deploy

# install HasiCorp Packer
RUN set +x \
  && wget "https://releases.hashicorp.com/packer/${PACKER_VERSION}/packer_${PACKER_VERSION}_linux_amd64.zip" \
  && unzip packer_${PACKER_VERSION}_linux_amd64.zip \
  && rm -rf packer_${PACKER_VERSION}_linux_amd64.zip \
  && mv packer /bin

# install HasiCorp Terraform
RUN set +x \
  && wget "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip" \
  && unzip terraform_${TERRAFORM_VERSION}_linux_amd64.zip \
  && rm -rf terraform_${TERRAFORM_VERSION}_linux_amd64.zip \
  && mv terraform /bin

# install Jenkins plugins
COPY plugins.txt /usr/share/jenkins/plugins.txt
RUN set +x \
  && /usr/local/bin/plugins.sh /usr/share/jenkins/plugins.txt

# list installed software versions
RUN set +x \
  && echo ''; echo '*** INSTALLED SOFTWARE VERSIONS ***';echo ''; \
  cat /etc/*release; python3 --version; \
  docker version; docker-compose version; \
  git --version; jq --version; pip3 --version; aws --version; \
  packer version; mvn --version; terraform version; echo '';

# For Jenkins User, not to prompt for the sudo user password, when switching as root user.
RUN echo "jenkins ALL=NOPASSWD: ALL" >> /etc/sudoers

RUN set +x \
  && apt-get clean

# set timezone to America/Los_Angeles
RUN set +x \
  && cp /usr/share/zoneinfo/${TIMEZONE} /etc/localtime \
  && echo "America/Los_Angeles" >  /etc/timezone \
  && date

# drop back to the regular jenkins user - good practice
USER jenkins
