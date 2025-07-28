# K3s Production Deployment Script

A comprehensive bash script for deploying production-grade K3s Kubernetes clusters with secure etcd backend and nginx load balancing on Ubuntu Linux machines.

## Author
**Bankole Ogundero** - Created: Wed 12-May-2021

## Overview

This script automates the deployment of a highly available K3s cluster with the following components:
- **Secure etcd cluster** as the datastore backend
- **K3s server nodes** (masters) with etcd integration
- **K3s agent nodes** (workers)
- **Nginx load balancer** for cluster access

## Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│  Nginx LB Node  │    │  Nginx LB Node  │    │  Nginx LB Node  │
│   (Optional)    │    │   (Optional)    │    │   (Optional)    │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         └───────────────────────┼───────────────────────┘
                                 │
    ┌────────────────────────────┼────────────────────────────┐
    │                            │                            │
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│  K3s Master +   │    │  K3s Master +   │    │  K3s Master +   │
│  etcd Node      │    │  etcd Node      │    │  etcd Node      │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         └───────────────────────┼───────────────────────┘
                                 │
    ┌────────────────────────────┼────────────────────────────┐
    │                            │                            │
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│  K3s Agent      │    │  K3s Agent      │    │  K3s Agent      │
│  Node           │    │  Node           │    │  Node           │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

## Prerequisites

### System Requirements
- **Operating System**: Ubuntu Linux (tested with apt-get package manager)
- **Node Count**: Odd number of master nodes (3, 5, 7) for etcd quorum
- **SSH Access**: Same private key for all target machines
- **Network**: All nodes must be reachable via ping

### Required Tools (automatically checked)
- `ssh` - Secure Shell client
- `scp` - Secure Copy Protocol
- `curl` - Data transfer tool
- `ping` - Network connectivity test

### Automatically Installed Dependencies
- **cfssl** - CloudFlare's PKI toolkit for certificate generation
- **cfssljson** - JSON processing tool for cfssl
- **etcd** - Distributed key-value store
- **k3s** - Lightweight Kubernetes distribution
- **nginx** - Load balancer (on designated nodes)

## Installation

1. **Download the script**:
   ```bash
   wget https://your-repo/deploy-k3s.sh
   chmod +x deploy-k3s.sh
   ```

2. **Prepare your infrastructure**:
   - Deploy Ubuntu machines for masters, agents, and load balancers
   - Ensure SSH key-based authentication is configured
   - Verify network connectivity between all nodes

## Usage

### Command Line Arguments

| Flag | Long Form | Description | Required |
|------|-----------|-------------|----------|
| `-mnips` | `--masterNodeIps` | Master node IP addresses (space-separated) | ✅ |
| `-anips` | `--agentNodeIps` | Agent node IP addresses (space-separated) | ✅ |
| `-nlbnips` | `--nginxLoadBalancerNodeIps` | Load balancer IP addresses | ✅ |
| `-npkp` | `--nodePrivateKeyPath` | Path to SSH private key | ✅ |
| `-rmun` | `--remoteMachineUsername` | SSH username for remote machines | ✅ |
| `-etcdv` | `--etcdVersion` | etcd version (default: 3.4.10) | ❌ |
| `-k3sv` | `--k3sVersion` | K3s version (default: 1.19.7) | ❌ |
| `-job` | `--job` | Job type to execute | ✅ |
| `-h` | `--help` | Display usage information | ❌ |

### Job Types

| Job Code | Long Form | Description |
|----------|-----------|-------------|
| `ietcd` | `installEtcd` | Install secure etcd cluster |
| `uetcd` | `uninstallEtcd` | Uninstall etcd completely |
| `ik3s` | `installK3s` | Install K3s servers and agents |
| `upk3s` | `upgradeK3s` | Upgrade K3s to specified version |
| `uk3s` | `uninstallK3s` | Uninstall K3s completely |
| `ingx` | `installNginx` | Install and configure nginx load balancer |
| `ungx` | `uninstallNginx` | Uninstall nginx load balancer |
| `iev` | `installEverything` | Complete cluster deployment |
| `uev` | `uninstallEverything` | Complete cluster removal |

