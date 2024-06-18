FROM artifactory.tfs.toyota.com/devops-docker-remote/amazoncorretto:11.0.23-alpine3.19

LABEL MAINTAINER="DevOps Engineering" \
    os.version="Alpine Linux v3.19" \
    python.version="3.11"

USER root

RUN apk upgrade --available --force-missing-repositories
RUN echo -e "https://artifactory.tfs.toyota.com/artifactory/devops-alpine-remote/v3.19/main\nhttps://artifactory.tfs.toyota.com/artifactory/devops-alpine-remote/v3.19/community" > /etc/apk/repositories

RUN apk update && apk upgrade --available --force-missing-repositories && apk add --no-cache libc6-compat gdb libstdc++ zip icu gettext gettext-dev git git-lfs build-base curl python3~3.11 py3-pip pipx aws-cli bash gcompat

# Conifgure Pip to use Artifactory and upgrade
RUN pip config set --site global.index https://artifactory.tfs.toyota.com/artifactory/devops-pypi-virtual/
RUN pip config set --site global.index-url https://artifactory.tfs.toyota.com/artifactory/devops-pypi-virtual/
RUN pip config set --site global.trusted-host artifactory.tfs.toyota.com
RUN pipx install veracode-api-signing

ARG JENKINS_HOME=/var/jenkins_home
ARG SYS_CA_CERT_DIR=/usr/local/share/ca-certificates

ARG user=jenkins
ARG group=jenkins
ARG uid=1000
ARG gid=1000
ARG PIPELINEMANAGER_CLI_ARTIFACT_URL
ARG PIPELINEMANAGER_CLI_HOME=/home/${user}/pipelinemanager_cli
RUN export JAVA_HOME="/usr/local/openjdk-11"
ENV PATH="$JAVA_HOME/bin:${PATH}:${PIPELINEMANAGER_CLI_HOME}"

RUN addgroup ${group} && adduser -s /bin/bash -h /home/${user} -D -G ${user}  ${user}

ARG AGENT_WORKDIR=/home/${user}/agent

COPY ./resources/remoting-4.9.jar /usr/share/jenkins/
RUN chmod 755 /usr/share/jenkins \
  && ln -sf /usr/share/jenkins/remoting-4.9.jar /usr/share/jenkins/agent.jar \
  && chmod +x /usr/share/jenkins/agent.jar \
  && ln -sf /usr/share/jenkins/agent.jar /usr/share/jenkins/slave.jar \
  && chmod 755 /usr/share/jenkins/agent.jar
ENV PATH="/usr/share/jenkins:$PATH"

COPY ./resources/jenkins-agent /usr/local/bin/jenkins-agent
RUN chmod +x /usr/local/bin/jenkins-agent &&\
    ln -s /usr/local/bin/jenkins-agent /usr/local/bin/jenkins-slave


ENV AGENT_WORKDIR=${AGENT_WORKDIR}
RUN mkdir /home/${user}/.jenkins && mkdir -p ${AGENT_WORKDIR}

ENV JAVA_HOME="/usr/lib/jvm/default-jvm"
ENV PATH="$JAVA_HOME/bin:$PATH"


RUN ls -ltr

COPY ./resources/certs $JAVA_HOME/lib/security/

# Change directories to certificates to source downloaded certificates
WORKDIR /usr/local/share/ca-certificates

