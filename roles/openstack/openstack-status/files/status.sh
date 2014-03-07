#! /usr/bin/env bash
set -e -u

#allow services to start after port 22 opens
sleep 30

source /root/keystonerc_admin
/usr/bin/openstack-status  || true