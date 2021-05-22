#!/bin/bash
# Authors: Bankole Ogundero
# Date: Wed 12-May-2021

CFSSL_DOWNLOAD_URL="https://pkg.cfssl.org/R1.2/cfssl_linux-amd64"
CFSSL_JSON_DOWNLOAD_URL="https://pkg.cfssl.org/R1.2/cfssljson_linux-amd64"
ETCD_DOWNLOAD_URL="https://storage.googleapis.com/etcd"
ETCD_FOLDER="/etcd"
ETCD_CERTS_FOLDER="$ETCD_FOLDER/certs"
ETCD_DATA_FOLDER="$ETCD_FOLDER/data"
SYSTEMD_LIB_SYSTEM_PATH="/lib/systemd/system"
K3S_FOLDER="/k3s"
NGINX_CONF_PATH="/nginx-conf"
DEFAULT_ETCD_VERSION="3.4.10"
DEFAULT_K3S_VERSION="1.19.7"
TIME_TO_WAIT="5" # seconds

# usage
# function that will display how to use this script
function usage {
    cat 1>&2 <<EOF
Author:   Bankole Ogundero
Date:     Wed 12-May-2021
Synopsis: This script will deploy a production grade k3s on ubuntu linux machines.
Note:     On the machine running this script, some folders will be created in the / directory. This is normal. 

DESCRIPTION:
    This script deploys a production grade k3s on several linux machines.
    The script assumes the same private key was used to create all the machines.
    The script assumes the target linux machines are ubuntu (for the package manager used will be apt-get)
    The script installs a secure etcd which will be used as the datastore for k3s. Ensure the nodes are in odd numbers (e.g. 3, 5, 7)
    The script also installs nginx and configures it as a load balancer (which will be the IP(s) used to the connect the cluster)

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

USAGE:
    ./deploy-k3s.sh --masterNodeIps "10.22.17.11 10.22.17.12 10.22.17.13" --agentNodeIps "10.22.17.14 10.22.17.15 10.22.17.16 10.22.17.17" --nginxLoadBalancerNodeIps "10.22.17.10" --nodePrivateKeyPath "/.ssh/id_rsa" --remoteMachineUsername admin --etcdVersion 3.4.10 --k3sVersion 1.19.7 --job installEverything
    ./deploy-k3s.sh --masterNodeIps "10.22.17.11 10.22.17.12 10.22.17.13" --agentNodeIps "10.22.17.14 10.22.17.15 10.22.17.16 10.22.17.17" --nginxLoadBalancerNodeIps "10.22.17.10" --nodePrivateKeyPath "/.ssh/id_rsa" --remoteMachineUsername admin --etcdVersion 3.4.10 --k3sVersion 1.19.7 --job uninstallEverything

    ./deploy-k3s.sh --mnips "10.22.17.11 10.22.17.12 10.22.17.13" \\
                    --anips "10.22.17.14 10.22.17.15 10.22.17.16 10.22.17.17" \\
                    --nlbnips "10.22.17.10" \\
                    --npkp "/.ssh/id_rsa" \\
                    --rmun admin \\
                    --etcdv 3.4.10 \\
                    --k3sv 1.19.7 \\
                    --job installEverything
    
    ./deploy-k3s.sh --masterNodeIps "10.22.17.11 10.22.17.12 10.22.17.13" \\
                    --agentNodeIps "10.22.17.14 10.22.17.15 10.22.17.16 10.22.17.17" \\
                    --nginxLoadBalancerNodeIps "10.22.17.10" \\
                    --nodePrivateKeyPath "/.ssh/id_rsa" \\
                    --remoteMachineUsername admin \\
                    --etcdVersion 3.4.10 \\
                    --k3sVersion 1.19.7 \\
                    --job installEverything
    
    ./deploy-k3s.sh --masterNodeIps "10.22.17.11 10.22.17.12 10.22.17.13" \\
                    --agentNodeIps "10.22.17.14 10.22.17.15 10.22.17.16 10.22.17.17" \\
                    --nginxLoadBalancerNodeIps "10.22.17.10" \\
                    --nodePrivateKeyPath "/.ssh/id_rsa" \\
                    --remoteMachineUsername admin \\
                    --etcdVersion 3.4.10 \\
                    --k3sVersion 1.19.7 \\
                    --job uninstallEverything
EOF
}

# while loop that will process incoming arguments to the script and shift to the next
while [ "$1" != "" ]; do
    case $1 in
        -mnips   | --masterNodeIps)             shift
                                                MASTER_NODE_IPS=$1
                                                ;;
        -anips   | --agentNodeIps)              shift
                                                AGENT_NODE_IPS=$1
                                                ;;
        -nlbnips | --nginxLoadBalancerNodeIps)  shift
                                                NGINX_LOAD_BALANCER_NODE_IPS=$1
                                                ;;
        -npkp    | --nodePrivateKeyPath)        shift
                                                NODE_PRIVATE_KEY_PATH=$1
                                                ;;
        -rmun    | --remoteMachineUsername)     shift
                                                REMOTE_MACHINE_USERNAME=$1
                                                ;;
        -etcdv   | --etcdVersion)               shift
                                                ETCD_VERSION=$1
                                                ;;
        -k3sv    | --k3sVersion)                shift
                                                K3S_VERSION=$1
                                                ;;
        -job     | --job)                       shift
                                                JOB_TYPE=$1
                                                ;;
        -h       | --help)                      usage
                                                exit 1
    esac
    shift
done

if [ -z "$MASTER_NODE_IPS" ]; then
    usage
    echo ""
    echo "Please provide the IP(s) of the master nodes"
    echo "e.g. \"192.168.0.1 192.168.0.2 192.168.0.3\""
    echo ""
    exit 1
fi

if [ -z "$AGENT_NODE_IPS" ]; then
    usage
    echo ""
    echo "Please provide the IP(s) of the agent nodes"
    echo "e.g. \"192.168.0.4 192.168.0.5 192.168.0.6\""
    echo ""
    exit 1
fi

if [ -z "$NODE_PRIVATE_KEY_PATH" ]; then
    usage
    echo ""
    echo "Please supply the path to the private key that will be used to connect to the nodes"
    echo "e.g. \"./path/to/private.key\""
    echo "e.g. \"/.ssh/id_rsa\""
    echo ""
    exit 1
fi

if [ -z "$REMOTE_MACHINE_USERNAME" ]; then
    usage
    echo ""
    echo "Please supply the username that will be used to connect to the remote machines."
    echo "This will be used in conjuction with the supplied IP (e.g. admin@192.168.0.1)"
    echo "e.g. admin"
    echo ""
    exit 1
fi

if [ -z "$ETCD_VERSION" ]; then
    echo ""
    echo "ETCD_VERSION not provided. Will use the default $DEFAULT_ETCD_VERSION"
    ETCD_VERSION=$DEFAULT_ETCD_VERSION
    echo ""
fi

if [ -z "$K3S_VERSION" ]; then
    echo ""
    echo "K3S_VERSION not provided. Will use the default $DEFAULT_K3S_VERSION"
    K3S_VERSION=$DEFAULT_K3S_VERSION
    echo ""
fi

# installCloudFlareSsl
# function that will check if cfssl is installed and 
function installCloudFlareSsl {
    echo "Installing cfssl..."
    sudo curl -s -L -o /usr/bin/cfssl $CFSSL_DOWNLOAD_URL

    echo "Installing cfssljson..."
    sudo curl -s -L -o /usr/bin/cfssljson $CFSSL_JSON_DOWNLOAD_URL

    echo "Making binaries executable..."
    sudo chmod +x /usr/bin/cfssl
    sudo chmod +x /usr/bin/cfssljson
}

