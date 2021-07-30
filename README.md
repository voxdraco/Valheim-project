# Valheim-project

Hello and welcome to my valheim project.

In this I will be going over simple project I worked on to spin up a valheim containter from scratch and how to get it working in kubernetes.

If you are attempting to do this yourself, you need to configure a kubernetes cluster yourself first AND a registry where the containters can sit. 

kubernetes cluster: https://www.virtualizationhowto.com/2021/06/kubernetes-home-lab-setup-step-by-step/

registry: https://www.linuxtechi.com/setup-private-docker-registry-kubernetes/

Who this is for:

People who are starting out. This container and kubentes configuration are very simple and I attempt to keep it that way, however I do realize that there will be instances where I do things which might make you ask why and if this is the case, I will try and explain it.



-----------------

Requirements:

Docker
kubectl and a working kubernetes node/cluster

-----------------

I will go through the process and explain why I have done things the way I have. Please keep in mind this is the first time I have ever published a project like this ti github.

Lets start off by going over the Dockerfile inside the docker-files directory as this is the first project thing you need create if you want to use this, so from the top.

The first line inside the Dockerfile will tell docker what image to use. I have elected to use the debian buster image because I am most familiar with debian.

```
FROM: debain:buster
```
The next few lines are self explanatory. They do an apt update and then installs two packages. One allows debian to install non-free packages and the other (locales) installs software that allows you to adjust what language debian will use. It will then use the GB english package.

``` 

RUN apt-get update

RUN apt-get -y install software-properties-common locales

RUN locale-gen en_GB.UTF-8

```

The next two lines create a user and set its gid, uid, shell and tell it to create a home directory.

This next bit is important. When you first create a user in debian, it defaults to the user group 1000 and user ID 1000. This assures that its ALWAYS set to this for future prosparity. The reason gid/uid 1000 is important is because of the way kubernetes persistant data storage works. Valheim needs to save data, it goes without saying... but in order to do that the user ID and the GID MUST be the same as the persistent volumes location on the host so it has permission to write to it. 

In the example you will see down the line, there is a persistent volume configured in /home/vox/valhiem-data on the host. That directory is owned by the user "vox" which has a uid/gid of 1000. The steam user that gets created on the container also has a uid/gid of 1000. Next when the kubenetes pod is created (later in this guide), the containter is ran with the option fsgroup: 1000. What that will ensure is that all procesees inside the container are ran as uid/gid 1000. Since the volume at /home/vox/valheim-data is owned by a user with the same uid/gid, the container will be able to write to it.


```
RUN groupadd --gid 1000 steam

RUN useradd --uid 1000 --gid steam --shell /bin/bash --create-home steam

```
Next, the non-free debian repo is added and thats because steamcmd is non-free.

```
RUN apt-add-repository non-free

RUN apt-get update

```

Next we add i368 packages because one of the language libraries we use later down the line needs it added.

```
RUN dpkg --add-architecture i386

RUN apt-get update
```

We need to add an answer to the debconf datatbase with answers. The purpose of this, is that some packages require more then a YES or NO answer when they are being installed. steamcmd is such a package. An "I AGREE" answer needs to be given and the licence needs to be skipped to the next page, this will ensure that this is done properly when the package is installed.

```
RUN echo steam steam/question select "I AGREE" | debconf-set-selections

RUN echo steam steam/licence note '' | debconf-set-selections
```

Here we install steamcmd and lib32gcc1. Lib32gcc1 is required for when steamcmd installs valheim.

```
RUN apt-get -y install steamcmd lib32gcc1
```

Next, I am not entirely sure its required however steams own documentation reccordmend it. All I am doing here is creating a symlink between where the steamcmd binery sits and the steam users home directory.

```
RUN ln -s /usr/games/steamcmd /home/steam/steamcmd
```

Here we set the working directory as the /home/steam directory inside the container. This can be skipped if you wanted to use a full path for the next few commands but I just found it easier this way.

```
WORKDIR /home/steam
```

Next we copy over the entrypoint.sh script into the working directory we just set (ill go into what this does later on).

```
COPY entrypoint.sh entrypoint.sh
```

We need to make it executible (because its a script, duh)

```
RUN chmod +x entrypoint.sh
```

Next we do the same two things for the Installupdate.sh script

```

RUN chmod +x InstallUpdate.sh

RUN chown steam:steam InstallUpdate.sh

```

This next bit makes the docker container run everything as the steam user itself. Up until this point, its been doing everything as root. The next line will also make sure the working dir is still set.

```
USER steam
WORKDIR /home/steam
```

Next, for data to be persistent we must create a directory where data will run on the games first run. Normally this is taken care of by steamcmd running valheim for the first time but because we will be instructing kubernetes to mount the location where the game data is stored (remeber all data on a containter is lost when it terminates) we must create it before valheims dedicated server starts. If the directory does not exist when kubernetes tries to mount the persistant volume, it will cause and error and stop.

```
RUN mkdir -p /home/steam/.config/unity3d/IronGate/Valheim
```

The InstallUpdate.sh script is ran next. The contents of this script is below.

This command not only updates the game, but installs it. 

```
#!/bin/bash
/home/steam/steamcmd +@sSteamCmdForcePlatformType linux +login anonymous +force_install_dir /home/steam +app_update 896660 validate +quit
```

Here is the script running

```
RUN ./InstallUpdate.sh
```

We need to expose the ports the game will be running on to allow outside communication from the container. In this case, its UDP ports 2456-2458. The game strictly runs on 2456 because of the entrypoint script which you will see in a moment, but steam servers will also talk to the container on 2457 and 2458. It's used to probe the service to gather information, such as the server name. This is then used to list it on public server lists.

```
EXPOSE 2456-2458/udp
```

Lastly at the end of the docker file, we execute the entrypoint script. This is the script that starts when the container starts and if this process should terminate inside the container, the container will terminate. So if your container does not start, there is a good chance its having issues launching this script for some reason.

```
ENTRYPOINT ["./entrypoint.sh"]
```

