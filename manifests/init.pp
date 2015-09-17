# See README.md for more documentation.
class geoserver(
  $server_name          = 'geoserver',
  $server_port          = 8105,
  $connector_port       = 8180,
  $workers              = 1,
  $address              = $::fqdn,
  $data_dir             = undef,
  $embedded_geowebcache = true,
  $cache_dir            = '/var/cache/sig/tiles',
  $java_xmx             = undef,
  $ssl_only             = true,
  $truststorefile       = '/srv/tomcat/ssl/georchestra.ts',
  $truststorepass       = 'GeoServer',
) {
  package { 'libjai-imageio-core-java':
    ensure => present,
  }

  $last_worker = $workers - 1
  $server_names = range(
    "${server_name}0",
    "${server_name}${last_worker}")

  if $java_xmx == undef {
    $memorysize = split($::memorysize, ' ')
    validate_re($memorysize[0], '^\d+(\.\d+)?$')
    $memory_per_worker = ($memorysize[0] - 0.5) / $workers
    if $memory_per_worker > 2 {
      $_java_xmx = '2G'
    } else {
      $_java_xmx = "${memory_per_worker}G"
    }
  } else {
    $_java_xmx = $java_xmx
  }

  geoserver::worker { $server_names:
    data_dir => $data_dir,
    java_xmx => $_java_xmx,
  }

  if $embedded_geowebcache {
    exec { "/bin/mkdir -p `dirname ${cache_dir}`":
      unless => "/usr/bin/test -d `dirname ${cache_dir}`",
      before => File[$cache_dir],
    }
    file { $cache_dir:
      ensure => directory,
      owner  => 'tomcat',
      group  => 'tomcat',
      mode   => '0755',
    }
  }
}