# createEtcdFolders
# function to create folders
# Calling this function and passing "recreate" will delete the etcd folder and create it again.
function createEtcdFolders {
    # Create etcd certs folder
    if [ ! -d $ETCD_CERTS_FOLDER ]; then
        echo "Creating folders $ETCD_CERTS_FOLDER..."
        sudo mkdir -p $ETCD_CERTS_FOLDER
        sudo chmod -R 777 $ETCD_CERTS_FOLDER
    fi

    # Create etcd data folder
    if [ ! -d $ETCD_DATA_FOLDER ]; then
        echo "Creating folders $ETCD_DATA_FOLDER..."
        sudo mkdir -p $ETCD_DATA_FOLDER
        sudo chmod -R 777 $ETCD_DATA_FOLDER
    fi
}

# checkPrograms
# function to check for certain programs on the machine.
# If program cannot be found, it'll exit using exit code 1
function checkPrograms {
    program=$1
    if [ $(which $program | wc -l) -ne 1 ]; then
        echo ""
        echo "$program is not installed."
        echo "Please ensure you install it depending on your linux distro."
        echo ""
        exit 1
    fi
}

# checkIfIpsAreReachable
# function to check if the IPs supplied can be reached. This will use netcat.
function checkIfIpsAreReachable {
    serverType=$1

    # NGINX LOAD BALANCER NODES
    if [ $serverType = "nginxNodes" ]; then
        for ip in ${NGINX_LOAD_BALANCER_NODE_IPS[@]}; do
            echo "ping -c 1 $ip | grep icmp* | wc -l"
            count=$( ping -c 1 $ip | grep icmp* | wc -l )
            if [ $count -eq 0 ]; then
                echo "Cannot reach nginx load balancer node: $ip"
                exit 1
            fi
        done
    fi

    # MASTER NODES
    if [ $serverType = "masterNodes" ]; then
        for ip in ${MASTER_NODE_IPS[@]}; do
            echo "ping -c 1 $ip | grep icmp* | wc -l"
            count=$( ping -c 1 $ip | grep icmp* | wc -l )
            if [ $count -eq 0 ]; then
                echo "Cannot reach master node: $ip"
                exit 1
            fi
        done
    fi

    # AGENT NODES
    if [ $serverType = "agentNodes" ]; then
        for ip in ${AGENT_NODE_IPS[@]}; do
            echo "ping -c 1 $ip | grep icmp* | wc -l"
            count=$( ping -c 1 $ip | grep icmp* | wc -l )
            if [ $count -eq 0 ]; then
                echo "Cannot reach agent node: $ip"
                exit 1
            fi
        done
    fi
}

# checkDirectory
# function that will make a directory and set open permissions.
function checkDirectory {
    folder=$1
    if [ ! -d $folder ]; then
        sudo mkdir -p $folder
        sudo chmod -R 777 $folder
    fi
}

# checkPrequisites
# function to check prequisites on machine before deploying
function checkPrequisites {
    # Check if certain linux binaries are available
    echo "Checking if programs are available..."
    checkPrograms "scp"
    checkPrograms "ssh"
    checkPrograms "curl"
    checkPrograms "ping"

    echo "Checking if IPs can be reached..."
    checkIfIpsAreReachable "nginxNodes"
    checkIfIpsAreReachable "masterNodes"
    checkIfIpsAreReachable "agentNodes"

    # Check if directories exist
    checkDirectory "$ETCD_FOLDER"
    checkDirectory "$ETCD_CERTS_FOLDER"
    checkDirectory "$ETCD_DATA_FOLDER"
    checkDirectory "$K3S_FOLDER"
    checkDirectory "$NGINX_CONF_PATH"

    # Check if cfssl is installed and install it if not present
    if [ $(which cfssl | wc -l) -ne 1 ]; then
        echo ""
        echo "CloudFlare SSL is not installed."
        echo "Installing. Please wait..."
        installCloudFlareSsl
        echo "Done."
        echo ""
    fi

    # Check if etcdFolder directory exists and create if it does not.
    if [ ! -d $ETCD_FOLDER ]; then
        echo ""
        echo "Cannot find $ETCD_FOLDER"
        echo "Creating. Please wait..."
        createEtcdFolders
        echo "Done."
        echo ""
    fi

    # Make set the right permissions for private key
    sudo chmod -R 600 $NODE_PRIVATE_KEY_PATH
}

# generateCaCerts
# function that will generate CA certs for etcd.
# The certs will have an rsa size of 4096 and will last for 10 years.
function generateCaCerts {
    echo "Certs will be generated in $ETCD_CERTS_FOLDER"
    cd $ETCD_CERTS_FOLDER
    echo '{"CN":"CA","key":{"algo":"rsa","size":4096}}' | cfssl gencert -initca - | cfssljson -bare ca -
    echo '{"signing":{"default":{"expiry":"87600h","usages":["signing","key encipherment","server auth","client auth"]}}}' > ca-config.json
}

# generateEtcdInitialClusterTextString
# function that will loop through the Master Node IPs and 
# generate a string compatible with etcd leaving out the last comma
function generateEtcdInitialClusterTextString {
    idx=0
    for ip in ${MASTER_NODE_IPS[@]}; do 
        echo "Agent Node IPs $idx: $ip"
        ETCD_INITIAL_CLUSTER+="node-$idx=https://$ip:2380,"
        idx=$((idx + 1))
    done
    # Trim trailing comma
    ETCD_INITIAL_CLUSTER=$(echo -n $ETCD_INITIAL_CLUSTER | head -c -1)
}

