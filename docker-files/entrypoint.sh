#!/bin/bash
export templdpath=$LD_LIBRARY_PATH
export LD_LIBRARY_PATH=./linux64:$LD_LIBRARY_PATH
export SteamAppID=892970

/home/steam/steamcmd +@sSteamCmdForcePlatformType linux +login anonymous +force_install_dir /home/steam +app_update 896660 validate +quit


/home/steam/valheim_server.x86_64 -name ${SERVERNAME} -port ${PORT} -world "Dedicated" -password ${PASSWORD} -public 1
export LD_LIBRARY_PATH=$templdpath
