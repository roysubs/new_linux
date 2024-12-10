#!/bin/bash

# Setup ansible on debian
sudo apt update && sudo apt upgrade -y

# Install Required Dependencies
sudo apt install -y python3 python3-pip sshpass

# Install Ansible
# Debian includes Ansible in its repositories, but it might not be the latest version.
# sudo apt install -y ansible
# So instead install the latest Ansible via PPA (Preferred)
sudo apt install -y software-properties-common
sudo add-apt-repository --yes --update ppa:ansible/ansible
sudo apt install -y ansible
ansible --version

# Ansible communicates with managed hosts over SSH. Ensure SSH access is configured.
# Generate an SSH key (if you don’t already have one):
ssh-keygen
# Copy the SSH key to the remote hosts:
# ssh-copy-id user@remote_host
# Replace user with the remote username and remote_host with the target host's IP address or hostname.

# Test SSH connectivity:
ssh user@remote_host

# Configure the Inventory File
# Ansible uses an inventory file to define managed hosts.
# The default inventory file is located at /etc/ansible/hosts.
sudo vi /etc/ansible/hosts
# Add your hosts, e.g.:
# [webservers]
# 192.168.1.10
# 192.168.1.11
# 
# [dbservers]
# 192.168.1.20
# Save and exit.

# Test the Configuration
# Run a simple ping module test against your hosts.
ansible all -m ping
# If successful, you’ll see pong responses from the hosts.

# (Optional) Install Additional Collections
# You can install additional modules and plugins from the Ansible Galaxy repository.
ansible-galaxy collection install <collection_name>

# Start Using Ansible
# Create and run playbooks to automate tasks.
# Playbooks are YAML files that describe the tasks to execute.

# Example playbook (example.yml):

# - hosts: webservers
#   tasks:
#     - name: Install Nginx
#       apt:
#         name: nginx
#         state: present

# Run the playbook:
# ansible-playbook example.yml