# generateCertsForEachEtcdNode
# function that will iterate over the Master Node IPs 
# and generate the appropriate etcd cert configs.
function generateCertsForEachEtcdNode {
    # Populate the ETCD_INITIAL_CLUSTER with the correct values
    generateEtcdInitialClusterTextString

    cd $ETCD_CERTS_FOLDER
    idx=0
    for ip in ${MASTER_NODE_IPS[@]}; do 
        echo ""
        echo "Generating cert for node-$idx: $ip"
        echo "Please wait..."
        NAME="node-$idx"
        ADDRESS=$ip,$NAME
        echo '{"CN":"'$NAME'","hosts":[""],"key":{"algo":"rsa","size":4096}}' | cfssl gencert -config=ca-config.json -ca=ca.pem -ca-key=ca-key.pem -hostname="$ADDRESS" - | cfssljson -bare $NAME
        if [ ! -d "$ETCD_CERTS_FOLDER/$ip" ]; then
            sudo mkdir -p "$ETCD_CERTS_FOLDER/$ip"
            sudo chmod -R 777 "$ETCD_CERTS_FOLDER/$ip"
        fi
        # Move generated certs specific to this node into the node folder
        # Copy also the certificate pem file
        sudo mv $NAME-key.pem "$ETCD_CERTS_FOLDER/$ip"
        sudo mv $NAME.pem "$ETCD_CERTS_FOLDER/$ip"
        sudo mv $NAME.csr "$ETCD_CERTS_FOLDER/$ip"
        sudo cp ca.pem "$ETCD_CERTS_FOLDER/$ip"
        cd "$ETCD_CERTS_FOLDER/$ip"

        # Rename the certs for consistency.
        # The names will be the same for each node.
        sudo mv ca.pem etcd-ca.crt
        sudo mv $NAME.pem server.crt
        sudo mv $NAME-key.pem server.key

        # Set appropriate permissions for certs 
        # otherwise an error will be thrown.
        sudo chmod -R 600 etcd-ca.crt
        sudo chmod -R 600 server.crt
        sudo chmod -R 600 server.key

        # Generate etcd config specific to this node
        cat 1>&2 <<EOF > "$ETCD_CERTS_FOLDER/$ip/etcd.conf"
ETCD_NAME=$NAME
ETCD_LISTEN_PEER_URLS="https://$ip:2380"
ETCD_LISTEN_CLIENT_URLS="https://$ip:2379"
ETCD_INITIAL_CLUSTER_TOKEN="etcd-cluster"
ETCD_INITIAL_CLUSTER="$ETCD_INITIAL_CLUSTER"
ETCD_INITIAL_ADVERTISE_PEER_URLS="https://$ip:2380"
ETCD_ADVERTISE_CLIENT_URLS="https://$ip:2379"
ETCD_TRUSTED_CA_FILE=$ETCD_CERTS_FOLDER/$ip/etcd-ca.crt
ETCD_CERT_FILE="$ETCD_CERTS_FOLDER/$ip/server.crt"
ETCD_KEY_FILE="$ETCD_CERTS_FOLDER/$ip/server.key"
ETCD_PEER_CLIENT_CERT_AUTH=true
ETCD_PEER_TRUSTED_CA_FILE=$ETCD_CERTS_FOLDER/$ip/etcd-ca.crt
ETCD_PEER_KEY_FILE=$ETCD_CERTS_FOLDER/$ip/server.key
ETCD_PEER_CERT_FILE=$ETCD_CERTS_FOLDER/$ip/server.crt
ETCD_DATA_DIR=$ETCD_DATA_FOLDER
ETCD_INITIAL_CLUSTER_STATE="new"
EOF
        echo ""
        echo "Done"
        echo ""

        # Generate etcd config specific to this node
        cat 1>&2 <<EOF > "$ETCD_CERTS_FOLDER/$ip/etcd.conf.yaml"
# This is the configuration file for the etcd server.

# Human-readable name for this member.
name: $NAME

# Path to the data directory.
data-dir: $ETCD_DATA_FOLDER

# Path to the dedicated wal directory.
# wal-dir: $ETCD_DATA_FOLDER
wal-dir:

# Number of committed transactions to trigger a snapshot to disk.
snapshot-count: 10000

# Time (in milliseconds) of a heartbeat interval.
heartbeat-interval: 100

# Time (in milliseconds) for an election to timeout.
election-timeout: 1000

# Raise alarms when backend size exceeds the given quota. 0 means use the
# default quota.
quota-backend-bytes: 0

# List of comma separated URLs to listen on for peer traffic.
listen-peer-urls: https://$ip:2380

# List of comma separated URLs to listen on for client traffic.
listen-client-urls: https://$ip:2379

# Maximum number of snapshot files to retain (0 is unlimited).
max-snapshots: 5

# Maximum number of wal files to retain (0 is unlimited).
max-wals: 5

# Comma-separated white list of origins for CORS (cross-origin resource sharing).
cors:

# List of this member's peer URLs to advertise to the rest of the cluster.
# The URLs needed to be a comma-separated list.
initial-advertise-peer-urls: https://$ip:2380

# List of this member's client URLs to advertise to the public.
# The URLs needed to be a comma-separated list.
advertise-client-urls: https://$ip:2379

# Discovery URL used to bootstrap the cluster.
discovery:

# Valid values include 'exit', 'proxy'
discovery-fallback: 'proxy'

# HTTP proxy to use for traffic to discovery service.
discovery-proxy:

# DNS domain used to bootstrap initial cluster.
discovery-srv:

# Initial cluster configuration for bootstrapping.
initial-cluster: $ETCD_INITIAL_CLUSTER

# Initial cluster token for the etcd cluster during bootstrap.
initial-cluster-token: etcd-cluster

# Initial cluster state ('new' or 'existing').
initial-cluster-state: 'new'

# Reject reconfiguration requests that would cause quorum loss.
strict-reconfig-check: false

# Accept etcd V2 client requests
enable-v2: true

# Enable runtime profiling data via HTTP server
enable-pprof: true

# Valid values include 'on', 'readonly', 'off'
proxy: 'off'

# Time (in milliseconds) an endpoint will be held in a failed state.
proxy-failure-wait: 5000

# Time (in milliseconds) of the endpoints refresh interval.
proxy-refresh-interval: 30000

# Time (in milliseconds) for a dial to timeout.
proxy-dial-timeout: 1000

# Time (in milliseconds) for a write to timeout.
proxy-write-timeout: 5000

# Time (in milliseconds) for a read to timeout.
proxy-read-timeout: 0

client-transport-security:
  # Path to the client server TLS cert file.
  cert-file: $ETCD_CERTS_FOLDER/$ip/server.crt

  # Path to the client server TLS key file.
  key-file: $ETCD_CERTS_FOLDER/$ip/server.key

  # Enable client cert authentication.
  client-cert-auth: true

  # Path to the client server TLS trusted CA cert file.
  trusted-ca-file: $ETCD_CERTS_FOLDER/$ip/etcd-ca.crt

  # Client TLS using generated certificates
  auto-tls: true

peer-transport-security:
  # Path to the peer server TLS cert file.
  cert-file: $ETCD_CERTS_FOLDER/$ip/server.crt

  # Path to the peer server TLS key file.
  key-file: $ETCD_CERTS_FOLDER/$ip/server.key

  # Enable peer client cert authentication.
  client-cert-auth: true

  # Path to the peer server TLS trusted CA cert file.
  trusted-ca-file: $ETCD_CERTS_FOLDER/$ip/etcd-ca.crt

  # Peer TLS using generated certificates.
  auto-tls: true

# Enable debug-level logging for etcd.
debug: false

logger: zap

# Specify 'stdout' or 'stderr' to skip journald logging even when running under systemd.
log-outputs: [stderr]

# Force to create a new one member cluster.
force-new-cluster: false

auto-compaction-mode: periodic
auto-compaction-retention: "1"
EOF
        echo ""
        echo "Done"
        echo ""
        cd $ETCD_CERTS_FOLDER
        idx=$((idx + 1))
    done
}

