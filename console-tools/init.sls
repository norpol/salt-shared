
{% if grains['os_family'] == 'Debian' %}
base-deps:
  pkg.installed:
    - pkgs:
      - mc
      - unzip
      - zip
      - cabextract
      - ncdu
      - tree
      - pwgen
      - command-not-found
      - htop
      - iftop
      - iotop
      - blktrace
      - dstat
      - cpu-checker
      - iperf
      - glances
      - pciutils
      - pv
      - socat
      - netcat
      - nethogs
      - rsync
      - trickle
      - curl
      - elinks
      - links
      - jupp
      - sox
      - xmlstarlet
      - html-xml-utils
      - etherwake
      - httpie

{% endif %}
