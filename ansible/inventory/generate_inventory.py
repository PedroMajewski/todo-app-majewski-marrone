#!/usr/bin/env python3
"""Gera o inventário do Ansible a partir de `terraform output -json`.

Uso: python3 generate_inventory.py <terraform-output.json> > inventory/hosts.yml

- VM da aplicação: acessada pelo IP elástico.
- VM do banco: acessada pelo IP PRIVADO, passando pela VM da aplicação
  (ProxyCommand), pois não aceita SSH vindo da internet.
O arquivo gerado é JSON (YAML válido) e não contém segredos.
"""
import json
import os
import sys


def main() -> None:
    with open(sys.argv[1], encoding="utf-8") as handle:
        outputs = {name: item["value"] for name, item in json.load(handle).items()}

    key_file = os.environ.get("SSH_KEY_FILE", "~/.ssh/todo_deploy")
    known_hosts = os.environ.get("SSH_KNOWN_HOSTS_FILE", "~/.ssh/known_hosts_todo")
    user = outputs["ssh_user"]
    app_ip = outputs["app_public_ip"]
    common_ssh = f"-o UserKnownHostsFile={known_hosts} -o StrictHostKeyChecking=accept-new"
    proxy = (
        f'-o ProxyCommand="ssh -W %h:%p -q -i {key_file} {common_ssh} {user}@{app_ip}" '
        f"{common_ssh}"
    )

    inventory = {
        "all": {
            "vars": {
                "ansible_user": user,
                "ansible_ssh_private_key_file": key_file,
                "env_name": outputs["environment"],
                "app_fqdn": outputs["app_fqdn"],
                "app_url": outputs["app_url"],
                "app_public_ip": app_ip,
                "app_private_ip": outputs["app_private_ip"],
                "db_private_ip": outputs["db_private_ip"],
                "mongo_data_volume_id": outputs["mongo_data_volume_id"],
                "backup_bucket": outputs["backup_bucket"],
                "backup_prefix": outputs["backup_prefix"],
                "aws_region": outputs["aws_region"],
            },
            "children": {
                "app": {
                    "hosts": {
                        outputs["app_vm_name"]: {
                            "ansible_host": app_ip,
                            "ansible_ssh_common_args": common_ssh,
                        }
                    }
                },
                "db": {
                    "hosts": {
                        outputs["db_vm_name"]: {
                            "ansible_host": outputs["db_private_ip"],
                            "ansible_ssh_common_args": proxy,
                        }
                    }
                },
            },
        }
    }
    json.dump(inventory, sys.stdout, indent=2)
    sys.stdout.write("\n")


if __name__ == "__main__":
    main()
