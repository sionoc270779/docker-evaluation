#!/bin/bash

# Use this script to deploy the docker image on the local machine.
 
# Swarm manager allows the service to be distributed to all machines inside the cluster, this gives better scalability etc. 
# --advertise-addr only needed if multiple NIC's or running docker out of virtual box which creates a virtual NIC.
# But lets always use the docker machine ip so even if you got 1 NIC or multiple it will always get the correct ip.
printf "Initializing Swarm Manager\n"
dockerMachineIP=$(docker-machine ip)
docker swarm init --advertise-addr $dockerMachineIP

printf "Deploying Full Stack using compose file - Named port-tutorial\n"
docker stack deploy -c docker-compose.yml port-tutorial

# Use regular expresion to find the services not running
regexPat="^[a-zA-Z0-9]+[:]Running.*" 

# Ensure the data is not split on spaces i.e. only on new line
IFS=$'\n'

while true
do
  printf "Checking the Docker Services are Running\n"
  for serviceID in $(docker service ps port-tutorial_web --format "{{.ID}}:{{.CurrentState}}");
  do 
    if ! [[ $serviceID =~ $regexPat ]]; then 
      printf "Service Is Not Running - "$serviceID | cut -f1 -d":";
    fi;
  done
  sleep 10;
done



