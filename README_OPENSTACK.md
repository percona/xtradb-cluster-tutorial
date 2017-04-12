# Percona XtraDB Cluster Tutorial - Openstack

## Setup and Configuration

For this to run, you'll need a custom Vagrantbox with an image to boot from on your Openstack Cloud.

A publically available image for CentOS can be found here: https://github.com/grypyrg/packer-percona It will need to be rebuilt for other clouds.

Perconians can use a prebuilt image in our Openstack lab with this command: 

```
vagrant box add grypyrg/centos-x86_64 --provider openstack
```

You'll also need your secrets setup in ~/.openstack_secrets:

```yaml
---
endpoint: http://controller:5000/v2.0/tokens
tenant: tenant_name
username: your_user
password: your_pw
keypair_name: your_keypair_name
private_key_path: the_path_to_your_pem_file
```

Finally, you'll need the vagrant-openstack-plugin:

```
vagrant plugin install vagrant-openstack-plugin
```
