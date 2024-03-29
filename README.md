# Valheim-project

Hello and welcome to my valheim project.

In this I will be going over a simple project I worked on to spin up a valheim container from scratch and how to get it working in kubernetes.

If you are attempting to do this yourself, you need to configure a kubernetes cluster yourself first AND a registry where the containers can sit.

kubernetes cluster: https://www.virtualizationhowto.com/2021/06/kubernetes-home-lab-setup-step-by-step/

registry: https://www.linuxtechi.com/setup-private-docker-registry-kubernetes/

Who this is for:

People who are starting out. This container and kubernetes configuration are very simple and I attempt to keep it that way, however I do realize that there will be instances where I do things which might make you ask why and if this is the case, I will try and explain it.



-----------------

Requirements:

Docker
kubectl and a working kubernetes node/cluster

-----------------

I will go through the process and explain why I have done things the way I have. Please keep in mind this is the first time I have ever published a project like this on github.

Lets start off by going over the Dockerfile inside the docker-files directory as this is the first project thing you need to create if you want to use this, so from the top.

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

This next bit is important. When you first create a user in debian, it defaults to the user group 1000 and user ID 1000. This assures that its ALWAYS set to this for future prosperity. The reason gid/uid 1000 is important is because of the way kubernetes persistent data storage works. Valheim needs to save data, it goes without saying... but in order to do that the user ID and the GID MUST be the same as the persistent volumes location on the host so it has permission to write to it.

In the example you will see down the line, there is a persistent volume configured in /home/vox/valhiem-data on the host. That directory is owned by the user "vox" which has a uid/gid of 1000. The steam user that gets created on the container also has a uid/gid of 1000. Next when the kubernetes pod is created (later in this guide), the container is ran with the option fsgroup: 1000. What that will ensure is that all processes inside the container are ran as uid/gid 1000. Since the volume at /home/vox/valheim-data is owned by a user with the same uid/gid, the container will be able to write to it.


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

We need to add an answer to the debconf database with answers. The purpose of this, is that some packages require more then a YES or NO answer when they are being installed. steamcmd is such a package. An "I AGREE" answer needs to be given and the licence needs to be skipped to the next page, this will ensure that this is done properly when the package is installed.

```
RUN echo steam steam/question select "I AGREE" | debconf-set-selections

RUN echo steam steam/licence note '' | debconf-set-selections
```

Here we install steamcmd and lib32gcc1. Lib32gcc1 is required for when steamcmd installs valheim.

```
RUN apt-get -y install steamcmd lib32gcc1
```

Next, I am not entirely sure its required however steams own documentation recommend it. All I am doing here is creating a symlink between where the steamcmd binary sits and the steam users home directory.

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

We need to make it executable (because its a script, duh)

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

Next, for data to be persistent we must create a directory where data will run on the games first run. Normally this is taken care of by steamcmd running valheim for the first time but because we will be instructing kubernetes to mount the location where the game data is stored (remember all data on a container is lost when it terminates) we must create it before valheims dedicated server starts. If the directory does not exist when kubernetes tries to mount the persistent volume, it will cause and error and stop.

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

The shebang is set to bash, not much to explain there. The three exports set some variables which steamcmd uses as it runs. Do not edit these. The appID is for valheim.

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

This next bit is what starts the actual dedicated server. You will notice that the name, port and password are set as ${EXAMPLE}. This is so we can set variables in the kubernetes config later on.

The -public 1 flag makes the server publicly available on valheims server list. If you set it to 0, it wont show up.

```
/home/steam/valheim_server.x86_64 -name ${SERVERNAME} -port ${PORT} -world "Dedicated" -password ${PASSWORD} -public 1
export LD_LIBRARY_PATH=$templdpath
```

If you tried to run this container as is at the moment, it would fail. You need to change the environment variables in the entrypoint script to something usable, however you can assign variables on the same command when you launch the container if you wish. That would get around it, for example:-

```
docker run --env VARIABLE1=foobar debian:buster env
```

Once you create this docker container (docker build -t valhiem-container .) you will need to upload it to a registry you have access too. You need to set this up yourself first to get this to work.

--------------------

Next we will look at the actual kubernetes yaml files bit by bit. This is where it can get a bit more complicated.

The first one we look at is the valheim-deployment.yaml in the kubernetes directory.

There are a few things you need to understand when creating and using a kubernetes file. Its a requirement that you assign an apiVersion, kind, metadata and spec.

A pod is the container or group of containers that are defined to run in a config file, that runs on the host, the host is referred to as a node.