## Examples

### Complete Cluster Deployment

```bash
./deploy-k3s.sh \
  --masterNodeIps "10.22.17.11 10.22.17.12 10.22.17.13" \
  --agentNodeIps "10.22.17.14 10.22.17.15 10.22.17.16 10.22.17.17" \
  --nginxLoadBalancerNodeIps "10.22.17.10" \
  --nodePrivateKeyPath "~/.ssh/id_rsa" \
  --remoteMachineUsername admin \
  --etcdVersion 3.4.10 \
  --k3sVersion 1.19.7 \
  --job installEverything
```

### Short Form Usage

```bash
./deploy-k3s.sh \
  -mnips "10.22.17.11 10.22.17.12 10.22.17.13" \
  -anips "10.22.17.14 10.22.17.15 10.22.17.16 10.22.17.17" \
  -nlbnips "10.22.17.10" \
  -npkp "~/.ssh/id_rsa" \
  -rmun admin \
  -etcdv 3.4.10 \
  -k3sv 1.19.7 \
  -job iev
```

### Individual Component Installation

**Install only etcd**:
```bash
./deploy-k3s.sh \
  --masterNodeIps "10.22.17.11 10.22.17.12 10.22.17.13" \
  --agentNodeIps "10.22.17.14 10.22.17.15" \
  --nginxLoadBalancerNodeIps "10.22.17.10" \
  --nodePrivateKeyPath "~/.ssh/id_rsa" \
  --remoteMachineUsername admin \
  --job installEtcd
```

**Install only nginx load balancer**:
```bash
./deploy-k3s.sh \
  --masterNodeIps "10.22.17.11 10.22.17.12 10.22.17.13" \
  --agentNodeIps "10.22.17.14 10.22.17.15" \
  --nginxLoadBalancerNodeIps "10.22.17.10" \
  --nodePrivateKeyPath "~/.ssh/id_rsa" \
  --remoteMachineUsername admin \
  --job installNginx
```

## Deployment Process

### 1. Complete Installation (`installEverything`)

The script performs these steps in order:

1. **Prerequisites Check**
   - Validates required tools are available
   - Tests network connectivity to all nodes
   - Creates necessary directories
   - Installs cfssl if needed

2. **Nginx Load Balancer Setup**
   - Installs nginx with stream module
   - Configures load balancing for K3s API servers
   - Starts nginx service

3. **Secure etcd Cluster Deployment**
   - Generates CA certificates using cfssl
   - Creates node-specific TLS certificates
   - Installs etcd binaries on master nodes
   - Configures etcd cluster with TLS encryption
   - Creates systemd services
   - Starts etcd cluster

4. **K3s Server Installation**
   - Configures K3s to use etcd as datastore
   - Installs K3s on master nodes with server role
   - Applies node taints for master nodes
   - Retrieves cluster token

5. **K3s Agent Installation**
   - Installs K3s agents on worker nodes
   - Joins agents to the cluster using cluster token
   - Labels agent nodes appropriately

## Configuration Details

### etcd Configuration

- **TLS Encryption**: Full TLS encryption for client and peer communication
- **Certificate Authority**: Self-signed CA generated with cfssl
- **Data Directory**: `/etcd/data`
- **Certificates Directory**: `/etcd/certs/{node-ip}/`
- **Ports**: 2379 (client), 2380 (peer)

### K3s Configuration

- **Datastore**: External etcd cluster
- **API Server**: Load balanced through nginx
- **Default Version**: v1.19.7+k3s1
- **Master Node Taint**: `CriticalAddonsOnly=true:NoExecute`

### Nginx Configuration

- **Module**: `ngx_stream_module` for TCP load balancing
- **Upstream**: All K3s master nodes on port 6443
- **Listen Port**: 6443

## File Structure

The script creates the following directory structure:

