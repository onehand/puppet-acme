# = Define: acme::crt
#
# Used as exported ressource to ship a signed CRT.
#
# == Parameters:
#
# [*crt_content*]
#   actual certificate content.
#
# [*crt_chain_content*]
#   actual certificate chain file content.
#
# [*domain*]
#   Certificate commonname / domainname.
#
define acme::deploy::crt(
  $crt_content,
  $crt_chain_content,
  $ocsp_content,
  $domain = $name
) {
  require ::acme::params

  $cfg_dir = $::acme::params::cfg_dir
  $crt_dir = $::acme::params::crt_dir
  $key_dir = $::acme::params::key_dir

  $user = $::acme::params::user
  $group = $::acme::params::group

  $crt = "${crt_dir}/${name}/cert.pem"
  $ocsp = "${crt_dir}/${name}/cert.ocsp"
  $key = "${key_dir}/${name}/private.key"
  $dh = "${cfg_dir}/${domain}/params.dh"
  $crt_chain = "${crt_dir}/${name}/chain.pem"
  $crt_full_chain = "${crt_dir}/${name}/fullchain.pem"
  $crt_full_chain_with_key = "${key_dir}/${name}/fullchain_with_key.pem"

  file { $crt:
    ensure  => file,
    owner   => 'root',
    group   => $group,
    content => $crt_content,
    mode    => '0644',
  }

  if !empty($ocsp_content) {
    file { $ocsp:
      ensure  => file,
      owner   => 'root',
      group   => $group,
      content => base64('decode', $ocsp_content),
      mode    => '0644',
    }
  } else {
    file { $ocsp:
      ensure => absent,
      force  => true,
    }
  }

  concat { $crt_full_chain:
    owner => 'root',
    group => $group,
    mode  => '0644',
  }

  concat { $crt_full_chain_with_key:
    owner => 'root',
    group => $group,
    mode  => '0640',
  }

  concat::fragment { "${domain}_key" :
    target => $crt_full_chain_with_key,
    source => $key,
    order  => '01',
  }

  concat::fragment { "${domain}_fullchain":
    target    => $crt_full_chain_with_key,
    source    => $crt_full_chain,
    order     => '10',
    subscribe => Concat[$crt_full_chain],
  }

  concat::fragment { "${domain}_crt":
    target  => $crt_full_chain,
    content => $crt_content,
    order   => '10',
  }

  concat::fragment { "${domain}_dh":
    target  => $crt_full_chain,
    source  => $dh,
    order   => '30',
    require => File[$dh],
  }

  if ($crt_chain_content and $crt_chain_content =~ /BEGIN CERTIFICATE/) {
    file { $crt_chain:
      ensure  => file,
      owner   => 'root',
      group   => $group,
      content => $crt_chain_content,
      mode    => '0644',
    }
    concat::fragment { "${domain}_ca":
      target  => $crt_full_chain,
      content => $crt_chain_content,
      order   => '50',
    }
  } else {
    file { $crt_chain:
      ensure => absent,
      force  => true,
    }
  }

}
