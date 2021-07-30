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

We need to add an answer to the debconf-set-selections file

```
RUN echo steam steam/question select "I AGREE" | debconf-set-selections

RUN echo steam steam/licence note '' | debconf-set-selections
```


