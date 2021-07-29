FROM debian:buster

RUN apt-get update

RUN apt-get -y install software-properties-common locales

RUN locale-gen en_GB.UTF-8

RUN groupadd --gid 1000 steam

RUN useradd --uid 1000 --gid steam --shell /bin/bash --create-home steam

RUN apt-add-repository non-free

RUN apt-get update

RUN dpkg --add-architecture i386

RUN apt-get update

RUN echo steam steam/question select "I AGREE" | debconf-set-selections
RUN echo steam steam/licence note '' | debconf-set-selections


RUN apt-get -y install steamcmd lib32gcc1

RUN ln -s /usr/games/steamcmd /home/steam/steamcmd

WORKDIR /home/steam

COPY entrypoint.sh entrypoint.sh

RUN chmod +x entrypoint.sh

RUN chown steam:steam entrypoint.sh

COPY InstallUpdate.sh InstallUpdate.sh

RUN chmod +x InstallUpdate.sh

RUN chown steam:steam InstallUpdate.sh

USER steam

WORKDIR /home/steam

RUN mkdir -p /home/steam/.config/unity3d/IronGate/Valheim

RUN ./InstallUpdate.sh

EXPOSE 2456-2458/udp

EXPOSE 9001/tcp

EXPOSE 80/tcp

# Use env option in kubernetes instead

#ENV PASSWORD="projectilevomit"
#ENV SERVERNAME="Vox's little server"
#ENV PORT="2456"

ENTRYPOINT ["./entrypoint.sh"]
