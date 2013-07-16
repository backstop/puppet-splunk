# Class: splunk::linux_forwarder
#
# Modified version of dhogland/splunk
# (https://github.com/dhogland/splunk). Modified
# by Will Ferrer and Ethan Brooks of Run the Business LLC
#
class splunk::linux_forwarder {
  file {$splunk::params::linux_stage_dir:
    ensure => directory,
    owner  => 'root',
    group  => 'root',
  }

  file {'splunk_installer':
    path    => "${splunk::params::linux_stage_dir}/${splunk::params::installer}",
    source  => "${splunk::params::installerfilespath}${splunk::params::installer}",
    require => File[$splunk::params::linux_stage_dir],
  }

  package {'splunkforwarder':
    ensure   => installed,
    source   => "${splunk::params::linux_stage_dir}/${splunk::params::installer}",
    provider => $::operatingsystem ? {
      /(?i)(centos|redhat)/   => 'rpm',
      /(?i)(debian|ubuntu)/ => 'dpkg',
    },
    notify   => Exec['start_splunk'],
  }

  exec {'start_splunk':
    creates => '/opt/splunkforwarder/etc/licenses',
    command => '/opt/splunkforwarder/bin/splunk start --accept-license',
    timeout => 0,
  }

  exec {'set_forwarder_port':
    unless  => "/bin/grep -P \"server \= \[?${splunk::params::logging_server}\]?:${splunk::params::logging_port}\" /opt/splunkforwarder/etc/system/local/outputs.conf",
    command => "/opt/splunkforwarder/bin/splunk add forward-server ${splunk::params::logging_server}:${splunk::params::logging_port} -auth ${splunk::params::splunk_admin}:${splunk::params::splunk_admin_pass}",
    require => Exec['set_monitor_default'],
    notify  => Service['splunk'],
  }

  exec {'set_monitor_default':
    unless  => '/bin/grep \/var\/log /opt/splunkforwarder/etc/apps/search/local/inputs.conf',
    command => "/opt/splunkforwarder/bin/splunk add monitor \"/var/log/\" -auth ${splunk::params::splunk_admin}:${splunk::params::splunk_admin_pass}",
    require => Exec['start_splunk','set_boot'],
  }

  exec {'set_boot':
    creates => '/etc/init.d/splunk',
    command => '/opt/splunkforwarder/bin/splunk enable boot-start',
    require => Exec['start_splunk'],
  }

  file {'/etc/init.d/splunk':
    ensure  => file,
    mode    => '0755',
    require => Exec['set_boot']
  }

  service {'splunk':
    ensure     => running,
    enable     => true,
    hasstatus  => true,
    hasrestart => true,
    require    => File['/etc/init.d/splunk'],
  }
}
