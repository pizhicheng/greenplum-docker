# Dockerfile for Greenplum

​    This is a project to building a docker image for Greenplum database. 

## Build

You can run

```
docker build -t greenplum:6.0.1 -f Dockerfile-singlenode .
```

to build a normal greenplum image.

You can add --build-arg  to configure your database. Below are available build argument and default value:

```
GP_VERSION=6.0.1   (only suport 6.0.1 now)
username=gpadmin
userpassword=gpadmin
MASTER_DIRECTORY=/data/greenplum/gpmaster
DATA_DIRECTORY=/data/greenplum/gpdata
MIRROR_DIRECTORY=/data/greenplum/gpmirror
PGPORT=5432
```

## Run

You can run command

```
docker run --privileged -v `pwd`/data:/data/greenplum greenplum:6.0.1 -n 8 -h 192.168.0.0/16 -m
```

to start a greenplum which has **8** segment, **enable mirror** and can be connected by ip in range **192.168.0.0 ~ 192.168.256.256**. Below are available argument and meaning.

```
-n number        :segment number
-h host          :visible host
-m               :enable mirror
```

*Warning: to make system configuration available --privileged option must be set. Otherwise database may open fail in some environment*

## What's more

​    Now this project only support a single node greenplum database.  I still have not found a good way to make greenplum to scale node with several option configuration, so multi-node greenplum are still on my future task list.

​    I'll be grateful, if you have any suggestion or good idea to share with me.