This kind of pod is going to be ran as a deployment with 1 replica. A deployment is a way of making the kubernetes scheduler make sure that this pod is always running. If it should fail, it will spin it back up. If you set more then 1 replica, it will spin up two containers inside the pod, but for this game that wont work. In fact it will break it. This is very advantageous for use in web development because if you wanted too you could create 10 replicas in one pod and all requests will be load balanced between them. If each container is serving the same static files or are running the same application and one container explodes, kubernetes will create a new container. The indentations need to be correct when you set this up and its very helpful to understand how yaml files work before you do this.

The app field needs to be consistent between there different bits of this pod because this is what it will target to to load balancing and connect services too.

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

I mentioned before that because this kubernetes cluster is going to use a persistent local volume, it needs to be able to write to the volume. The fsGroup needs to be set to 1000 for this to work. Please see my previous explanation on this on line 51.

```
  spec:
   securityContext:
    fsGroup: 1000
```

This bit below tells the node what the image name is and where its located. As you can see, my registry is located on a host called node01, and its listening on port 31320.  The image name is what I personally called mine when I pushed my finished docker container.

The pull policy here is a preference. If its set to always, whenever the container is launched the node will check with the registry to see if the image specified has the same digest as the one already pulled. If it's different, it will pull it again.

```
   containers:
    - image: node01:31320/valheim-server:1.0
      imagePullPolicy: Always
      name: valheim-server
```

Below are the environmental variables we need to set for our server. These were coded into the Dockerfile and here we set them, It's pretty self explanatory.

```
      env:
       - name: SERVERNAME
         value: "voxs-little-server"
       - name: PORT
         value: "2456"
       - name: PASSWORD
         value: "PASSWORD"
 ```
 Ports are also pretty self explanatory, this will tell the container what ports need to exposed, this is so network traffic can reach the container.
 
 NOTE: This should not be treated like a ACL, its nothing lie a proper firewall rule. containers can reach out to whatever they want using the hosts own networking. If you want to secure outbound traffic, you need to do it another way. This is purely so inbound traffic can get into the container. Also, you still need to set up a network service to do the rest of this. Exposing a port on its own is not enough so keep reading.
 
 ```
      ports:
       - containerPort: 2456
         name: gameport
       - containerPort: 2457
         name: queryport
```

Below we have set a resource limit and request on the total cpu and memory the container can use. A request is what the container is guaranteed to get. It will be reserved for it. You cannot have more requested resources then the node is capable of. For example if you have 12 gig of memory but request two containers are assigned 7 gig each, which ever pod starts first will get 7 gig, the next wont start at all.

Limits are simply a limit on how much a container is allowed to use. For example if you set a request for 1 gig but a limit at 4 gig of memory, if the container goes over 4 gig, it will be terminated.

Memory is easier to understand because its simply done in mebibytes (which is very similar to megabytes). CPU resources on the other hand are defined by millicores. 1 total cpu core is defined at 1000m, two cpu cores would be 2000m, 250m would equate to 1/4th of a single cpu core. Valheim is single threaded so there isnt any point in giving it more then 1 core, but is you are running more then 1 of these instances, its best to limit it.

By default a pod has no restrictions on memory and 100m cpu resources. Valheim doesn't need much unless there are a lot of players. I have been very generous with memory and cpu here. I didn't need to assign much but I wanted to make sure there was always enough if it ever got crowded.

```
      resources:
       requests:
        memory: "6000Mi"
        cpu: "500m"
       limits:
        memory: "6000Mi"
        cpu: "500m"
 ```
 
 This is where we define how our persistent storage works. Earlier on I mentioned that the dockerfile creates a directory so it can be mounted when the container starts and here is why we do this.
 
 the mountPath definition tells kubernetes where to mount a directory from inside the container itself. When you do this, you need to give the mount a name so the next section (volumes) will know what volume is going to be mounted from the host to this specified directory. In order to make this work, you need to create a volume claim which is something I will go into later on.
 
 It should be noted that the way I have done this, is bad practice for a production environment. For me, since this needs to be fast and its running on a physical server not in the cloud somewhere and there is only one node, this works fine for me. I just need to make sure its backed up because that is it's biggest weakness.

 You have several options when it comes to persistent data, the most popular one being a bucket in either aws, azure or gcp, but you can do others such as gluster, nfs and iscsi and many more. You will need to work out whats best for your use case.
 
 ```
       volumeMounts:
       - mountPath: /home/steam/.config/unity3d/IronGate/Valheim
         name: valheim-data
   volumes:
    - name: valheim-data
      persistentVolumeClaim:
       claimName: valheim-volume-claim
 ```

