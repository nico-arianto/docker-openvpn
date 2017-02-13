# - Credit to Digital Ocean <https://www.digitalocean.com/community/tutorials/how-to-set-up-an-openvpn-server-on-ubuntu-16-04>

FROM ubuntu:16.04

MAINTAINER Nico Arianto <nico.arianto@gmail.com>

ARG KEY_COUNTRY
ARG KEY_PROVINCE
ARG KEY_CITY
ARG KEY_ORG
ARG KEY_EMAIL
ARG KEY_OU
ARG KEY_CN
ARG KEY_NAME
ARG KEY_TAGGING
ARG SERVER_ADDRESS

ENV KEY_COUNTRY="${KEY_COUNTRY:-SG}"
ENV KEY_PROVINCE="${KEY_PROVINCE:-SG}"
ENV KEY_CITY="${KEY_CITY:-Singapore}"
ENV KEY_ORG="${KEY_ORG:-NA}"
ENV KEY_EMAIL="${KEY_EMAIL:-NA}"
ENV KEY_OU="${KEY_OU:-NA}"
ENV KEY_CN="${KEY_CN:-NA}"
ENV KEY_NAME="${KEY_NAME:-NA}"
ENV KEY_TAGGING="${KEY_TAGGING:-0}"
ENV SERVER_ADDRESS="${SERVER_ADDRESS:-localhost}"

# Install OpenVPN

RUN apt-get update && \
    apt-get install -y apt-utils && \
    apt-get install -y openvpn easy-rsa

# Set Up the CA Directory

RUN make-cadir /root/openvpn-ca

# Configure the CA variables

WORKDIR /root/openvpn-ca

RUN sed -i "s/\(KEY_COUNTRY=\).*\$/\1\"$KEY_COUNTRY\"/" vars && \
    sed -i "s/\(KEY_PROVINCE=\).*\$/\1\"$KEY_PROVINCE\"/" vars && \
    sed -i "s/\(KEY_CITY=\).*\$/\1\"$KEY_CITY\"/" vars && \
    sed -i "s/\(KEY_ORG=\).*\$/\1\"$KEY_ORG\"/" vars && \
    sed -i "s/\(KEY_EMAIL=\).*\$/\1\"$KEY_EMAIL\"/" vars && \
    sed -i "s/\(KEY_OU=\).*\$/\1\"$KEY_OU\"/" vars && \
    sed -i "s/\(KEY_NAME=\).*\$/\1\"$KEY_NAME\"/" vars && \
    sed -i "s/\(KEY_CN=\).*\$/\1\"$KEY_CN\"/" vars && \
    sed -i "s/# export KEY_CN/export KEY_CN/" vars && \
    echo 'export KEY_ALTNAMES="DNS:'$KEY_CN'"' >> vars

## Creating a Certificates Generation Script

RUN echo "#!/bin/bash" > make_all.sh && \
    echo "" >> make_all.sh && \
    echo "source vars" >> make_all.sh && \
    echo "./clean-all" >> make_all.sh && \
    echo "if [ -f ~/.rnd ]; then" >> make_all.sh && \
    echo "  rm ~/.rnd" >> make_all.sh && \
    echo "fi" >> make_all.sh && \
    echo "./build-ca <<< $'\n\n\n\n\n\n\n\n'" >> make_all.sh && \
    echo "./build-key-server server_\${KEY_NAME}_\${KEY_TAGGING} <<< $'\n\n\n\n\n\n\n\n\n\ny\ny\n'" >> make_all.sh && \
    echo "./build-dh" >> make_all.sh && \
    echo "openvpn --genkey --secret keys/ta.key" >> make_all.sh && \
    echo "./build-key client_\${KEY_NAME}_\${KEY_TAGGING} <<< $'\n\n\n\n\n\n\n\n\n\ny\ny\n'" >> make_all.sh && \
    chmod 700 make_all.sh

# Configure the OpenVPN Service

## Copy the Files to the OpenVPN Directory

WORKDIR /root/openvpn-ca/keys

RUN gunzip -c /usr/share/doc/openvpn/examples/sample-config-files/server.conf.gz | tee /etc/openvpn/server.conf

## Adjust the OpenVPN Configuration
## Basic Configuration
## Push DNS Changes to Redirect All Traffic Through the VPN
## Point to Non-Default Credentials

WORKDIR /etc/openvpn/

RUN sed -i "s/;tls-auth/tls-auth/" server.conf && \
    sed -i "/tls-auth/a\\key-direction 0" server.conf && \
    sed -i "s/;cipher AES-128-CBC/cipher AES-128-CBC/" server.conf && \
    sed -i "/cipher AES-128-CBC/a\\auth SHA256" server.conf && \
    sed -i "s/;user nobody/user nobody/" server.conf && \
    sed -i "s/;group nogroup/group nogroup/" server.conf && \
    sed -i "s/;push \"redirect-gateway/push \"redirect-gateway/" server.conf && \
    sed -i "s/;push \"dhcp-option/push \"dhcp-option/" server.conf && \
    sed -i "s/;duplicate-cn/duplicate-cn/" server.conf

