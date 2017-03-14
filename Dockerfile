FROM araczkowski/oracle-apex-ords

MAINTAINER Sergey Lukashevich <gnu.oracle@gmail.com>

ARG PASSWORD
ENV PASSWORD ${PASSWORD:-secret}

ARG TIMEZONE
ENV TIMEZONE ${TIMEZONE:-UTC}

ARG MA_DEMO
ENV MA_DEMO $MA_DEMO

ARG MA_DATA
ENV MA_DATA $MA_DATA

ARG MA_IMPORT
ENV MA_IMPORT $MA_IMPORT

#ARG PROXYSTRING
#ENV PROXYSTRING $PROXYSTRING

# get rid of the message: "debconf: unable to initialize frontend: Dialog"
ENV DEBIAN_FRONTEND noninteractive
ENV ORACLE_HOME /u01/app/oracle/product/11.2.0/xe
ENV PATH $ORACLE_HOME/bin:$PATH
ENV ORACLE_SID XE

EXPOSE 1521 8080

# all installation files
COPY meta-archive /meta-archive

# start the installation
RUN /meta-archive/install_main.sh

# ENTRYPOINT
ENTRYPOINT ["/meta-archive/entrypoint.sh"]

