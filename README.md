# Valheim-project

Hello and welcome to my valheim project.

In this I will be going over simple project I worked on to spin up a valheim containter from scratch and how to get it working in kubernetes.

If you are attempting to do this yourself, you need to configure a kubernetes cluster yourself first AND a registry where the containters can sit. 


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

This next bit is important. When you first create a user in debian, it defaults to the user group 1000 and user ID 1000. This assures that its ALWAYS set to this for future prosparity. The reason gid/uid 1000 is important is because of the way kubernetes 


```
RUN groupadd --gid 1000 steam
```
