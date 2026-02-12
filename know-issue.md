# Known Issues

## SSH Connection Timeout During `terraform apply`

When running `terraform apply`, the process successfully creates the compute instances but then fails with a timeout error on the `ssh_resource` step. The error message will look similar to this:

```
ssh_resource.test-ssh-computes[1]: Still creating... [01m30s elapsed]

## and when timeout

Error: execution of command 'echo 'SSH connection to OpenSDN Controller successful'' failed: context deadline exceeded: dial tcp 103.29.190.175:22: connect: connection refused
```

### Cause

This issue can occur if the `cloud-init` script, which runs on the first boot of the instance, fails to correctly restart the SSH service (`sshd`) after applying its configuration. This leaves the instance running but temporarily unreachable via SSH, causing Terraform's connection test to fail.

### Solution

The instances have been created, but they need to be rebooted to ensure the SSH service is running correctly.

1.  **Log in to space portal**.
2.  Navigate to the **Compute** section.
3.  Identify the instances created by this project (e.g., `tf-openstack-controller`, `tf-compute-0`, etc.).
4.  For each of the newly created instances, perform a **Restart**.
5.  After the instances have rebooted, run `terraform apply` again. Terraform will recognize that the instances already exist and will skip creating them. It will then re-attempt the SSH connection test, which should now succeed.
