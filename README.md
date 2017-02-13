# docker-openvpn

OpenVPN Server Docker

## Information

OpenVPN 2.3.10 server that based from Docker Image - Ubuntu 16.04

## Requisites

- Docker 1.13.0 (or higher)

## How to setup

### Create a Docker image

Create a new Docker image that based from Ubuntu 16.04 and install:
- OpenVPN 2.3.10 (or higher)
- easy-rsa 2.2.2-2 (or higher)

__Example command line:__

>     docker build -t openvpn:2.3.10 \
>       --build-arg KEY_COUNTRY=SG \
>       --build-arg KEY_PROVINCE=SG \
>       --build-arg KEY_CITY=Singapore \
>       --build-arg KEY_ORG=Organization \
>       --build-arg KEY_EMAIL=nico.arianto@gmail.com \
>       --build-arg KEY_OU=OrganizationUnit \
>       --build-arg KEY_CN=CommonName \
>       --build-arg KEY_NAME=Name \
>       --build-arg KEY_TAGGING=0 \
>       --build-arg SERVER_ADDRESS=RemoteAddress \
>       .

### Create and Run a Docker container

Create and run a new Docker container, mount a host directory and create the OpenVPN client configuration (ovpn) file.

__Example command line:__

>     docker run -d --privileged \
>       --volume ~/ovpn-files:/root/client-configs/files \
>       --network host \
>       --name openvpn openvpn:2.3.10

Continue with this command line to recreate the OpenVPN client configuration (ovpn) file in the mounted directory.

>     docker exec -t openvpn /root/client-configs/make_config.sh

### Regenerate the Certification files and Client configuration file

Regenerate the server and client certification files and client configuration file.

__Example command line:__

>     docker exec -t \
>       --e KEY_NAME=Name \
>       --e KEY_TAGGING=1 \
>       openvpn /root/remake_all.sh

Continue with this command line to restart the Docker container to reload the new certification files and server configuration changes.

>     docker restart openvpn

## Post Installation

- Enable IPv4 forwarding.
- Adjust Firewall rules to Masquerade client connections.
- Open the OpenVPN port and protocol.

For more detail on how to do it in **Ubuntu 16.04**, please read [Digital Ocean - Adjust the Server Networking Configuration](https://www.digitalocean.com/community/tutorials/how-to-set-up-an-openvpn-server-on-ubuntu-16-04#step-8-adjust-the-server-networking-configuration)

## Current Installation

- Duplicate CN is enabled.
- Server and Clint certification files are always be generated together.

If there's any changes required to fit your environment or implementation, please do the necessary changes in Dockerfile.

## Limitation

- Only been tested with **Ubuntu 16.04** as the host OS.
- Privileged must be extended and using host network.
- Port is hardcoded to always use **1194**.

## Credit
- [Digital Ocean](https://www.digitalocean.com/community/tutorials/how-to-set-up-an-openvpn-server-on-ubuntu-16-04)
