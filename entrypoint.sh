#!/bin/sh


if [ -f /etc/os-release ]; then
  . /etc/os-release
  if [ "$ID" = "ubuntu" ]; then
    sudo apt-get update
    sudo apt-get install -y ansible
    sudo apt-get install -y jq
  else
    echo "not ubuntu"
#    exit 1
  fi
else
  echo "/etc/os-release가 존재하지 않습니다. OS 정보를 확인할 수 없습니다."
fi

### Variables #############################################################
#LOGIN_NODE_NAME="login"
#LOGIN_NODE_IP="10.1.1.2"
#CONTROLLER_NODE_NAME="controller"
#CONTROLLER_NODE_IP="10.1.1.3"
#WORKER_NODES='{"worker001": "10.1.1.4", "worker002": "10.1.1.5"}'
LOGIN_NODE="{\"$LOGIN_NODE_NAME\": \"$LOGIN_NODE_IP\"}"
CONTROLLER_NODE="{\"$CONTROLLER_NODE_NAME\": \"$CONTROLLER_NODE_IP\"}"
###########################################################################

### Directories ###########################################################
URL="https://github.com/set-e/gitops-ansible.git"
REPO="$(basename $URL .git)"
WORK_DIR="/opt"
ANSIBLE_DIR="$WORK_DIR/$REPO"
INVENTORY_DIR="$ANSIBLE_DIR/inventory"
INVENTORY_FILE="$INVENTORY_DIR/hosts.yml"
###########################################################################

if [ -d "$ANSIBLE_DIR" ]; then
  rm -rf $ANSIBLE_DIR
fi

cd $WORK_DIR
git clone $URL

add_hosts() {
  INPUT_JSON="$@"
  keys=$(echo "$INPUT_JSON" | jq -r 'keys[]')
  for key in $keys
  do
    value=$(echo "$INPUT_JSON" | jq -r ".\"$key\"")
    echo "        $key:"
    echo "          ansible_host: $value"
  done
}

cat <<EOF > $INVENTORY_FILE
all:
  vars:
    ansible_ssh_private_key_file: $KEYPAIR_FILE
    cluster_name: "ml-cluster"

  children:
    login_node_group:
      hosts:
EOF
add_hosts $LOGIN_NODE >> $INVENTORY_FILE

cat <<EOF >> $INVENTORY_FILE
    controller_node_group:
      hosts:
EOF
add_hosts $CONTROLLER_NODE >> $INVENTORY_FILE

cat <<EOF >> $INVENTORY_FILE
    worker_node_group:
      hosts:
EOF
add_hosts $WORKER_NODES >> $INVENTORY_FILE

cd $ANSIBLE_DIR
ansible-playbook playbooks/all.yml -i $INVENTORY_FILE > /tmp/ansible.log