# Install TFS root and intermediate certificates then update the certificate store
RUN for cert in TFS-Root-02.crt TFS-Issuing-02.crt; \
    do \
        wget http://crl2.tfs.toyota.com/${cert}; \
     done; \
    for cert in TFS-Root-03.crt TFS-Issuing-03.crt; \
        do \
            wget http://tfs.crt.sectigo.com/${cert}; \
        done; \
    cd /etc/ssl/certs/ && update-ca-certificates \
    && for filename in $JAVA_HOME/lib/security/*.cer; do echo "$filename"; keytool -importcert -trustcacerts -alias ${filename%.*} -file $filename -keystore $JAVA_HOME/lib/security/cacerts -storepass changeit -noprompt ; done



#installation of sonar salseforce plugin
RUN mkdir /opt/sonar-scanner-3.3.0.1492
COPY ./resources/sonar-scanner-cli-3.3.0.1492.zip /opt/
RUN cd /opt/ && unzip sonar-scanner-cli-3.3.0.1492.zip
ENV PATH="/opt/sonar-scanner-3.3.0.1492/bin/:$PATH"

RUN export PATH=$PATH:/home/jenkins/.local/bin

# Installing pipeline manager CLI
RUN if [ "${PIPELINEMANAGER_CLI_ARTIFACT_URL}" != "" ] ; then mkdir -p ${PIPELINEMANAGER_CLI_HOME} && curl -o ${PIPELINEMANAGER_CLI_HOME}/pipelinemanager_cli.tar.gz ${PIPELINEMANAGER_CLI_ARTIFACT_URL} && cd ${PIPELINEMANAGER_CLI_HOME} && pip3.10 install pipelinemanager_cli.tar.gz; fi

# Install Gradle 7.6
COPY ./resources/gradle/gradle-7.6-bin.zip /tmp
RUN unzip -d /opt/gradle /tmp/gradle-*.zip \
    && ln -sf /opt/gradle/gradle-7.6/bin/gradle /usr/local/bin/gradle \
    && rm -rf /tmp/gradle-7.6-bin.zip

# Downoading scource clear
#RUN mkdir /opt/sca-scan
#RUN wget https://artifactory.tfs.toyota.com/artifactory/test-sca-local/srcclr-3.8.41-linux.tgz \
#    && tar xzf "srcclr-3.8.41-linux.tgz" -C /opt/sca-scan/ \
#    && ls -ltr

# Install SCA scan agent alpine package
COPY ./resources/srcclr-3.8.65-r0.apk /tmp
RUN apk update && apk add --allow-untrusted /tmp/srcclr-3.8.65-r0.apk && rm /tmp/srcclr-3.8.65-r0.apk


# Downloading Pipeline scan
RUN mkdir /opt/pipeline-scan
RUN wget https://artifactory.tfs.toyota.com:443/artifactory/test-sca-local/pipeline-scan-LATEST.zip \
    && unzip -o "pipeline-scan-LATEST.zip" -d /opt/pipeline-scan/ \
    && ls -ltr

# Install Apache-maven 3.8.1
RUN mkdir /home/jenkins/.m2
ENV MAVEN_HOME=/opt/maven
ADD ./resources/mvn/apache-maven-3.8.1-bin.tar.gz /opt/
RUN ln -s /opt/apache-maven-3.8.1 /opt/maven \
    && ln -s /opt/maven/bin/mvn /usr/local/bin

ENV TEST_BASE=/var/jenkins

# Install Ant-1.10.11
ARG ANT_VERSION=1.10.11
ENV ANT_HOME=/opt/apache-ant-${ANT_VERSION}/
ENV PATH=${PATH}:${ANT_HOME}/bin
ADD ./resources/ant/apache-ant-${ANT_VERSION}-bin.tar.gz /opt/
RUN ln -s /opt/apache-ant-${ANT_VERSION}/bin/ant /usr/local/bin/

# RUN cp /var/jenkins_home/centrifycli.config /var/jenkins_home/centrifycli.token /home/jenkins

RUN chown -R jenkins /opt/sonar-scanner-3.3.0.1492 \
    && chown -R jenkins /home/jenkins/ \
    && chown -R jenkins /usr/local/bin \
    && ls -la /home/jenkins


WORKDIR ${AGENT_WORKDIR}

RUN chmod 655 -R $JAVA_HOME/lib

#USER jenkins

# Adding Centrify Binaries
COPY --chown=jenkins:jenkins ./resources/centrify_files-master ${JENKINS_HOME}
RUN ls -ltrh ${JENKINS_HOME}
RUN chmod -R 755 /var/jenkins_home/
RUN ls -ltrh /var/jenkins_home
RUN cp /var/jenkins_home/centrifycli.config /var/jenkins_home/centrifycli.token /home/jenkins
RUN sed -i 's/\r$//' /var/jenkins_home/checkout-v2.sh /var/jenkins_home/checkout-v3.sh
RUN ln -sf /var/jenkins_home/CentrifyCLI-v1.0.8.0-linux-x64/ccli /var/jenkins_home/ccli-v1.0.2.0-linux-x64/linux-x64/ccli

RUN python3 -m venv /home/jenkins/venv2

ENTRYPOINT ["/usr/local/bin/jenkins-agent"]