```
/
├── etcd/
│   ├── certs/
│   │   ├── {master-ip}/
│   │   │   ├── etcd-ca.crt
│   │   │   ├── server.crt
│   │   │   └── server.key
│   │   └── ca-config.json
│   ├── data/
│   ├── etcd.conf
│   └── etcd.conf.yaml
├── k3s/
│   ├── kube.config
│   └── install-scripts...
└── nginx-conf/
    ├── nginx.conf
    └── install-nginx.sh
```

## Post-Installation

### Accessing Your Cluster

1. **Retrieve kubeconfig**:
   ```bash
   # The script automatically generates this file
   cat /k3s/kube.config
   ```

2. **Copy to your local machine**:
   ```bash
   scp admin@{your-machine}:/k3s/kube.config ~/.kube/config
   ```

3. **Test cluster access**:
   ```bash
   kubectl get nodes
   kubectl get pods --all-namespaces
   ```

### Verifying etcd Health

SSH into any master node and run:

```bash
etcdctl --endpoints=https://{master-ip}:2379 \
  --cert=/etcd/certs/{master-ip}/server.crt \
  --cacert=/etcd/certs/{master-ip}/etcd-ca.crt \
  --key=/etcd/certs/{master-ip}/server.key \
  member list
```

## Maintenance Operations

### Upgrading K3s

```bash
./deploy-k3s.sh \
  --masterNodeIps "10.22.17.11 10.22.17.12 10.22.17.13" \
  --agentNodeIps "10.22.17.14 10.22.17.15" \
  --nginxLoadBalancerNodeIps "10.22.17.10" \
  --nodePrivateKeyPath "~/.ssh/id_rsa" \
  --remoteMachineUsername admin \
  --k3sVersion 1.20.0 \
  --job upgradeK3s
```

### Complete Cluster Removal

```bash
./deploy-k3s.sh \
  --masterNodeIps "10.22.17.11 10.22.17.12 10.22.17.13" \
  --agentNodeIps "10.22.17.14 10.22.17.15" \
  --nginxLoadBalancerNodeIps "10.22.17.10" \
  --nodePrivateKeyPath "~/.ssh/id_rsa" \
  --remoteMachineUsername admin \
  --job uninstallEverything
```

## Troubleshooting

### Common Issues

1. **etcd fails to start on first node**:
   - This is normal - etcd waits for cluster formation
   - Check status after all nodes are configured

2. **SSH connection failures**:
   - Verify private key permissions (should be 600)
   - Ensure key-based authentication is configured
   - Check firewall settings

3. **Network connectivity issues**:
   - Verify all nodes can ping each other
   - Check firewall rules for required ports
   - Ensure DNS resolution is working

### Required Ports

| Service | Port | Protocol | Description |
|---------|------|----------|-------------|
| etcd client | 2379 | TCP | Client communication |
| etcd peer | 2380 | TCP | Peer communication |
| K3s API | 6443 | TCP | Kubernetes API |
| kubelet | 10250 | TCP | Kubelet API |

### Log Locations

- **etcd logs**: `journalctl -u etcd -f`
- **K3s server logs**: `journalctl -u k3s -f`
- **K3s agent logs**: `journalctl -u k3s-agent -f`
- **nginx logs**: `journalctl -u nginx -f`

## Security Considerations

- All etcd communication is encrypted with TLS
- Certificates are generated with 4096-bit RSA keys
- Certificate validity: 10 years (87600h)
- SSH key permissions are automatically set to 600
- Master nodes are tainted to prevent workload scheduling

## Version Compatibility

| Component | Default Version | Tested Versions |
|-----------|----------------|-----------------|
| etcd | 3.4.10 | 3.4.x series |
| K3s | 1.19.7 | 1.19.x series |
| Ubuntu | Not specified | 18.04+, 20.04+ |

## Contributing

When modifying this script:

1. Test thoroughly in a development environment
2. Update version defaults as needed
3. Maintain compatibility with existing configurations
4. Document any breaking changes

## License

This script is provided as-is for production K3s deployments. Please review and test thoroughly before using in production environments.

## Support

For issues or questions:
1. Check the troubleshooting section above
2. Review etcd and K3s official documentation
3. Verify all prerequisites are met
4. Test individual components before full deployment
