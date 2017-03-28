# Deploy using Docker, Azure Container Registry and Azure Container Service

This document describes how to set up an Azure Container Registry and an Azure Container Service Docker Swarm cluster on Microsoft Azure. We will also set up a Continuous Integration build (CI) that will allow us to build and run Docker images, inspect and scan containers, push Docker images to ACR and clean up build environment whenever the branch is updated.  

**Prerequisites**
- Complete the [Dockerizing Parts Unlimited MRP](https://microsoft.github.io/PartsUnlimitedMRP/adv/adv-21-Docker.html) lab

- An active Visual Studio Team Services (VSTS) account [Sign Up](https://www.visualstudio.com/en-us/docs/setup-admin/team-services/sign-up-for-visual-studio-team-services)

- You know how to set up Continuous Integration (CI) with Visual Studio Team Services (You don't? [Learn about CI]( https://microsoft.github.io/PartsUnlimitedMRP/fundvsts/fund-01-MS-CI.html))  

**Tasks Overview**

**1. Set up a Azure Container Registry** This will walk you through creating an Azure cCntainer Registry. It also demonstrates how to tag, push and pull your images.   

**2. Set up a Secured Continuous Integration (CI) with Visual Studio Team Services (VSTS)** Integrate Docker images and containers into your DevOps workflows using [Docker Integration](https://marketplace.visualstudio.com/items?itemName=ms-vscs-rm.docker) for Team Services. This Docker extension adds a task that enables you to build Docker images, push Docker images to Azure Container Registry, run Docker images or execute other operations offered by the Docker CLI.   

### Task 1: Create an Azure Container registry
**Step 1.** Create a resource group called `ContainerRegistry`.

```azurecli
az group create -n ContainerRegistry -l westeurope 
```


**Step 2.** Create a container registry
Run the `az acr create` command to create a container registry. 

> [!TIP]
> When you create a registry, specify a globally unique top-level domain name, containing only letters and numbers. The registry name in the examples is `my-registry`, but substitute a unique, lower case, name of your own. 
> 
> 

The following command creates container registry `my-registry` in the resource group `ContainerRegistry` in the West Europe location:

```azurecli
az acr create -n my-registry -g ContainerRegistry -l westeurope --admin-enabled true
```

* `--storage-account-name` or `-s` is optional. If not specified, a storage account is created with a random name in the specified resource group.


* `--admin-enabled` This enables admin login details for the registry. Custom service principles can be granted access and the default accoutn disabled.

The output is similar to the following:

```

{
  "adminUserEnabled": false,
  "creationDate": "2017-03-28T14:14:21.418885+00:00",
  "id": "/subscriptions/9999999-6032-4b50-884c-55cb9f074928/resourcegroups/ContainerRegistry/providers/Microsoft.ContainerRegistry/registries/myregistry",
  "location": "westeurope",
  "loginServer": "myregistry.azurecr.io",
  "name": "myregistry",
  "storageAccount": {
    "accessKey": null,
    "name": "myregistry1141344"
  },
  "tags": {},
  "type": "Microsoft.ContainerRegistry/registries"
}
```
Take special note:
 
* `loginServer` - The fully qualified name you specify to [log in to the registry](container-registry-authentication.md). In this example, the name is `myregistry.azurecr.io` (all lowercase).

**Step 3.** Retrieve login credentials for the registry:

```az acr credential show --name my-registry```

Record the `username` and `password` for later use. 

###Task 2: Configure Azure Container Service (ACS) running Docker Swarm

**Step 1.** Create a resource group called `SwarmCluster`.

```azurecli
az group create -n SwarmCluster -l westeurope 
```

**Step 4.** Deploy cluster running Docker Swarm

> [!TIP]
> When you create a cluster, specify a globally unique top-level domain name, containing only letters and numbers. The domain name in the examples is `my-cluster`, but substitute a unique, lower case, name of your own. 
> 
>
The following command uses the option ```--generate-ssh-keys```, this will use an existing SSH key within your profile, or if a key doesnt exist create a new one. This private key will be used later in the deployment process. If you do not want to use an existing private key please create and specify a new key pair and supply path to the public key using ```--ssh-key-value```.
> 

```azurecli

az acs create -n acs-cluster -g SwarmCluster -d my-cluster --orchestrator-type "Swarm"  --master-count 1 --agent-count 3 --generate-ssh-keys

``` 

Continue with the next task while ACS deploys. When complete please take note of the following values from the output JSON:

* agentFQDN
* masterFQDN


### Task 3: Set up a Secured Continuous Integration (CI) with Visual Studio Team Services (VSTS)  

The goal of this task is to build a Continuous Integration (CI) pipeline with Docker. The flow that we will setup is explained as follows:

1. Build: Build a Docker image.
2. Run: Create a running instance of the Docker image.
3. Inspect: Examine the software we build to ensure that they reach a high standard. The following tools are used:
   * [Docker Inspect](https://docs.docker.com/engine/reference/commandline/inspect/): Using the basic inspect command, a wealth of information (e.g., ports) about images and containers can be gathered.
   * [Docker Bench](https://github.com/docker/docker-bench-security): It is a script that checks for dozens of common best-practices around deploying Docker containers in production.
4. Push: After inspection, push your image to ACR as created in previous task.
5. Remove: Clean up the build environment by removing images and containers.

**Step 1.** Install [Docker Integration](https://marketplace.visualstudio.com/items?itemName=ms-vscs-rm.docker) for Visual Studio Team Services. This Docker extension adds a task that enables you to build Docker images, push Docker images to an authenticated Docker registry, run Docker images or execute other operations offered by the Docker CLI.

**Step 2.** After complete the [Dockerizing Parts Unlimited MRP](https://microsoft.github.io/PartsUnlimitedMRP/adv/adv-21-Docker.html) lab, please structure your directories and files as follows:    

```
PartsUnlimitedMRPDocker
├── src
    ├── Clients
    |   ├── Dockerfile
    |   └── drop    
    |        └── mrp.war
    ├── Database
    |   ├── Dockerfile
    |   └── drop
    |        └── MongoRecords.js
    ├── Order
    |   ├── Dockerfile
    |   └── drop
    |        ├── ordering-service-0.1.0.jar
    |        └── run.sh
    └── docker-compose.yml
    └── compose-token-replace.sh
```

1. Create **PartsUnlimitedMRPDocker** directory and **src** subdirectory.
2. Copy **Clients**, **Database** and **Order** created in [Dockerizing Parts Unlimited MRP](https://microsoft.github.io/PartsUnlimitedMRP/adv/adv-21-Docker.html) lab into the **src** directory.
3. Create a file named `docker-compose.yml` in the src folder with the following content:

```
version: "2"
services:
  db:
    image:  ${REPO_PREFIX}/database:${BUILD_BUILDNUMBER}
    ports:
      - 27017:27017
      - 28017:28017
    networks:
      - pu
  order:
    image:  ${REPO_PREFIX}/order:${BUILD_BUILDNUMBER}
    ports:
      - 8080:8080
    environment:
      - MONGO_PORT=tcp://db:27017
    depends_on: 
      - db
    networks:
      - pu
  web:
    image:  ${REPO_PREFIX}/clients:${BUILD_BUILDNUMBER}
    ports:
      - 80:8080
    depends_on: 
      - db
      - order
    networks:
      - pu
networks:
  pu: 
  


```

4. Create a file named `compose-token-replace.sh` with the following content  and place into the src folder:

```
sed -i -- 's/${REGISTRY_PREFIX}/'"$1"'/g' docker-compose.yml
sed -i -- 's/${BUILD_BUILDNUMBER}/'"$2"'/g' docker-compose.yml
```

**Step 3.** Go to your VSTS account’s homepage (e.g., https://`<account>`.visualstudio.com). Create a new PartsUnlimitedMRPDocker team project by clicking on the **New** button under Recent projects & teams. Type in the project name as **PartsUnlimitedMRPDocker** and select **Git** as the version control, then click on **Create project**:

![](<media/createteamproject.png>)

After the wizard creates your new team project, navigate to the PartsUnlimitedMRPDocker team project and click on the **Code** tab on the upper-left.

![](<media/browsetocode.png>)

The PartsUnlimitedMRPDocker Git repository will be empty, so copy the **Clone URL** of the VSTS repository to your clipboard and paste it into a text document for use later:

![](<media/cloneurl.png>)

Click on `Generate Git Credentials` and configure your git credentials.

Open your preferred command line tool, and change to **PartsUnlimitedMRPDocker** directory created earlier. Enter the following commands, and replace **clone-url** and **commit-message** with your **Clone URL** and message:
```
$ git init
$ git remote add origin <clone-url>
$ git add .
$ git commit -m <commit-message>
$ git push origin master
```  

Folders and files are now added into in your VSTS Git repository:

![](<media/projectstructure.png>)

**Step 4.** Go to your VSTS account’s homepage (e.g., https://<account>.visualstudio.com). Navigate to the **PartsUnlimitedMRPDocker** team project in VSTS.

![](<media/browsetoteamproject.png>)

**Step 5.** Create a Docker registry endpoint. In the **Settings** menu, select **Services**.

![](<media/servicespage.png>)

In the **New Service Endpoint** list, select **Docker Registry**.

![](<media/adddockerregistry.png>)

Enter the URL of your Azure Container Registry and login credentials created in previous task.

![](<media/enterdockerregistrydetails.png>)

**Step 6.** Create a new build definition. In the **Build & Release** menu, select **Builds**.

![](<media/addbuilddef.png>)

 Click the **+ New Definition** button or the **+ New** button, select **Empty**, and then click **Next >**.

![](<media/builddeftemplate.png>)

 Ensure the **Team Project** is selected as the **Repository source**, the appropriate repository (created in the previous step), and tick the **Continuous Integration** checkbox, select **Hosted Linux Preview** as the **Default agent queue**, then click **Create**.

![](<media/builddefconfig.png>)

 **Step 7.** Add a build step to build the **Clients** Docker image. Click on the **Build** tab, click **Add build step...**, and then click the **Add** button next to the Docker task. Docker task enables you to build, run, push Docker images or execute other operations offered by the Docker CLI.

![](<media/addstepforweb.png>)

Click the pencil icon to enter your preferred task name.

![](<media/edittaskname.png>)

Configure the task (e.g., Build Clients Image) as follows:

![](<media/configbuildclients.png>)

* **Docker Registry Connection**: Select the Docker registry endpoint created earlier.
* **Action**: Select **Build an image**.
* **Docker File**: Select the path to Docker file for your **Clients** Component.
* **Use Default Build Context**: Tick this checkbox. Set the build context to the directory that contains the Docker file.  
* **Image Name**: Enter the image name tagged with build number, **clients:$(Build.BuildId)**.
* **Qualify Image Name**: Tick this checkbox. Qualify the image name with the Docker registry connection's hostname.

**Step 8.** In the same Docker build task, add a build step to run the **clients** Docker image. Configure the Docker task (e.g., Run Clients Image) as follows:

![](<media/runclientimage.png>)

* **Docker Registry Connection**: Select the Docker registry endpoint created earlier.
* **Action**: Select **Run an image**.
* **Image Name**: Enter the image name (e.g., **clients:$(Build.BuildId)**) you wish to run.
* **Qualify Image Name**: Tick this checkbox. Qualify the image name with the Docker registry connection's hostname.
* **Container Name**: Enter your preferred container name (e.g., clients).
* **Ports**: Enter **80:8080**. Ports in the Docker container to publish to the host.


**Step 9.** Repeat the above steps for **order** (ports: 8080:8080) and **database** (ports: 27017:27017) components. 

**Step 10.** Add a build step to inspect the running Containers using [Docker Inspect](https://docs.docker.com/engine/reference/commandline/inspect/). Configure the Docker task (e.g., Inspect Clients Container) as follows:

![](<media/inspectclientscontainer.png>)

* **Action**: Select **Run a Docker command**.
* **Command**: Enter the following command line, and replace the container-name with your container name (e.g., clients,order,database):  

    ```
    inspect <container-name>
    ```

**Step 11.** Add a build step to scan security vulnerabilities using [Docker Bench for Security](https://github.com/docker/docker-bench-security). Configure the Docker task (e.g., Scan Security Vulnerabilities for Images and Containers) as follows:

![](<media/scansecurity.png>)

* **Action**: Select **Run a Docker command**.
* **Command**: Enter the following command line:  

    ```
    run --name dockerbenchsecurity --net host --pid host --cap-add audit_control -v /var/lib:/var/lib -v /var/run/docker.sock:/var/run/docker.sock -v /usr/lib/systemd:/usr/lib/systemd -v /etc:/etc --label docker_bench_security docker/docker-bench-security
    ```

**Step 12.** Add a build step to push the **Clients** image to ACR. Configure the Docker task (e.g., Push Clients Image to ACR) as follows:

![](<media/pushclientsimage.png>)



* **Docker Registry Connection**: Select the Docker registry endpoint created earlier.
* **Action**: Select **Push an image**.
* **Image Name**: Enter the image name (e.g., **clients:$(Build.BuildId)**) you wish to push.
* **Qualify Image Name**: Tick this checkbox. Qualify the image name with the Docker registry connection's hostname.

**Step 13.** Repeat the above step for **order**  and **database** components. 


**Step 14.** Add a build step ***Publish Build Artifacts** that that publishes the compose file as a build artifact so it can be used in the release. See the following screen for details.

* **Path to publish**: Browse to `/src/dockercompose.yml`
* **Artifact name**: `compose`
* **Artifact type**: `Server`


**Step 15.** Save the build definition, and then click the **Queue new build** button.

![](<media/saveandbuild.png>)

Select **Hosted Linux Preview** as **Queue**, **master** as **Branch**, and then click **OK**.

![](<media/queuebuildconfig.png>)

**Step 16.** Once the build is done, click on the build step **Inspect Clients Container** to view the inspection results for **Clients** container.

![](<media/inspectionresult.png>)

**Step 17.** Click on the build step **Scan Security Vulnerabilities for Images and Containers** to view the scan results for images and containers.

![](<media/scanresult.png>)


###Task 4: Configure deployment to Docker Swarm running on Azure Container Service 
VSTS task to deploy to Docker Swarm. We will use scripts and variables to carry out the deployment.

***Step 1.*** 
Create SSH endpoint. Click the Settings Cog | Services | New Service Endpoint | SSH. Enter the following details:


- **Connection Name**: Swarm Cluster
- **Host Name**: Master FQDN recorded earlier
- **Port**: 2222
- **User**: azureuser
- **Password**: leave blank
- **SSH Private Key**: copy contents of ```~/.ssh/id_rsa```


***Step 2.*** Click on `Releases` on the menu and then `+ New Definition`. Select `Empty`, click `Next`, and then chose the following options:

- **Project**: PartsUnlimitedMRP
- **Source (Build Definition)**: ???
- **Continous Deployment**: Checked
- **Queue**: Hosted Linux Preview

And click `Create`.

***Step 3.*** Create variables for the release process. Click Variables on the release menu.

- **docker.registry**: The URL of the Azure Container Registry created earlier.
- **docker.username**: The Azure Container Registry  username retrieved earlier.
- **docker.password**: The Azure Container Registry  passwordretrieved earlier earlier.

![](<media/release-variables.png>)

***Step 3.***  Configure a task to update ```docker-compose.yml`` with your registry name and the current build number. Click Environments | Add tasks | Utility | Shell Script | Add | Close. Configure as follows:

- **Script Path**: Browse to compose-token-replace.sh
- **Arguments**: $(docker.registry) $(Build.BuildNumber)

![](<media/compose-token-replace.png>)

***Step 4.*** Configure a task to securely copy the compose file to a deploy folder on the Docker Swarm master node, using the SSH connection you configured previously. Add tasks | Deploy | Copy files over SSH | Add | Close. Configure as follows:

- **SSH Endpoint**: SwarmCluster
- **Source Folder**: Browse to your compose artifacts directory
- **Contents**: docker-compose.yml
- **Target folder**: deploy

![](<media/sshcopy.png>)

***Step 5.*** Configure a second task to execute a bash command to run docker and docker-compose commands on the master node.  Add tasks | Deploy | SSH | Add | Close. Configure as follows:

- **SSH Endpoint**: SwarmCluster
- **Run**: Commands
- **Commands**: docker login -u $(docker.username) -p $(docker.password) $(docker.registry) && export DOCKER_HOST=:2375 && cd deploy && docker-compose pull && docker-compose stop && docker-compose rm -f && docker-compose up -d && docker exec deploy_db_1 mongo ordering /tmp/MongoRecords.js
- **Advanced: Fail on STDERR**: Uncheck

***Step 6.*** Check functionality

Trigger a new build by commiting a change to the PartsUnlimitedMRPDocker repository. Brown your applciation at http://agentFQDN/mrp , where agentFQDN is the vlaue recorded after the deployment fo your ACS Swarm cluster.

## Congratulations!

You've completed this HOL! In this lab, you have learned how to set up a Azure Container Service, Azure Contianer Registry, and integrate with Visual Studio Team Services.