# Adjust the Server Networking Configuration

RUN sed -i "s/#net.ipv4.ip_forward/net.ipv4.ip_forward/" /etc/sysctl.conf && \
    sysctl -p

# Create Client Configuration Infrastructure

RUN mkdir -p /root/client-configs/files && \
    chmod 700 /root/client-configs/files && \
    cp /usr/share/doc/openvpn/examples/sample-config-files/client.conf /root/client-configs/base.conf

WORKDIR /root/client-configs/

RUN sed -i "s/ca ca.crt/#ca ca.crt/" base.conf && \
    sed -i "s/cert client.crt/#cert client.crt/" base.conf && \
    sed -i "s/key client.key/#key client.key/" base.conf && \
    echo '' >> base.conf && \
    echo 'cipher AES-128-CBC' >> base.conf && \
    echo 'auth SHA256' >> base.conf && \
    echo 'key-direction 1' >> base.conf && \
    echo '# script-security 2' >> base.conf && \
    echo '# up /etc/openvpn/update-resolv-conf' >> base.conf && \
    echo '# down /etc/openvpn/update-resolv-conf' >> base.conf

## Creating a Configuration Generation Script

RUN echo "#!/bin/bash" > make_config.sh && \
    echo "" >> make_config.sh && \
    echo "cat /root/client-configs/base.conf \\" >> make_config.sh && \
    echo "    <(echo -e '<ca>') \\" >> make_config.sh && \
    echo "    /root/openvpn-ca/keys/ca.crt \\" >> make_config.sh && \
    echo "    <(echo -e '</ca>') \\" >> make_config.sh && \
    echo "    <(echo -e '<cert>') \\" >> make_config.sh && \
    echo "    /root/openvpn-ca/keys/client_\${KEY_NAME}_\${KEY_TAGGING}.crt \\" >> make_config.sh && \
    echo "    <(echo -e '</cert>') \\" >> make_config.sh && \
    echo "    <(echo -e '<key>') \\" >> make_config.sh && \
    echo "    /root/openvpn-ca/keys/client_\${KEY_NAME}_\${KEY_TAGGING}.key \\" >> make_config.sh && \
    echo "    <(echo -e '</key>') \\" >> make_config.sh && \
    echo "    <(echo -e '<tls-auth>') \\" >> make_config.sh && \
    echo "    /root/openvpn-ca/keys/ta.key \\" >> make_config.sh && \
    echo "    <(echo -e '</tls-auth>') \\" >> make_config.sh && \
    echo "    > /root/client-configs/files/client_\${KEY_NAME}_\${KEY_TAGGING}.ovpn" >> make_config.sh && \
    chmod 700 make_config.sh

# Creating a Certificates and a Configuration Script

WORKDIR /root/

RUN echo "#!/bin/bash" > remake_all.sh && \
    echo "" >> remake_all.sh && \
    echo "cd /root/openvpn-ca" >> remake_all.sh && \
    echo "./make_all.sh" >> remake_all.sh && \
    echo "cd /root/openvpn-ca/keys" >> remake_all.sh && \
    echo "cp ca.crt ca.key server_\${KEY_NAME}_\${KEY_TAGGING}.crt server_\${KEY_NAME}_\${KEY_TAGGING}.key ta.key dh2048.pem /etc/openvpn" >> remake_all.sh && \
    echo "cd /etc/openvpn" >> remake_all.sh && \
    echo 'sed -i "s/\(cert server\).*\(.crt\)\\$/cert server_${KEY_NAME}_${KEY_TAGGING}.crt/" server.conf' >> remake_all.sh && \
    echo 'sed -i "s/\(key server\).*\(.key\).*\\$/key server_${KEY_NAME}_${KEY_TAGGING}.key/" server.conf' >> remake_all.sh && \
    echo "cd /root/client-configs" >> remake_all.sh && \
    echo 'sed -i "s/\(remote \).*\( 1194\)\\$/remote ${SERVER_ADDRESS} 1194/" base.conf' >> remake_all.sh && \
    echo "./make_config.sh" >> remake_all.sh && \
    chmod 700 remake_all.sh

# Build the Certificate Authority
# Create the Server Certificate, Key and Encryption Files
# Generate a Client Certificate and Key Pair
# Generate Client Configurations

RUN ./remake_all.sh

# Start the OpenVPN

WORKDIR /root/

EXPOSE 1194/udp

CMD /usr/sbin/openvpn --cd /etc/openvpn --script-security 2 --config /etc/openvpn/server.conf

### Important: Give extended privileges (--privileged) and connect a container to a host network in docker run command.
### Example: docker run -d --privileged --network host --name openvpn openvpn:2.3.10
