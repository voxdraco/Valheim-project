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

-----------------

Next I will go into the contents of the entrypoint.sh script.

The shbang is set to bash, not much to explain there. The three exports set some variables which steamcmd uses as it runs. Do not edit these. The appID is for valheim. 

```
#!/bin/bash
export templdpath=$LD_LIBRARY_PATH
export LD_LIBRARY_PATH=./linux64:$LD_LIBRARY_PATH
export SteamAppID=892970
```

The next line is a bit of a hack. All it does is make sure that when the entrypoint script is ran (when the container starts) it will make sure the game is up to date. This saves you having to rebuild the container and re-upload it to a registry whenever the game updates. NOTE: it will take a longer and longer amount of time to start the container due to this so it's still good practice to rebuild the container every so often.

```
/home/steam/steamcmd +@sSteamCmdForcePlatformType linux +login anonymous +force_install_dir /home/steam +app_update 896660 validate +quit
```

This next bit is what starts the actual dedicated server. You will notice that the name, port and password are set as ${EXAMPLE}. This is so we can set veriables in the kubernetes config later on. 

The -public 1 flag makes the server pulicaly avaiable on valheims server list. If you set it to 0, it wont show up.

```
/home/steam/valheim_server.x86_64 -name ${SERVERNAME} -port ${PORT} -world "Dedicated" -password ${PASSWORD} -public 1
export LD_LIBRARY_PATH=$templdpath
```

If you tried to run this container as is at the moment, it would fail. You need to change the enviroment veriables in the entrypoint script to something useable, however you can assign veriables on the same command when you lauch the container if you wish. That would get around it, for example:-

```
docker run --env VARIABLE1=foobar debian:buster env
```

Once you create this docker container (docker build -t valhiem-container .) you will need to upload it to a registry you have access too. You need to set this up yourself first to get this to work.

--------------------

Next we will look at the actual kuberntes yaml files bit by bit. This is where it can get a bit more complicated.

There are a few things you need to understand when creating and using a kubernetes file. Its a requirement that you assign an apiVersion, kind, metedata and spec.

A pod is the container that runs on the host, the host is reffered to as a node.

This kind of pod is going to be ran as a deployment with 1 replica. A deployment is a way of making the kubernetes scheduler make sure that this pod is always running. If it should fail, it will spin it back up. If you set more then 1 replica, it will spin up two containers inside the pod, but for this game that wont work. Infact it will break it. This is very advantageous for use in web development because if you wanted too you could create 10 replicas in one pod and all requests will de load balanced between them. If each container is serving the same static files or are running the same application and one container explodes, kubernetes will create a new container. 

```
apiVersion: apps/v1
kind: Deployment
metadata:
 name: valheim-server
spec:
 selector:
  matchLabels:
   name: valheim-server
   app: valheim-server
 replicas: 1
 template:
  metadata:
   labels:
    name: valheim-server
    app: valheim-server
```