# generateScriptToInstallEtcdOnMasterNodes
# function to generate the script that will be copied
# to the master nodes and run them.
function generateScriptToInstallEtcdOnMasterNodes {
    nodeIp=$1
    sudo touch $ETCD_FOLDER/install-etcd.sh
    sudo chmod -R 777 $ETCD_FOLDER/install-etcd.sh

    cat 1>&2 <<EOF > "$ETCD_FOLDER/install-etcd.sh"
#!/bin/bash
# create essential etcd folder if they don't exist.
if [ ! -d $ETCD_FOLDER ]; then
    sudo mkdir -p $ETCD_FOLDER
    sudo chmod -R 777 $ETCD_FOLDER
    sudo chown -R $REMOTE_MACHINE_USERNAME:$REMOTE_MACHINE_USERNAME $ETCD_FOLDER

    sudo mkdir -p $ETCD_CERTS_FOLDER/$nodeIp
    sudo chown -R $REMOTE_MACHINE_USERNAME:$REMOTE_MACHINE_USERNAME $ETCD_CERTS_FOLDER
    sudo chown -R $REMOTE_MACHINE_USERNAME:$REMOTE_MACHINE_USERNAME $ETCD_CERTS_FOLDER/$nodeIp

    sudo mkdir -p $ETCD_DATA_FOLDER
    sudo chown -R $REMOTE_MACHINE_USERNAME:$REMOTE_MACHINE_USERNAME $ETCD_DATA_FOLDER

    sudo mkdir -p $ETCD_DATA_FOLDER/member/snap
    sudo chown -R $REMOTE_MACHINE_USERNAME:$REMOTE_MACHINE_USERNAME $ETCD_DATA_FOLDER/member/snap
    sudo touch $ETCD_DATA_FOLDER/member/snap/db

    # etcd will complain if the permission is not set to 700
    sudo chmod -R 700 $ETCD_DATA_FOLDER
fi

# Install etcd if not installed.
if [ \$(which etcd | wc -l) -ne 1 ]; then
    # Install etcd 
    echo "Removing etcd archive (if exists)..."
    rm -f /tmp/etcd-v${ETCD_VERSION}-linux-amd64.tar.gz

    echo "Removing temporary folder that will hold the etcd archive..."
    rm -rf /tmp/etcd-download-test

    echo "Making new temporary folder that will hold the etcd archive..."
    mkdir -p /tmp/etcd-download-test

    echo "Using curl to fetch the etcd archive..."
    curl -L ${ETCD_DOWNLOAD_URL}/v${ETCD_VERSION}/etcd-v${ETCD_VERSION}-linux-amd64.tar.gz -o /tmp/etcd-v${ETCD_VERSION}-linux-amd64.tar.gz

    echo "Unpacking the etcd tar.gz file..."
    tar xzvf /tmp/etcd-v${ETCD_VERSION}-linux-amd64.tar.gz -C /tmp/etcd-download-test --strip-components=1

    echo "Removing the etcd tar.gz file to save space..."
    rm -f /tmp/etcd-v${ETCD_VERSION}-linux-amd64.tar.gz

    echo "Making binaries executable..."
    chmod +x /tmp/etcd-download-test/etcd
    chmod +x /tmp/etcd-download-test/etcdctl 

    echo "Verifying downloads..."
    echo "etcd --version"
    /tmp/etcd-download-test/etcd --version
    echo "etcdctl --version"
    /tmp/etcd-download-test/etcdctl version

    echo "Moving binaries to /usr/local/bin..."
    sudo mv /tmp/etcd-download-test/etcd /usr/local/bin
    sudo mv /tmp/etcd-download-test/etcdctl /usr/local/bin
fi

EOF
    echo ""
    echo "------------------------------------------"
    echo "Generated etcd script for $nodeIp"
    echo "------------------------------------------"
    cat "$ETCD_FOLDER/install-etcd.sh"
    echo ""
}

# installEtcdOnRemoteMasterNodes
# function to install etcd on remote master nodes
function installEtcdOnRemoteMasterNodes {
    for ip in ${MASTER_NODE_IPS[@]}; do 
        echo ""
        echo "Generating etcd install script for $ip"
        generateScriptToInstallEtcdOnMasterNodes "$ip"
        echo ""

        echo ""
        echo "Copying etcd install script to $ip"
        echo "sudo scp -o StrictHostKeyChecking=accept-new -i $NODE_PRIVATE_KEY_PATH $ETCD_FOLDER/install-etcd.sh $REMOTE_MACHINE_USERNAME@$ip:/tmp/"
        sudo scp -o StrictHostKeyChecking=accept-new -i $NODE_PRIVATE_KEY_PATH $ETCD_FOLDER/install-etcd.sh $REMOTE_MACHINE_USERNAME@$ip:/tmp/
        echo ""

        echo ""
        echo "Running etcd install script on $ip"
        echo "ssh -o StrictHostKeyChecking=accept-new -i $NODE_PRIVATE_KEY_PATH $REMOTE_MACHINE_USERNAME@$ip \"chmod +x /tmp/install-etcd.sh && /tmp/install-etcd.sh\""
        ssh -o StrictHostKeyChecking=accept-new -i $NODE_PRIVATE_KEY_PATH $REMOTE_MACHINE_USERNAME@$ip "chmod +x /tmp/install-etcd.sh && /tmp/install-etcd.sh"
        echo ""
    done
}

