resource "null_resource" "ansible_init_manager" {

  provisioner "local-exec" {
    command = " ansible-playbook ansible/nsx.yml -e @../../variables.json"
  }
}