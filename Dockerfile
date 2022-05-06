FROM ubuntu:20.04

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Europe/Berlin

RUN apt update && \
    apt install -y \
        python3.8 \
        python3-pip \
        openssh-server \
        net-tools \
    && \
    pip3 install --upgrade pip \
    && \
    pip3 install \
        pytest

RUN ssh-keygen -A
RUN passwd -d root
RUN sed -ri 's/#PermitEmptyPasswords no/PermitEmptyPasswords yes/' /etc/ssh/sshd_config
RUN sed -ri 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config
RUN sed -ri 's/^UsePAM yes/UsePAM no/' /etc/ssh/sshd_config
COPY startup.sh /usr/bin/startup.sh
RUN /etc/init.d/ssh start
RUN rm -f /sbin/init
COPY _build/init /sbin/init
