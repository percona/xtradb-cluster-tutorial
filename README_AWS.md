# Percona XtraDB Cluster Tutorial AWS Setup

You can skip this if you aren't planning on using AWS.  

In a nutshell, you need this:

* AWS access key
* AWS secret access key
* A Keypair name and path for each AWS region you intend to use
* Whatever security groups you'll need for the environments you intend to launch.

## AWS Details

You'll need an AWS account setup with the following information in a file called ~/.aws_secrets:

```yaml
access_key_id: YOUR_ACCESS_KEY
secret_access_key: THE_ASSOCIATED_SECRET_KEY
keypair_name: KEYPAIR_ID
keypair_path: PATH_TO_KEYPAIR_PEM
instance_name_prefix: SOME_NAME_PREFIX
default_vpc_subnet_id: subnet-896602d0
```

### Multi-region

AWS Multi-region can be supported by adding a 'regions' hash to the .aws_secrets file:

```yaml
access_key_id: YOUR_ACCESS_KEY
secret_access_key: THE_ASSOCIATED_SECRET_KEY
keypair_name: jay
keypair_path: /Users/jayj/.ssh/jay-us-east-1.pem
instance_name_prefix: Jay
default_vpc_subnet_id: subnet-896602d0
regions:
  us-east-1:
    keypair_name: jay
    keypair_path: /Users/jayj/.ssh/jay-us-east-1.pem
    default_vpc_subnet_id: subnet-896602d0
  us-west-1:
    keypair_name: jay
    keypair_path: /Users/jayj/.ssh/jay-us-west-1.pem
  eu-west-1:
    keypair_name: jay
    keypair_path: /Users/jayj/.ssh/jay-eu-west-1.pem
```

Note that the default 'keypair_name' and 'keypair_path' can still be used. Region will default to 'us-east-1' unless you specifically override it.

### Boxes and Multiple AWS Regions

AMI's are region-specific. The AWS Vagrant boxes you use must include AMI's for each region in which you wish to deploy.

For an example, see the regions listed here: https://vagrantcloud.com/grypyrg/centos-x86_64

Packer, which is used to build this box, can be configured to add more regions if desired, but it requires building a new box.

### AWS VPC Integration

The latest versions of grypyrg/centos-x86-64 boxes require a VPC since AWS now requires VPC for all instances. 

As shown in the example above, you must set the `default_vpc_subnet_id` in the ~/.aws_secrets file. You can override this on a per-region basis.

You can also pass a `subnet_id` into the `provider_aws` method using an override in your Vagrantfile.
