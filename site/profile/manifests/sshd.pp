## Include augeasproviders_ssh module from forge or github.
#### https://forge.puppet.com/herculesteam/augeasproviders_ssh
## Include augeasproviders_core from forge or github.
#### https://github.com/hercules-team/augeasproviders_core

class profile::sshd {

  package { 'sshd':
    ensure => installed,
  }

  service { 'sshd':
    ensure => running,
  }

  sshd_config { "PermitRootLogin":
    ensure => present,
    value  => "no",
  }

  sshd_config { "PasswordAuthentication":
    ensure    => present,
    value     => "yes",
  }

  sshd_config { "ChallengeResponseAuthentication":
    ensure    => present,
    value     => "no",

  }

}
