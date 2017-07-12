class role::linux_base {
  include profile::linux_baseline
  include profile::sshd
}
