### Cloudgov Sandbox Necessities
Create a rds instance for use with the system called `spiffworkflow-db`:
`cf create-service aws-rds micro-psql spiffworkflow-db`

In order to utilize the newly created db, the following security groups will also need to be added to your sandbox:
`cf bind-security-group trusted_local_networks ORGNAME --lifecycle running --space SPACENAME`
`cf bind-security-group trusted_local_networks_egress ORGNAME --lifecycle running --space SPACENAME`

In order to successfully get the front end to redirect in the sandbox space, run the following command:
`cf bind-security-group public_networks_egress ORGNAME --lifecycle running --space SPACENAME`

In order to enable the backend to connect to the connector proxy, run the following command, using your value for slug in vars.yml:
`cf add-network-policy spiffworkflow((slug))-backend spiffworkflow((slug))-connector --port 61443 --protocol tcp`

For example, if your value for `slug` in `vars.yml` was `-abc123` then this command would be:
`cf add-network-policy spiffworkflow-abc123-backend spiffworkflow-abc123-connector --port 61443 --protocol tcp`

### Generating a Github SSH Key
In order to utilize some of the processes in this application, we utilize a forked process model repo, accessible via ssh endpoint.
`git@github.com:GSA-TTS/gsa-process-models.git`.
Generate a new ssh key pairing for use with git, using `ssh-keygen -t rsa -b 4096 -C "my-git@email.blah"`. Once this has been created, navigate to the location where the keys are stored, usually `~/.ssh/` and copy the `<my_key_name>.pub` to [Github SSH Keys](https://github.com/settings/keys). Then, copy the plaintext `<my_key_name>` private key to `vars.yml` under the variable `github_ssh_key`. Alternatively, if you wish to use the actual keyfile and copy it onto the deployed instance for use, you can use the environment var `SPIFFWORKFLOW_BACKEND_GIT_SSH_PRIVATE_KEY_PATH:`

### Deploying
- Create a database service
- Copy vars.yml-template to `vars.yml`
- `cf push --vars-file vars.yml`