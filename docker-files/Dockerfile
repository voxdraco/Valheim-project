# Pull down debian image
FROM debian:buster

# Run updates
RUN apt-get update

#Installing tools which can compile and install local languages as 
RUN apt-get -y install software-properties-common locales

# Intall GB english
RUN locale-gen en_GB.UTF-8

# Create steam group and set it as group ID 1000
RUN groupadd --gid 1000 steam

# Create steam user and put it in the correct steam group, set its shell and create a home folder
RUN useradd --uid 1000 --gid steam --shell /bin/bash --create-home steam

# Adding non-free repo for more compiling tools
RUN apt-add-repository non-free

# apt update
RUN apt-get update

# adding more tools for making stuff, specifically for i386 architecture
RUN dpkg --add-architecture i386

# update again
RUN apt-get update

# Adding aswers to steamcmd install for later on
RUN echo steam steam/question select "I AGREE" | debconf-set-selections
RUN echo steam steam/licence note '' | debconf-set-selections

# Installs steamcmd and language librariees
RUN apt-get -y install steamcmd lib32gcc1

# creating symlink for steamcmd 
RUN ln -s /usr/games/steamcmd /home/steam/steamcmd

# setting working directory as the steam users home directory
WORKDIR /home/steam

# copying over entrypoint script
COPY entrypoint.sh entrypoint.sh

# making the entrypoint script executable
RUN chmod +x entrypoint.sh

# changing the owner of the entrypoint script
RUN chown steam:steam entrypoint.sh

# copying over the installupdate.sh script
COPY InstallUpdate.sh InstallUpdate.sh

# making installupdate.sh script executable
RUN chmod +x InstallUpdate.sh

# chaning permissions of installupdate.sh
RUN chown steam:steam InstallUpdate.sh

# switching to steam user
USER steam

# making sure the workingdir didnt change
WORKDIR /home/steam

# creating a new directory where world data and other files will save
RUN mkdir -p /home/steam/.config/unity3d/IronGate/Valheim

# running script that will install valheim
RUN ./InstallUpdate.sh

# exposing ports for the game
EXPOSE 2456-2458/udp

EXPOSE 9001/tcp

EXPOSE 80/tcp

# lastly launching the entrypoint script.
ENTRYPOINT ["./entrypoint.sh"]
