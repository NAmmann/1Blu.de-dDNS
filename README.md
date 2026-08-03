# 1Blu DDNS

Small Python updater for 1Blu DNS records. It logs in to the 1Blu customer interface, reads the configured DNS records, checks the current public internet IP, and only writes DNS records when the configured record is outdated.

This repository is trimmed for running the updater directly inside a Proxmox LXC container with cron.

## What it does

- Checks the current public IPv4 or IPv6 address via `ident.me`.
- Resolves the configured DNS record.
- Updates 1Blu only when the public IP and DNS record differ.
- Supports the base domain and multiple subdomains.
- Supports `A` and `AAAA` records.
- Supports 1Blu accounts with optional TOTP/OTP two-factor authentication.
- Runs one check/update cycle and exits, which is suitable for cron.

## Proxmox LXC setup

Use a Debian or Ubuntu LXC container with internet access.

Inside the container:

```sh
apt-get update
apt-get install -y git
git clone <this-repo-url> /tmp/1blu-ddns
cd /tmp/1blu-ddns
chmod +x scripts/install-lxc.sh
./scripts/install-lxc.sh
```

The installer:

- copies the repository to `/opt/1blu-ddns`
- creates `/opt/1blu-ddns/.venv`
- installs Python dependencies
- creates `/etc/1blu-ddns.env` from `1blu-ddns.env.example` if it does not exist
- links the updater into cron via `/etc/cron.d/1blu-ddns`
- runs the updater every minute with `python -m app.main`
- writes logs to `/var/log/1blu-ddns.log`

After installation, edit the config:

```sh
nano /etc/1blu-ddns.env
```

Then test one update cycle manually:

```sh
set -a
. /etc/1blu-ddns.env
set +a
cd /opt/1blu-ddns
/opt/1blu-ddns/.venv/bin/python -m app.main
```

Cron will run the same check every minute. If the DNS record already matches the current public IP, no DNS update is sent to 1Blu.

## Configuration

Configuration is read from environment variables. The LXC installer stores them in `/etc/1blu-ddns.env`.

| Variable | Required | Description |
| --- | --- | --- |
| `USERNAME` | yes | 1Blu username. |
| `PASSWORD` | yes | 1Blu password. |
| `CONTRACT` | yes | 1Blu contract number from the customer portal. |
| `DOMAIN_NUMBER` | yes | Domain number from the DNS editor URL: `ksb.1blu.de/<contract>/domain/<domain-number>/dns/`. |
| `DOMAIN` | yes | Base domain, for example `example.de`. |
| `OTP_KEY` | no | TOTP setup secret for accounts with 2FA enabled. This is the setup secret, not a current one-time code. |
| `SUBDOMAIN` | no | Comma-separated hostnames to update. Defaults to `@` for the base domain. |
| `RRTYPE` | no | Default record type: `A` for IPv4 or `AAAA` for IPv6. Defaults to `A`. |
| `LOGGING_LEVEL` | no | `INFO`, `WARNING`, `ERROR`, or `DEBUG`. Defaults to `INFO`. |

`SUBDOMAIN` examples:

```sh
# Update the base domain A record.
SUBDOMAIN=@
RRTYPE=A

# Update cloud.example.de as A, home.example.de as AAAA, and example.de as A.
SUBDOMAIN=cloud,home{AAAA},@{A}
RRTYPE=A
```

Do not include spaces in `SUBDOMAIN`.

## Manual usage without cron

Install dependencies:

```sh
python3 -m venv .venv
. .venv/bin/activate
pip install -r requirements.txt
```

Run one check/update cycle:

```sh
set -a
. ./1blu-ddns.env.example
set +a
python -m app.main
```

## VS Code dev container with Podman

The repository includes a VS Code dev container definition in `.devcontainer/`.

To use it with Podman:

1. Install Podman.
2. Install the VS Code Dev Containers extension.
3. Configure VS Code Dev Containers to use Podman instead of Docker, for example by setting `dev.containers.dockerPath` to `podman`.
4. Run `Dev Containers: Reopen in Container`.

The dev container builds from `.devcontainer/Containerfile`, creates a Python virtual environment, and installs `requirements.txt`.

For the VS Code run configuration, copy the example env file first:

```sh
cp 1blu-ddns.env.example 1blu-ddns.env
```

Then edit `1blu-ddns.env` with real credentials and start `Run 1Blu DDNS` from the VS Code Run and Debug panel.

## Development

Run tests:

```sh
python -m unittest
```

## Notes

1Blu does not provide a public DDNS API. This updater uses the 1Blu customer interface session flow, including CSRF tokens and optional TOTP, then submits the full DNS record set back to the DNS editor endpoint.
