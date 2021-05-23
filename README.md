# deploy-k3s
```console
Author:   Bankole Ogundero
Date:     Wed 12-May-2021
Synopsis: This script will deploy a production grade k3s on ubuntu linux machines.
Note:     On the machine running this script, some folders will be created in the / (root) directory. This is normal. 
```

# Description
```console
DESCRIPTION:
    This script deploys a production grade k3s on several linux machines.
    The script assumes the same private key was used to create all the machines.
    The script assumes the target linux machines are ubuntu (for the package manager used will be apt-get)
    The script installs a secure etcd which will be used as the datastore for k3s. Ensure the nodes are in odd numbers (e.g. 3, 5, 7)
    The script also installs nginx and configures it as a load balancer (which will be the IP(s) used to the connect the cluster)
```

# Flags
```console
FLAGS:
    -mnips,   --masterNodeIps               Master Node IPs
    -anips,   --agentNodeIps                Agent Node IPs
    -nlbnips, --nginxLoadBalancerNodeIps    Nginx Load Balancer IPs (this will deploy nginx on the machines and configure it as a loadbalancer)
    -npkp,    --nodePrivateKeyPath          Full path to the Private key to ssh into the Master and Agent Nodes e.g. ~/.ssh/server.key
    -rmun     --remoteMachineUsername       The username that will be used to connect to each remote linux machine (this will be used in conjuction with the supplied IPs)
    -etcdv    --etcdVersion                 Set the version of etcd to deploy. If this is not set, a default version will be automatically chosen
    -k3sv     --k3sVersion                  Set the version of k3s to deploy. If this is not set, a default version will be automatically chosen
    -job      --job                         Use this flag in conjuction with the JOB_OPTIONS
    -h,       --help                        Display how to use this script.
```

# Job Options
```console
JOB_OPTIONS:
    ietcd,     installEtcd          This will install a complete production ready etcd. Certs will be generated, copied onto the etcd nodes and service started.
    uetcd,     uninstallEtcd        This will completely uninstall etcd on all instances and wipe any binaries as well as systemd entries
    ik3s,      installK3s           This will install production ready k3s on selected master and agent nodes. Etcd needs to be installed first. 
    upk3s,     upgradeK3s           Supply the k3s version (i.e. k3sv or k3sVersion) and k3s server and agents will be upgraded accordingly.
    uk3s,      installK3s           This will completely uninstall k3s completely by running the uninstall script that comes with the k3s deployment
    ingx,      installNginx         This will install configure and start nginx
    ungx,      uninstallNginx       This will stop, uninstall and purge nginx artifacts 
    iev,       installEverything    This will install k3s agents, masters and etcd and start the services respectively
    uev,       uninstallEverything  This will completely uninstall k3s agents, masters and etcd 
```

# Usage
```console
./deploy-k3s.sh -mnips "10.22.17.11 10.22.17.12 10.22.17.13" \
                -anips "10.22.17.14 10.22.17.15 10.22.17.16 10.22.17.17" \
                -nlbnips "10.22.17.10" \
                -npkp "/.ssh/id_rsa" \
                -rmun admin \
                -etcdv 3.4.10 \
                -k3sv 1.19.7 \
                -job installEverything
    
./deploy-k3s.sh --masterNodeIps "10.22.17.11 10.22.17.12 10.22.17.13" \
                --agentNodeIps "10.22.17.14 10.22.17.15 10.22.17.16 10.22.17.17" \
                --nginxLoadBalancerNodeIps "10.22.17.10" \
                --nodePrivateKeyPath "/.ssh/id_rsa" \
                --remoteMachineUsername admin \
                --etcdVersion 3.4.10 \
                --k3sVersion 1.19.7 \
                --job installEverything
```
