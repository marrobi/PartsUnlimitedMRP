echo $(SSHKey) > ~/.ssh/swarm_id

ssh -i ~/.ssh/swarm_id -f azureuser@$(SwarmMaster) -L 233750:(SwarmMaster):2375 -N