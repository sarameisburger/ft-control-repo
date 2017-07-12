class profile::sudoers {

  user { 'example':
    managehome => true,
  }

  file { '/etc/sudoers.d/example':
    ensure  => file,
    mode    => '0440',
    owner   => 'root',
    group   => 'root',
    content => epp('profile/example_sudoer_file.epp'),
  }

}