# copySpecificEtcdConfigsToMasterNodes
# function to copy specific etcd configs to master nodes
function copySpecificEtcdConfigsToMasterNodes {
    for ip in ${MASTER_NODE_IPS[@]}; do 
        echo ""
        echo "Copying specific etcd certs to $ip"
        echo "sudo scp -o StrictHostKeyChecking=accept-new -i $NODE_PRIVATE_KEY_PATH $ETCD_CERTS_FOLDER/$ip/* $REMOTE_MACHINE_USERNAME@$ip:$ETCD_CERTS_FOLDER/$ip"
        sudo scp -o StrictHostKeyChecking=accept-new -i $NODE_PRIVATE_KEY_PATH $ETCD_CERTS_FOLDER/$ip/* $REMOTE_MACHINE_USERNAME@$ip:$ETCD_CERTS_FOLDER/$ip
        echo ""

        echo ""
        echo "Setting permissions for certs on $ip"
        echo "ssh -o StrictHostKeyChecking=accept-new -i $NODE_PRIVATE_KEY_PATH $REMOTE_MACHINE_USERNAME@$ip \"chmod -R 400 $ETCD_CERTS_FOLDER/$ip/{*.csr,*.crt,*.key}\""
        ssh -o StrictHostKeyChecking=accept-new -i $NODE_PRIVATE_KEY_PATH $REMOTE_MACHINE_USERNAME@$ip "chmod -R 400 $ETCD_CERTS_FOLDER/$ip/{*.csr,*.crt,*.key}"
        echo ""

        echo ""
        echo "Moving etcd.conf from $ETCD_CERTS_FOLDER/$ip to $ETCD_FOLDER on $ip"
        echo "ssh -o StrictHostKeyChecking=accept-new -i $NODE_PRIVATE_KEY_PATH $REMOTE_MACHINE_USERNAME@$ip \"sudo mv $ETCD_CERTS_FOLDER/$ip/etcd.conf $ETCD_FOLDER\""
        ssh -o StrictHostKeyChecking=accept-new -i $NODE_PRIVATE_KEY_PATH $REMOTE_MACHINE_USERNAME@$ip "sudo mv $ETCD_CERTS_FOLDER/$ip/etcd.conf $ETCD_FOLDER"
        echo ""

        echo ""
        echo "Moving etcd.conf.yaml from $ETCD_CERTS_FOLDER/$ip to $ETCD_FOLDER on $ip"
        echo "ssh -o StrictHostKeyChecking=accept-new -i $NODE_PRIVATE_KEY_PATH $REMOTE_MACHINE_USERNAME@$ip \"sudo mv $ETCD_CERTS_FOLDER/$ip/etcd.conf.yaml $ETCD_FOLDER\""
        ssh -o StrictHostKeyChecking=accept-new -i $NODE_PRIVATE_KEY_PATH $REMOTE_MACHINE_USERNAME@$ip "sudo mv $ETCD_CERTS_FOLDER/$ip/etcd.conf.yaml $ETCD_FOLDER"
        echo ""
    done
}

# generateAndCopyEtcdSystemdServiceConfig
# function to generate and copy systemd service config "etcd.service" to remote machines
function generateAndCopyEtcdSystemdServiceConfig {
    sudo touch "$ETCD_FOLDER/etcd.service"
    sudo chmod -R 777 "$ETCD_FOLDER/etcd.service"
    cat 1>&2 <<EOF > "$ETCD_FOLDER/etcd.service"
[Unit]
Description=etcd key-value store
Documentation=https://github.com/etcd-io/etcd
After=network.target
 
[Service]
Type=notify
ExecStart=/usr/local/bin/etcd --config-file /etcd/etcd.conf.yaml
Restart=always
RestartSec=10s
LimitNOFILE=40000
 
[Install]
WantedBy=multi-user.target
EOF
    for ip in ${MASTER_NODE_IPS[@]}; do 
        echo ""
        echo "Copying etcd.service to $ip..."
        echo "sudo scp -o StrictHostKeyChecking=accept-new -i $NODE_PRIVATE_KEY_PATH \"$ETCD_FOLDER/etcd.service\" $REMOTE_MACHINE_USERNAME@$ip:/tmp"
        sudo scp -o StrictHostKeyChecking=accept-new -i $NODE_PRIVATE_KEY_PATH "$ETCD_FOLDER/etcd.service" $REMOTE_MACHINE_USERNAME@$ip:/tmp
        echo ""

        echo ""
        echo "Moving etcd.service from /tmp to $SYSTEMD_LIB_SYSTEM_PATH and enabling etcd service..."
        echo "ssh -o StrictHostKeyChecking=accept-new -i $NODE_PRIVATE_KEY_PATH $REMOTE_MACHINE_USERNAME@$ip \"sudo mv /tmp/etcd.service $SYSTEMD_LIB_SYSTEM_PATH\""
        ssh -o StrictHostKeyChecking=accept-new -i $NODE_PRIVATE_KEY_PATH $REMOTE_MACHINE_USERNAME@$ip "sudo mv /tmp/etcd.service $SYSTEMD_LIB_SYSTEM_PATH"
        ssh -o StrictHostKeyChecking=accept-new -i $NODE_PRIVATE_KEY_PATH $REMOTE_MACHINE_USERNAME@$ip "sudo systemctl daemon-reload"
        ssh -o StrictHostKeyChecking=accept-new -i $NODE_PRIVATE_KEY_PATH $REMOTE_MACHINE_USERNAME@$ip "sudo systemctl enable etcd"
        echo ""
    done
}

# startEtcdOnMasterNodes
# function that will start secured etcd service on master nodes
function startEtcdOnMasterNodes {
    for ip in ${MASTER_NODE_IPS[@]}; do 
        echo ""
        echo "Starting etcd on $ip..."
        echo "Starting etcd on the first node takes a while."
        echo "It might timeout and show the status as activating, but it still starts nonetheless."
        echo "ssh -o StrictHostKeyChecking=accept-new -i $NODE_PRIVATE_KEY_PATH $REMOTE_MACHINE_USERNAME@$ip \"sudo systemctl start etcd\""
        ssh -o StrictHostKeyChecking=accept-new -i $NODE_PRIVATE_KEY_PATH $REMOTE_MACHINE_USERNAME@$ip "sudo systemctl start etcd"
        ssh -o StrictHostKeyChecking=accept-new -i $NODE_PRIVATE_KEY_PATH $REMOTE_MACHINE_USERNAME@$ip "sudo systemctl status etcd"
        echo ""
        cat 1>&2 <<EOF
# To check if etcd is running on each node, 
# log into the node and run the following (this will display the etcd member list)
etcdctl --endpoints=https://$ip:2379 \
--cert=$ETCD_CERTS_FOLDER/$ip/server.crt \
--cacert=$ETCD_CERTS_FOLDER/$ip/etcd-ca.crt \
--key=$ETCD_CERTS_FOLDER/$ip/server.key \
member list
EOF
    done
}

# installEtcd
# function that will call other functions to install etcd on remote nodes
function installEtcd {
    generateCaCerts
    generateCertsForEachEtcdNode
    installEtcdOnRemoteMasterNodes
    copySpecificEtcdConfigsToMasterNodes
    generateAndCopyEtcdSystemdServiceConfig
    startEtcdOnMasterNodes
}

# uninstallEtcd
# function will completely uninstall etcd 
function uninstallEtcd {
    sudo touch $ETCD_FOLDER/uninstall-etcd.sh
    sudo chmod -R 777 $ETCD_FOLDER/uninstall-etcd.sh
    cat 1>&2 <<EOF > "$ETCD_FOLDER/uninstall-etcd.sh"
#!/bin/bash
sudo systemctl stop etcd
sudo systemctl disable etcd
sudo rm -f /lib/systemd/system/etcd.service
sudo systemctl daemon-reload
sudo rm -rf $ETCD_FOLDER
sudo rm -f /usr/local/bin/etcd
sudo rm -f /usr/local/bin/etcdctl
sudo rm -rf /tmp/etcd-download-test
sudo rm -rf /tmp/install-etcd.sh
EOF
    for ip in ${MASTER_NODE_IPS[@]}; do 
        echo ""
        echo "Copying uninstall-etcd.sh to $ip..."
        echo "sudo scp -o StrictHostKeyChecking=accept-new -i $NODE_PRIVATE_KEY_PATH $ETCD_FOLDER/uninstall-etcd.sh $REMOTE_MACHINE_USERNAME@$ip:/tmp"
        sudo scp -o StrictHostKeyChecking=accept-new -i $NODE_PRIVATE_KEY_PATH $ETCD_FOLDER/uninstall-etcd.sh $REMOTE_MACHINE_USERNAME@$ip:/tmp
        echo ""

        echo ""
        echo "Completely removing etcd on $ip"
        echo "ssh -o StrictHostKeyChecking=accept-new -i $NODE_PRIVATE_KEY_PATH $REMOTE_MACHINE_USERNAME@$ip \"sudo chmod +x /tmp/uninstall-etcd.sh && /tmp/uninstall-etcd.sh\""
        ssh -o StrictHostKeyChecking=accept-new -i $NODE_PRIVATE_KEY_PATH $REMOTE_MACHINE_USERNAME@$ip "sudo chmod +x /tmp/uninstall-etcd.sh && /tmp/uninstall-etcd.sh"
        echo ""
    done
}

# generateK3sEndpointTextString
# function that will generate the text for K3S_DATASTORE_ENDPOINT to use
function generateK3sEndpointTextString {
    for ip in ${MASTER_NODE_IPS[@]}; do 
        echo "Agent k3s datastore endpoint for IP: $ip"
        K3S_DS_ENDPOINT+="https://$ip:2379,"
    done
    # Trim trailing comma
    K3S_DS_ENDPOINT=$(echo -n $K3S_DS_ENDPOINT | head -c -1)
}

# installK3s
# function to install production grade k3s.
# The k3s will use etcd as its datasource
# e.g. installK3s "server"
# e.g. installK3s "agent"
function installK3s {
    if [ ! -d $K3S_FOLDER ]; then
        sudo mkdir -p $K3S_FOLDER
        sudo chmod -R 777 $K3S_FOLDER
    fi

    # Get the value of the load balancer. This is important for k3s https://rancher.com/docs/k3s/latest/en/installation/ha/
    LOAD_BALANCER_IP=$(echo ${NGINX_LOAD_BALANCER_NODE_IPS} | cut -d ' ' -f1)
    
    # Get the input argument $1 when calling this function
    k3sType=$1

    # Populate the K3S_DATASTORE_ENDPOINT
    generateK3sEndpointTextString

    # Installing k3s on master nodes
    if [ $k3sType = "server" ]; then 
        for ip in ${MASTER_NODE_IPS[@]}; do 
            cat 1>&2 <<EOF > "$K3S_FOLDER/install-k3s-server.$ip.sh"
#!/bin/bash
if [ \$(which k3s | wc -l) -ne 1 ]; then
    export K3S_DATASTORE_ENDPOINT="$K3S_DS_ENDPOINT"
    export K3S_DATASTORE_CAFILE="$ETCD_CERTS_FOLDER/$ip/etcd-ca.crt"
    export K3S_DATASTORE_CERTFILE="$ETCD_CERTS_FOLDER/$ip/server.crt"
    export K3S_DATASTORE_KEYFILE="$ETCD_CERTS_FOLDER/$ip/server.key"
    export INSTALL_K3S_VERSION="v$K3S_VERSION+k3s1"
    curl -sfL https://get.k3s.io | sh -s - server --node-taint CriticalAddonsOnly=true:NoExecute --tls-san $LOAD_BALANCER_IP
fi

sudo k3s kubectl get nodes
echo "Fetching server token. Use this token when installing k3s nodes"
sudo cat /var/lib/rancher/k3s/server/token
EOF
        echo "Running script on $ip"
        cat "$K3S_FOLDER/install-k3s-server.$ip.sh"
        echo ""

        echo ""
        echo "Copying install-k3s-server.$ip.sh to $ip"
        echo "sudo scp -o StrictHostKeyChecking=accept-new -i $NODE_PRIVATE_KEY_PATH "$K3S_FOLDER/install-k3s-server.$ip.sh" $REMOTE_MACHINE_USERNAME@$ip:/tmp"
        sudo scp -o StrictHostKeyChecking=accept-new -i $NODE_PRIVATE_KEY_PATH "$K3S_FOLDER/install-k3s-server.$ip.sh" $REMOTE_MACHINE_USERNAME@$ip:/tmp
        echo ""
        
        echo ""
        echo "Installing k3s server on $ip"
        echo "ssh -o StrictHostKeyChecking=accept-new -i $NODE_PRIVATE_KEY_PATH $REMOTE_MACHINE_USERNAME@$ip \"sudo chmod +x /tmp/install-k3s-server.$ip.sh && /tmp/install-k3s-server.$ip.sh\""
        ssh -o StrictHostKeyChecking=accept-new -i $NODE_PRIVATE_KEY_PATH $REMOTE_MACHINE_USERNAME@$ip "sudo chmod +x /tmp/install-k3s-server.$ip.sh && /tmp/install-k3s-server.$ip.sh"
        echo ""
                
        done
    fi

    # Fetch k3s token and kube config from one of the master nodes
    ip=$(echo ${MASTER_NODE_IPS} | cut -d ' ' -f1)
    echo ""
    echo "Fetching token from $ip"
    k3sToken=$(ssh -o StrictHostKeyChecking=accept-new -i $NODE_PRIVATE_KEY_PATH $REMOTE_MACHINE_USERNAME@$ip "sudo cat /var/lib/rancher/k3s/server/token")
    echo ""

    # create kube config file
    sudo touch "$K3S_FOLDER/kube.config"
    sudo chmod -R 777 "$K3S_FOLDER/kube.config"

    echo ""
    echo "Fetching kube config from $ip"
    ssh -o StrictHostKeyChecking=accept-new -i $NODE_PRIVATE_KEY_PATH $REMOTE_MACHINE_USERNAME@$ip "sudo cat /etc/rancher/k3s/k3s.yaml" > "$K3S_FOLDER/kube.config"
    echo ""
    
    echo ""
    echo "Using sed to replace 127.0.0.1 with load balancer IP: $LOAD_BALANCER_IP"
    sudo sed -i s"^127.0.0.1^$LOAD_BALANCER_IP^g" "$K3S_FOLDER/kube.config"
        
    # Installing k3s on agent nodes
    if [ $k3sType = "agent" ]; then
        for ip in ${AGENT_NODE_IPS[@]}; do 
            cat 1>&2 <<EOF > "$K3S_FOLDER/install-k3s-agent.$ip.sh"
#!/bin/bash
if [ \$(which k3s | wc -l) -ne 1 ]; then
    export INSTALL_K3S_VERSION="v$K3S_VERSION+k3s1"
    export K3S_TOKEN="$k3sToken"
    export K3S_URL="https://$LOAD_BALANCER_IP:6443"
    curl -sfL https://get.k3s.io | sh -
    sudo mkdir -p ~/.kube
    sudo touch ~/.kube/config
    sudo mv /tmp/kube.config /tmp/config
    sudo mv /tmp/config ~/.kube/config
    sudo kubectl label nodes \${HOSTNAME} kubernetes.io/role=agent
fi
EOF
            echo ""
            echo "Running script on $ip"
            cat "$K3S_FOLDER/install-k3s-agent.$ip.sh"
            echo ""

            echo ""
            echo "Copying install-k3s-server.$ip.sh to $ip"
            echo "sudo scp -o StrictHostKeyChecking=accept-new -i $NODE_PRIVATE_KEY_PATH \"$K3S_FOLDER/install-k3s-agent.$ip.sh\" $REMOTE_MACHINE_USERNAME@$ip:/tmp"
            sudo scp -o StrictHostKeyChecking=accept-new -i $NODE_PRIVATE_KEY_PATH "$K3S_FOLDER/install-k3s-agent.$ip.sh" $REMOTE_MACHINE_USERNAME@$ip:/tmp
            echo ""

            echo ""
            echo "Copying kube config to $ip"
            echo "sudo scp -o StrictHostKeyChecking=accept-new -i $NODE_PRIVATE_KEY_PATH \"$K3S_FOLDER/kube.config\" $REMOTE_MACHINE_USERNAME@$ip:/tmp"
            sudo scp -o StrictHostKeyChecking=accept-new -i $NODE_PRIVATE_KEY_PATH "$K3S_FOLDER/kube.config" $REMOTE_MACHINE_USERNAME@$ip:/tmp
            echo ""

            echo ""
            echo "Installing k3s agent on $ip"
            echo "ssh -o StrictHostKeyChecking=accept-new -i $NODE_PRIVATE_KEY_PATH $REMOTE_MACHINE_USERNAME@$ip \"sudo chmod +x /tmp/install-k3s-agent.$ip.sh && /tmp/install-k3s-agent.$ip.sh\""
            ssh -o StrictHostKeyChecking=accept-new -i $NODE_PRIVATE_KEY_PATH $REMOTE_MACHINE_USERNAME@$ip "sudo chmod +x /tmp/install-k3s-agent.$ip.sh && /tmp/install-k3s-agent.$ip.sh"
            echo ""

            # Get the hostnames of the agents and add to variable AGENT_HOSTNAMES
            AGENT_HOSTNAMES+=$(ssh -o StrictHostKeyChecking=accept-new -i $NODE_PRIVATE_KEY_PATH $REMOTE_MACHINE_USERNAME@$ip "printf \"%s \" \"\$HOSTNAME\"")
        done
    fi

    # When doing a sudo kubectl get nodes, you will see roles assigned to nodes.
    # However roles for agents will show up as <none>
    # This will set the agent nodes from <none> to agent
    # Loop through each hostname in AGENT_HOSTNAMES
    for hn in ${AGENT_HOSTNAMES[@]}; do
        ip=$(echo ${MASTER_NODE_IPS} | cut -d ' ' -f1)
        echo ""
        echo "Setting the k3s agent label on hostname $hn"
        ssh -o StrictHostKeyChecking=accept-new -i $NODE_PRIVATE_KEY_PATH $REMOTE_MACHINE_USERNAME@$ip "sudo sleep $TIME_TO_WAIT && sudo kubectl label nodes $hn kubernetes.io/role=agent"
        ssh -o StrictHostKeyChecking=accept-new -i $NODE_PRIVATE_KEY_PATH $REMOTE_MACHINE_USERNAME@$ip "sudo kubectl get nodes"
        echo ""
    done
    
    echo ""
    echo "############################################################"
    echo "# TO CONNECT TO THIS CLUSTER, ADD THIS TO YOUR KUBE CONFIG #"
    echo "############################################################"
    echo ""
    sudo cat "$K3S_FOLDER/kube.config"
    echo ""
}

# uninstallK3s
# function to uninstall k3s
# You can uninstall selectively by passing "server" or "agent"
# e.g. uninstallK3s "server"
# e.g. uninstallK3s "agent"
function uninstallK3s {
    k3sType=$1

    if [ $k3sType = "server" ]; then
        for ip in ${MASTER_NODE_IPS[@]}; do 
            echo ""
            echo "Uninstalling k3s agent on $ip"
            echo "ssh -o StrictHostKeyChecking=accept-new -i $NODE_PRIVATE_KEY_PATH $REMOTE_MACHINE_USERNAME@$ip \"sudo /usr/local/bin/k3s-uninstall.sh\""
            ssh -o StrictHostKeyChecking=accept-new -i $NODE_PRIVATE_KEY_PATH $REMOTE_MACHINE_USERNAME@$ip "sudo /usr/local/bin/k3s-uninstall.sh"
            echo ""
        done
    fi

    if [ $k3sType = "agent" ]; then
        for ip in ${AGENT_NODE_IPS[@]}; do
            echo ""
            echo "Uninstalling k3s agent on $ip"
            echo "ssh -o StrictHostKeyChecking=accept-new -i $NODE_PRIVATE_KEY_PATH $REMOTE_MACHINE_USERNAME@$ip \"sudo /usr/local/bin/k3s-agent-uninstall.sh\""
            ssh -o StrictHostKeyChecking=accept-new -i $NODE_PRIVATE_KEY_PATH $REMOTE_MACHINE_USERNAME@$ip "sudo /usr/local/bin/k3s-agent-uninstall.sh"
            echo ""
        done
    fi
}

# generateNginxConfig
# function that will generate the correct nginx config that will be the load balancer for k3s
function generateNginxConfig {
    if [ ! -d "$NGINX_CONF_PATH" ]; then
        sudo mkdir -p $NGINX_CONF_PATH
        sudo chmod -R 777 $NGINX_CONF_PATH

        sudo touch "$NGINX_CONF_PATH/nginx.conf"
        sudo chmod -R 777 "$NGINX_CONF_PATH/nginx.conf"
    fi

    for ip in ${MASTER_NODE_IPS[@]}; do
        k3sServers+="server $ip:6443; "
    done
    echo $k3sServers

    cat 1>&2 <<EOF > "$NGINX_CONF_PATH/nginx.conf"
load_module '/usr/lib/nginx/modules/ngx_stream_module.so';

events {}

stream {
    upstream k3s_servers {
        ${k3sServers}
    }

    server {
        listen 6443;
        proxy_pass k3s_servers;
    }
}
EOF
    cat "$NGINX_CONF_PATH/nginx.conf"
}

# installNginx
# function to install and configure and start nginx on the load balancer(s)
function installNginx {
    if [ -z "$NGINX_LOAD_BALANCER_NODE_IPS" ]; then
        usage
        echo ""
        echo "Please provide the IP(s) of the nginx load balancer nodes"
        echo "e.g. \"192.168.0.7 192.168.0.8 192.168.0.9\""
        echo ""
        exit 1
    fi

    # Generate nginx config
    generateNginxConfig

    if [ ! -f "$NGINX_CONF_PATH/install-nginx.sh" ]; then
        sudo touch "$NGINX_CONF_PATH/install-nginx.sh"
        sudo chmod -R 777 "$NGINX_CONF_PATH/install-nginx.sh"
    fi  

    cat 1>&2 <<EOF > "$NGINX_CONF_PATH/install-nginx.sh"
#!/bin/bash
if [ \$(which nginx | wc -l) -ne 1 ]; then
    timestamp=\$(date +%Y_%m_%d_%H_%M)
    sudo apt-get update -y && sudo apt-get autoremove -y
    sudo apt-get install libnginx-mod-stream nginx-extras nginx -y
    sudo systemctl stop nginx
    sudo mv /etc/nginx/nginx.conf /etc/nginx/nginx.conf.\$timestamp 
    sudo mv /tmp/nginx.conf /etc/nginx/nginx.conf
    sudo systemctl start nginx
    sudo systemctl status nginx
fi
EOF
    echo "Running script on load balancer..."
    cat "$NGINX_CONF_PATH/install-nginx.sh"

    for ip in ${NGINX_LOAD_BALANCER_NODE_IPS[@]}; do
        echo ""
        echo "Copying nginx.conf and install-nginx.sh to $ip"
        echo "sudo scp -o StrictHostKeyChecking=accept-new -i $NODE_PRIVATE_KEY_PATH $NGINX_CONF_PATH/* $REMOTE_MACHINE_USERNAME@$ip:/tmp"
        sudo scp -o StrictHostKeyChecking=accept-new -i $NODE_PRIVATE_KEY_PATH $NGINX_CONF_PATH/* $REMOTE_MACHINE_USERNAME@$ip:/tmp
        echo ""
        
        echo ""
        echo "Installing, Configuring and Starting nginx on $ip"
        echo "ssh -o StrictHostKeyChecking=accept-new -i $NODE_PRIVATE_KEY_PATH $REMOTE_MACHINE_USERNAME@$ip \"sudo chmod +x /tmp/install-nginx.sh && /tmp/install-nginx.sh\""
        ssh -o StrictHostKeyChecking=accept-new -i $NODE_PRIVATE_KEY_PATH $REMOTE_MACHINE_USERNAME@$ip "sudo chmod +x /tmp/install-nginx.sh && /tmp/install-nginx.sh"
        echo ""
    done
}

# uninstallNginx
# function that will completely uninstall nginx on the load balancer
function uninstallNginx {
    if [ ! -f "$NGINX_CONF_PATH/uninstall-nginx.sh" ]; then
        sudo touch "$NGINX_CONF_PATH/uninstall-nginx.sh"
        sudo chmod -R 777 "$NGINX_CONF_PATH/uninstall-nginx.sh"
    fi  
        cat 1>&2 <<EOF > "$NGINX_CONF_PATH/uninstall-nginx.sh"
#!/bin/bash
if [ \$(which nginx | wc -l) -eq 1 ]; then
    sudo systemctl stop nginx
    sudo apt-get purge libnginx-mod-stream nginx-extras nginx -y
    sudo apt-get autoremove -y
    sudo rm -rf /etc/nginx
fi
EOF
    for ip in ${NGINX_LOAD_BALANCER_NODE_IPS[@]}; do
        echo ""
        echo "Copying nginx uninstall script to $ip"
        echo "sudo scp -o StrictHostKeyChecking=accept-new -i $NODE_PRIVATE_KEY_PATH \"$NGINX_CONF_PATH/uninstall-nginx.sh\" $REMOTE_MACHINE_USERNAME@$ip:/tmp"
        sudo scp -o StrictHostKeyChecking=accept-new -i $NODE_PRIVATE_KEY_PATH "$NGINX_CONF_PATH/uninstall-nginx.sh" $REMOTE_MACHINE_USERNAME@$ip:/tmp
        echo ""
        
        echo ""
        echo "Uninstalling nginx on $ip"
        echo "ssh -o StrictHostKeyChecking=accept-new -i $NODE_PRIVATE_KEY_PATH $REMOTE_MACHINE_USERNAME@$ip \"sudo chmod +x /tmp/uninstall-nginx.sh && /tmp/uninstall-nginx.sh\""
        ssh -o StrictHostKeyChecking=accept-new -i $NODE_PRIVATE_KEY_PATH $REMOTE_MACHINE_USERNAME@$ip "sudo chmod +x /tmp/uninstall-nginx.sh && /tmp/uninstall-nginx.sh"
        echo ""
    done
}

# upgradeK3s
# function that will upgrade k3s on masters and agent nodes.
function upgradeK3s {
    k3sType=$1
    if [ $k3sType = "server" ]; then
        for ip in ${MASTER_NODE_IPS[@]}; do 
            sudo touch "$K3S_FOLDER/upgrade-k3s-server.$ip.sh"
            sudo chmod -R 777 "$K3S_FOLDER/upgrade-k3s-server.$ip.sh"
            cat 1>&2 <<EOF > "$K3S_FOLDER/upgrade-k3s-server.$ip.sh"
#!/bin/bash
if [ \$(which k3s | wc -l) -eq 1 ]; then
    echo "Previous version of k3s on $ip ..."
    k3s --version 

    echo "Stop the k3s service on $ip ..."
    sudo systemctl stop k3s

    echo "Download k3s version ${K3S_VERSION} binary on $ip ..."
    curl -L https://github.com/k3s-io/k3s/releases/download/v${K3S_VERSION}%2Bk3s1/k3s -o /tmp/k3s
    sudo chmod +x /tmp/k3s
    sudo rm /usr/local/bin/k3s
    sudo mv /tmp/k3s /usr/local/bin

    echo "New version of k3s on $ip ..."
    k3s --version

    echo "Start k3s server using systemd on $ip ..."
    sudo systemctl start k3s

    echo "Show the status of k3s server using systemd on $ip ..."
    sudo systemctl status k3s

    echo "Run kubectl to fetch nodes on $ip ..."
    sudo kubectl get nodes
fi
EOF
            echo ""
            echo "Running k3s server upgrade script on $ip"
            cat "$K3S_FOLDER/upgrade-k3s-server.$ip.sh"
            echo ""   

            echo ""
            echo "Copying upgrade-k3s-server.$ip.sh to $ip"
            sudo scp -o StrictHostKeyChecking=accept-new -i $NODE_PRIVATE_KEY_PATH \"$K3S_FOLDER/upgrade-k3s-server.$ip.sh\" $REMOTE_MACHINE_USERNAME@$ip:/tmp
            sudo scp -o StrictHostKeyChecking=accept-new -i $NODE_PRIVATE_KEY_PATH "$K3S_FOLDER/upgrade-k3s-server.$ip.sh" $REMOTE_MACHINE_USERNAME@$ip:/tmp
            echo ""

            echo ""
            echo "Running upgrade-k3s-server.$ip.sh on $ip"
            echo "ssh -o StrictHostKeyChecking=accept-new -i $NODE_PRIVATE_KEY_PATH $REMOTE_MACHINE_USERNAME@$ip \"sudo chmod +x /tmp/upgrade-k3s-server.$ip.sh && /tmp/upgrade-k3s-server.$ip.sh\""
            ssh -o StrictHostKeyChecking=accept-new -i $NODE_PRIVATE_KEY_PATH $REMOTE_MACHINE_USERNAME@$ip "sudo chmod +x /tmp/upgrade-k3s-server.$ip.sh && /tmp/upgrade-k3s-server.$ip.sh"
            echo ""    
        done
    fi

    if [ $k3sType = "agent" ]; then
        for ip in ${AGENT_NODE_IPS[@]}; do 
            sudo touch "$K3S_FOLDER/upgrade-k3s-agent.$ip.sh"
            sudo chmod -R 777 "$K3S_FOLDER/upgrade-k3s-agent.$ip.sh"
            cat 1>&2 <<EOF > "$K3S_FOLDER/upgrade-k3s-agent.$ip.sh"
#!/bin/bash
if [ \$(which k3s | wc -l) -eq 1 ]; then
    echo "Previous version of k3s on $ip ..."
    k3s --version 

    echo "Stop the k3s agent service on $ip ..."
    sudo systemctl stop k3s-agent

    echo "Download k3s version ${K3S_VERSION} binary on $ip ..."
    curl -L https://github.com/k3s-io/k3s/releases/download/v${K3S_VERSION}%2Bk3s1/k3s -o /tmp/k3s
    sudo chmod +x /tmp/k3s
    sudo rm /usr/local/bin/k3s
    sudo mv /tmp/k3s /usr/local/bin

    echo "New version of k3s on $ip ..."
    k3s --version 

    echo "Start k3s agent on $ip ..."
    sudo systemctl start k3s-agent

    echo "Checking the status of k3s agent on $ip ..."
    sudo systemctl status k3s-agent

    echo "Using kubectl to check nodes on $ip ..."
    sudo kubectl get nodes
fi
EOF
            echo ""
            echo "Running k3s agent upgrade script on $ip"
            cat "$K3S_FOLDER/upgrade-k3s-agent.$ip.sh"
            echo ""       

            echo ""
            echo "Copying upgrade-k3s-agent.$ip.sh to $ip"
            sudo scp -o StrictHostKeyChecking=accept-new -i $NODE_PRIVATE_KEY_PATH \"$K3S_FOLDER/upgrade-k3s-agent.$ip.sh\" $REMOTE_MACHINE_USERNAME@$ip:/tmp
            sudo scp -o StrictHostKeyChecking=accept-new -i $NODE_PRIVATE_KEY_PATH "$K3S_FOLDER/upgrade-k3s-agent.$ip.sh" $REMOTE_MACHINE_USERNAME@$ip:/tmp
            echo ""

            echo ""
            echo "Running upgrade-k3s-agent.$ip.sh on $ip"
            echo "ssh -o StrictHostKeyChecking=accept-new -i $NODE_PRIVATE_KEY_PATH $REMOTE_MACHINE_USERNAME@$ip \"sudo chmod +x /tmp/upgrade-k3s-agent.$ip.sh && /tmp/upgrade-k3s-agent.$ip.sh\""
            ssh -o StrictHostKeyChecking=accept-new -i $NODE_PRIVATE_KEY_PATH $REMOTE_MACHINE_USERNAME@$ip "sudo chmod +x /tmp/upgrade-k3s-agent.$ip.sh && /tmp/upgrade-k3s-agent.$ip.sh"
            echo ""
        done
    fi
}

checkPrequisites

case "$JOB_TYPE" in
    ingx | installNginx)
        installNginx
    ;;
    ungx | uninstallNginx)
        uninstallNginx
    ;;
    ietcd | installEtcd)
        installEtcd
    ;;
    uetcd | uninstallEtcd)
        uninstallEtcd
    ;;
    ik3s | installK3s)
        installK3s "server"
        installK3s "agent"
    ;;
    upk3s | upgradeK3s)
        upgradeK3s "server"
        upgradeK3s "agent"
    ;;
    uk3s | uninstallK3s)
        uninstallK3s "agent"
        uninstallK3s "server"
    ;;
    iev | installEverything)
        installNginx
        installEtcd
        installK3s "server"
        installK3s "agent"
    ;;
    uev | uninstallEverything)
        uninstallK3s "agent"
        uninstallK3s "server"
        uninstallEtcd
        uninstallNginx
    ;;
    *)
        usage
        echo ""
        echo "ERROR!!!"
        echo "Please provide job tag. Example below..."
        echo "-job iev"
        echo "--job installEverything"
        echo ""
        exit 1
    ;;
esac
