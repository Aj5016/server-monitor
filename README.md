# Server Monitor Manager

A Linux server monitoring and incident-response helper script for quickly inspecting network traffic, active connections, service logs, Docker activity, firewall status, and suspicious traffic behavior.

> Created with assistance from **GPT-5.5**.

---

## Overview

`server-monitor.sh` is a menu-driven Bash utility designed for Linux server administrators who need a fast way to investigate traffic spikes, unusual upload/download activity, active connections, and possible attack behavior.

It is intended as an operational toolbox for quick inspection, not as a full replacement for enterprise monitoring, SIEM, IDS, or centralized logging systems.

---

## Features

- Live bandwidth monitoring
- Per-process traffic monitoring
- Active TCP/UDP connection inspection
- Listening port and service visibility
- Top remote IP detection
- Basic suspicious connection analysis
- Firewall status review
- UFW/IPTables/nftables visibility depending on system support
- Authentication log inspection
- Web server log inspection
- Docker container overview
- Exportable system/network reports
- Optional package installation helper
- Basic IP blocking helper with confirmation

---

## Supported Tools

Depending on your Linux distribution and installed packages, the script can use:

- `ss`
- `ip`
- `iftop`
- `nethogs`
- `vnstat`
- `iptraf-ng`
- `bmon`
- `journalctl`
- `ufw`
- `iptables`
- `nft`
- `docker`
- `fail2ban-client`

---

## Use Cases

This script can help answer questions such as:

- Which IPs are connected to my server?
- Which services are receiving traffic?
- Which processes are using network bandwidth?
- Why is my server upload traffic suddenly high?
- Are there suspicious connection patterns?
- What ports are open and listening?
- What happened in the last few minutes?
- Which Docker containers are running?
- Should I temporarily block a suspicious IP?

---

## Important Security Notice

This script is designed for server administration and incident response. Use it carefully.

Before using any blocking feature:

1. Make sure you are not blocking your own IP.
2. Keep an active backup SSH session open.
3. If possible, whitelist your management IP first.
4. Test on a non-critical server before production use.
5. Understand your firewall backend before applying rules.

Incorrect firewall changes can lock you out of your server.

---

## Requirements

- Linux server
- Bash
- Root or sudo privileges
- Common networking utilities

Recommended operating systems:

- Debian
- Ubuntu
- Rocky Linux
- AlmaLinux
- CentOS Stream
- Fedora

---

## Installation

Clone the repository:
```bash
git clone https://github.com/Aj5016/server-monitor-manager.git
cd server-monitor-manager

Make the script executable:

bash
chmod +x server-monitor.sh

Run it as root:

bash
sudo ./server-monitor.sh

---

## Optional Tool Installation

Some features require extra packages.

### Debian / Ubuntu

bash
sudo apt update
sudo apt install -y iftop nethogs vnstat iptraf-ng bmon curl jq net-tools lsof

### RHEL / Rocky / AlmaLinux / Fedora

bash
sudo dnf install -y iftop nethogs vnstat iptraf-ng bmon curl jq net-tools lsof

If `dnf` is not available:

bash
sudo yum install -y iftop nethogs vnstat iptraf-ng bmon curl jq net-tools lsof

---

## Usage

Run:

bash
sudo ./server-monitor.sh

Then select an option from the interactive menu.

Typical investigation flow:

1. Check live bandwidth usage.
2. Check per-process traffic.
3. Review active connections.
4. Identify top remote IPs.
5. Inspect listening services.
6. Review recent logs.
7. Check authentication logs.
8. Review firewall status.
9. Block malicious IPs only if confirmed.

---

## Example Commands Used Internally

The script may use commands similar to:

bash
ss -tuna
ss -tulpn
ip route get 1.1.1.1
iftop -i eth0
nethogs eth0
journalctl -xe
tail -f /var/log/auth.log
tail -f /var/log/nginx/access.log

The exact behavior depends on the server environment and available tools.

---

## Recommended Production Monitoring Stack

This script is useful for quick troubleshooting, but for production environments you should also consider a proper monitoring and security stack.

Recommended layers:

### Metrics

- Prometheus
- Node Exporter
- Grafana

### Logs

- Loki
- Promtail
- Elasticsearch / OpenSearch
- Graylog

### Security

- Fail2ban
- CrowdSec
- Wazuh
- Suricata
- Zeek

### Network Flow Visibility

- NetFlow
- IPFIX
- ntopng

---

## Limitations

This script does not replace:

- A SIEM
- A full IDS/IPS
- Centralized logging
- Long-term traffic analytics
- Professional DDoS protection
- Cloud provider firewalling
- Web Application Firewall rules
- Reverse proxy security hardening

It is a practical local investigation tool.

---

## Safety Recommendations

For secure server operation:

- Disable password SSH login.
- Use SSH keys only.
- Change default SSH port only if appropriate for your environment.
- Enable Fail2ban or CrowdSec.
- Restrict management ports by source IP.
- Keep the OS and packages updated.
- Use a firewall deny-by-default policy where possible.
- Expose only required services.
- Monitor outbound traffic, not only inbound traffic.
- Keep backups before making firewall or system changes.

---

## Troubleshooting

### `nethogs` says no devices to monitor

Try:

bash
ip -br link
ip route get 1.1.1.1
sudo nethogs -a

Or specify the interface manually:

bash
sudo nethogs (interface_name)

### `iftop` does not start

Check the interface name:

bash
ip -br link

Then run:

bash
sudo iftop -i INTERFACE_NAME

Example:

bash
sudo iftop -i (interface_name)

### Permission denied

Run the script with sudo:

bash
sudo ./server-monitor.sh

### Missing command

Install the required package for your distribution.

Example:

bash
sudo apt install iftop nethogs

---

## Disclaimer

This project is provided as-is.

The author and contributors are not responsible for:

- Accidental firewall lockouts
- Service disruptions
- Data loss
- Misconfiguration
- False positives
- False negatives
- Incorrect blocking decisions
- Production outages

Review the script before using it on critical systems.

---

## Attribution

This project was created with assistance from **GPT-5.5**.

---

## License

MIT License

You are free to use, modify, and distribute this project, provided that the license terms are respected.

