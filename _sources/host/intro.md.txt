# Introduction

## Hyperconverged Infrastructure

For a user, hyperconverged infrastructure is a platforms that runs
their machines/services on demand. That is orchestrated in real-time
instead of having somebody put a new computer into the datacenter the
next workday. The user pays not only for the variable resource usage
but also for high availability and storage redundancy.

For operators, this guide provides guidelines to prepare a deployment
that will allow to expand its capacities by simply adding more
machines.

In short, we understand Hyperconverged Infrastructure to be what
people expect in **Cloud Computing**, running on standard
off-the-shelf servers.


## Input/Output

The main goal is to run virtual machines regardless of the particular
host machine. To treat hosts equally, they must be configured
consistently -- a goal that is easy to achieve with Nix and NixOS!

The nixosModule for hosts is the most important component of Skyflake.


### Persistent Storage

Services are sometimes stateful, for example with a database system
that persists its data to disk. That means that virtual machines must
always be able to access its storage, regardless of the server they
are started on.

We solve this problem by moving the VM filesystems to a network
filesystem: Ceph.


### Network Setup

Networks should be designed properly so that you don't end up with
docker-style port forwarding. Therefore this topic is left open to you
intentionally. We just provide ideas here.

By bridging everything at layer 2 you get ultimate location
transparency at limited scalability. Better use a VLAN per user.

When bridging network segments over L3 tunnels (VXLAN, OpenVPN with
tap), the MTU must be lowered on all hosts on that segment.

The same could be achieved by distributing routing information of all
individual MicroVM addresses at layer 3 at the price of memory usage.


## About MicroVMs

When consolidating systems into virtualized machines, a lot of people
think in terms of containers. We agree that a single OS kernel can be
more efficient and ecological, but the attack surface is larger than
in proper virtualization.

Virtualization on the other hand is hardware-accelerated in mainstream
CPUs since 2005. MicroVMs enhance I/O by replacing emulated hardware
with *virtio* interfaces that are optimized for the virtualization
scenario.

Skyflake's primary target is running Virtual Machines in one of the
hypervisors supported by
[microvm.nix](https://github.com/astro/microvm.nix).