----------------------

Now we will look at the service definition file, (valheim-service.yaml)

There isn't much in here, so I can go over it all at once.

Kind needs to be set as Service, which will instruct kubernetes that this is a service, not a container. You need to set a name obviously.

If you remember, I set the ports in valheim to 2456 and 2457, both udp.

In kubernetes, you need to understand how traffic gets from the hosts interface to the container. Simply put, traffic doesn't just go into the hosts network interface and go straight to a container, it will instead hit the Kube-Proxy service then it will go to your container. There are a few additional steps it takes if you really want to drill down, such as how nodes send traffic to one another if a particular container exists elsewhere, or how it uses iptables but we dont need to know that for this.

What you need to understand for this is what nodePort, port, and targetPort mean.

The nodeport is the port the node (host) is going to be listening on or more specifically, where kube-proxy is listening on the node, the port is where kube-proxy sends traffic OUT from and the targetPort is where kube-proxy sends traffic too.

So in my example the valheim service is expecting traffic on port 31000 and 31001. This is because my gateway is port forwarding traffic from 2456 and 2457 to 31000 and 31001. Traffic reaches the node on 31000 and 31001 and then the service listening on that node, kube-proxy picks up that traffic. Kube-proxy then sends the traffic back out on port 2456 and 2457 respectively and sends it to port 2456 and 2457 on the target container. NOTE: there is a trap here. If you have more then one container, the port value MUST be different per pod. If you specify the same port, it will break because when the container responds to the port you specified it will cause a conflict. The kube-proxy will just send traffic back out of the node as instructed but you can't run multiple services on the same port, thats going to cause things to go wrong.

```
apiVersion: v1
kind: Service
metadata:
 name: valheim-server
spec:
 ports:
  - name: gameport
    nodePort: 31000
    port: 2456
    targetPort: 2456
    protocol: UDP

  - name: queryport
    nodePort: 31001
    port: 2457
    targetPort: 2457
    protocol: UDP


```
The LoadBalancer type is pretty self explanatory, it works like any load balancer. If you have multiple containers, it will just split traffic among them. The app value is what links this service to the deployment file we made earlier using the "app: valheim-server" label. Other then that, you dont need to worry much about this for the purposes we are using it.

```
 type: LoadBalancer
 selector:
  app: valheim-server
```

-------------------

The next file we will look at is the yaml file for the volume where the sames persistant data is stored.

In this file we need to specify that this is fot a persistent volume. As said earlier, there are many kinds of volume types. For our purposes, since we only have one node, we are using local as the type. This is how it sounds, the node will use local storage. You need to take note of the claim name in here for when you go to use it in a deployment and a volume claim (which I will go into shortly)

```
apiVersion: v1
kind: PersistentVolume
metadata:
 name: valheim-data
 labels:
  type: local
```

The storageClassName is basically a way of tagging a volume as a type you make up yourself. For example if you create a 10 volumes on a slow storage system, you could call it "slow" and then whenever you make a claim but do not reference a specific volume, it will take a pick from whatever you set here. If the claim is for a "slow" storage, it will pick one at random.

You can also use this (like I have) to target specific volumes, for example I called mine "manual", and if there is only one volume with this tag/name, it will only use that one.

capacity speaks for itself

accessModes sets what can access the volume and how many nodes/how. ReadWriteOnce means this volume can only be mounted by one node at a time, note that this is the only option for a single node.

The hostpath denotes where the actual data is going to sit on the host and where the volume is located. All data written to tgis volume by the container will land in /home/vox/valheim-data on the node.

```
 storageClassName: manual
 capacity:
  storage: 50Gi
 accessModes:
  - ReadWriteOnce
 hostPath:
  path: "/home/vox/valheim-data"
  
```

---------

We're almost there now, at the very end of the kubernetes files. We still have a bit more to cover however after.

This one is quite short, this is the volume-claim which needs to be defined inside the deployment yaml. 

The whole purpose of this yaml is to create a claim on an already existing volume which you can link to a pod. You will notice in the volume section of the deployment file it mentions just the volume claim and where the data will end up inside the container, it doesnt mention anything to do with the volume yaml itself.

The only bits you need to take note of here is the claim requests storage and the kind is different. Everything else is almost identical to a volume yaml. 


```
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
 name: valheim-volume-claim
spec:
 storageClassName: manual
 accessModes:
  - ReadWriteOnce
 resources:
  requests:
   storage: 50Gi
```

------------
So we have reached the and of the main guide. 

To do:-

Add instructions on how to set up automatic backups
