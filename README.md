# Homelab

## Hardware

<img width="500px" src="https://github.com/jjti/homelab/assets/13923102/6a97ead1-d26e-4056-8fbc-c2fc2da03fb1" />

The homelab is made up of three [Beelink Mini SER5 Maxes](https://www.bee-link.com/beelink-amd-ryzen-5-ser5-5800u-minip-26183466). Each has 32 GB DDR4 of memory and 500 GB of NVMe storage. I also added [2 TB of SSD storage to each](https://www.amazon.com/dp/B07YD5F561). So in total there's:

- 24 cores / 48 threads
- 96 GiB memory
- 1.5 TiB NVMe storage and 6 TiB SATA storage

The main reason I opt'ed the SER5 Max was they're cheap (~$350 each), have low power draw (advertised at 54 W per node), and they don't take up much space. That said, everything is slower in these compared to a consumer desktop: the 5800H is a laptop CPU, storage is over PCIe 3 not 4, and it's DDR4 memory. That's all fine though since this is to tinker.

## Access

Tailscale. TODO: more details. For the homelab use-case it's better than Cloudflare Tunnels and sshuttle.

## Storage

### MinIO

MinIO is a distributed storage engine with an S3-compatible interface. It means I can write data from one node into MinIO and access it from applications running on other nodes, and have some redundancy during deployments or restarts of any one of the nodes.
