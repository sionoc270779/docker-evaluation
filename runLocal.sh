#!/bin/bash

# Use this script to deploy the docker image on the local machine.

# Swarm manager allows the service to be distributed to all machines inside the cluster, this gives better scalability etc. 
printf "Initializing Swarm Manager"
# --advertise-addr only needed if multiple NIC's or running docker out of virtual box which creates a virtual NIC
docker swarm init --advertise-addr 192.168.99.100

printf "Deploying Full Stack using compose file - Named port-tutorial"
docker stack deploy -c docker-compose.yml port-tutorial



