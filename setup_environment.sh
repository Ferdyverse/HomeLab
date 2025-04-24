#!/bin/bash

echo "Create venv"
python3 -m venv .venv

echo "Activate venv"
source .venv/bin/activate

echo "Install pip requirements"
pip install -r requirements.txt

echo "Install Ansible collections"
ansible-galaxy install -r requirements.yml --force
