# Homelab setup notes

** Work in progress **

## Commands

Some usefull commands

```shell

# Edit vault
ansible-vault edit group_vars/all/vault.yml

# Configure container with excludes
ansible-playbook -i inventorys -J -k -K --limit grafana --skip-tags user,ssh_config,grafana.base.setup,loki.setup container_configure.yml

# Create new container
ansible-playbook -i inventorys -J container_create.yml

# Dependencies Installation
ansible-galaxy collection install -r requirements.yml --force
pip install -r requirements.txt

# Generate Random Keys
openssl rand -base64 24 # 24 = length

# Run command as user
runuser -u <user> -- <COMMAND>
```

## Add new container

To add a new container you just have to add it to the `lxcs` section in the file `roles/pve/vars/main.yml`. Here is a example you can copy over an edit the values:

```yaml
    vmid: ''
    node: 'my_node'
    cores: 2
    memory: 1024
    disk: 'zfs:10'
    netif:
      net0: "name=eth0,gw=192.168.1.x,ip=192.168.1.xx/24,bridge=vmbr0,firewall=0,tag=1"
```

## Alloy configuration

Alloy is configured to use config files so it is more flexible

```yaml
- name: Install alloy
  ansible.builtin.include_tasks: tasks/alloy.yml
  vars:
    alloy_config_files:
      - { "src": "alloy/logfiles.alloy.j2", "dest": "logfiles.alloy" }
      - { "src": "alloy/prometheus.alloy.j2", "dest": "prometehus.alloy" }
  tags:
    - <role>.alloy
```

### Alloy config examples

Prometheus metrics
```json
prometheus.scrape "caddy" {
    targets = [{
        __address__ = "localhost:2019",
    }]
    forward_to = [prometheus.remote_write.default.receiver]
    job_name   = "caddy"
}

prometheus.remote_write "default" {
    endpoint {
        url = "{{ prometheus_write_url }}"

        queue_config { }

        metadata_config { }
    }
}
```

Logfile config
```json
local.file_match "local_files" {
    path_targets = [{"__path__" = "/var/log/caddy/*.log"}]
    sync_period = "5s"
}

loki.source.file "log_scrape" {
    targets    = local.file_match.local_files.targets
    forward_to = [loki.process.process_logs.receiver]
    tail_from_end = true
}

loki.process "process_logs" {

    // Use filename to get the hostename
    stage.regex {
        source = "filename"
        expression = ".*/(?P<host_name>[^.]+)\\..*"
    }

    // Extract some json values to generate labels
    stage.json {
        // default source is the whole log line (`message`)
        expressions = {
            remote_ip = "request.remote_ip",
            client_ip = "request.client_ip",
            status    = "status",
        }
        drop_malformed = true
    }

    // Set the values as labels so I can serach for them
    stage.labels {
        values = {
            host_name = "host_name",
            remote_ip = "remote_ip",
            client_ip = "client_ip",
            status    = "status",
        }
    }

    forward_to = [loki.write.grafana_loki.receiver]
}

loki.write "grafana_loki" {
    endpoint {
        url = "{{ loki_push_url }}"
    }
}
```
