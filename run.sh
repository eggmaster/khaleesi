#! /usr/bin/env bash
set -e -u

#pip install ansible > /dev/null 2>&1

image_id_for_name() {
    local name=$1; shift
    glance image-list | egrep " $name " |  cut -f2 -d '|' | tr -d ' '
}

network_id_for_name() {
    local name=$1; shift
    neutron net-list  -F id -- --name=$name | awk  'NR==4' | awk '{print $2}'
}

main() {
    local rdo_icehouse_f20_baseurl='http://repos.fedorapeople.org/repos/openstack/openstack-icehouse/fedora-20'
    local default_flavor_id=4
    local default_floating_nw_name='external'

    local key_file=${KEY_FILE:-/key.pem }
    local key_name=${SSH_KEY_NAME:-'key'}
    chmod 600 $key_file

    local node_prefix=${NODE_PREFIX:-st}

    local image_id=${IMAGE_ID:-$(image_id_for_name 'Fedora 20')}
    local flavor_id=${FLAVOR_ID:-$default_flavor_id}

    local floating_nw_name=${FLOATING_NETWORK_NAME:-$default_floating_nw_name}

    local baseurl=${REPO_BASEURL:-$rdo_icehouse_f20_baseurl}
    local network_name=${NETWORK_NAME:-'default'}
    local net_1=$(network_id_for_name $network_name)

cat > settings.yml <<-EOF
# job config

workarounds_disabled: yes
selinux: permissive  #[permissive, enforcing]

config:
  product: rdo
  version: icehouse
  repo: production
  verbosity:
    - info
    - warning

# OpenStack controller settings
os_auth_url: '$OS_AUTH_URL'
os_username: $OS_USERNAME
os_password: $OS_PASSWORD
os_tenant_name: $OS_TENANT_NAME

# instance settings
node_prefix: $node_prefix
network_ids: [{ net-id: '$net_1' }]
image_id: $image_id
ssh_private_key: $key_file
ssh_key_name: $key_name
flavor_id: $flavor_id
floating_network_name: $floating_nw_name

nodes:
  - name: "{{ node_prefix }}rdopkg"
    image_id: "{{ image_id }}"
    key_name: "{{ ssh_key_name }}"
    flavor_id: "{{ flavor_id }}"
    network_ids: "{{ network_ids }}"
    hostname: packstack.example.com
    groups: "packstack,openstack_nodes"

#VM settings
epel_repo: download.fedoraproject.org/pub/epel/6/
gpg_check: 0
ntp_server: clock.redhat.com
reboot_delay: +1

# Currently sudo w/ NOPASSWD must be enabled in /etc/sudoers for sudo to work
sudo: yes
remote_user: fedora
sudo_user: root

tempest:
    puppet_file: /tmp/tempest_init.pp
    checkout_dir: /var/lib/tempest
    revision: 'stable/havana'
    test_name: 'tempest'
    #test_name: 'tempest.scenario.test_network_basic_ops'
    exclude:
        files:
            - test_server_rescue
            - test_server_actions
            - test_load_balancer
            - test_vpnaas_extensions
        tests:
            - test_rescue_unrescue_instance
            - test_create_get_delete_object
            - test_create_volume_from_snapshot
            - test_service_provider_list
            - test_ec2_
            - test_stack_crud_no_resources
            - test_stack_list_responds

EOF



### disabled since it is already in <git.root>/ansible.cfg
##export ANSIBLE_HOST_KEY_CHECKING=False
##export ANSIBLE_ROLES_PATH=$WORKSPACE/khaleesi/roles
##export ANSIBLE_LIBRARY=$WORKSPACE/khaleesi/library:$VIRTUAL_ENV/share/ansible

ansible-playbook -i local_hosts  \
 playbooks/packstack/rdo_neutron_aio_playbook.yml \
    --extra-vars @settings.yml -v -u fedora
}

main "$@"
