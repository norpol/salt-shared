include:
  - .ppa
  - .grub

{% if salt['pillar.get']('docker:custom_storage', false) %}
{% from 'storage/lib.sls' import storage_setup with context %}
{{ storage_setup(salt['pillar.get']('docker:custom_storage')) }}
{% endif %}

docker:
  pkg.installed:
    - pkgs:
      - iptables
      - ca-certificates
      - lxc
      - cgroup-bin
      - lxc-docker
{% if grains['os'] == 'Ubuntu' %}
    - require:
      - pkgrepo: docker_ppa
{% endif %}

  file.managed:
    - name: /etc/default/docker
    - template: jinja
    - source: salt://roles/docker/files/docker
    - context:
      docker: {{ pillar.docker|d({}) }}
  service.running:
    - enable: true
    - require:
      - pkg: docker
      - sls: roles.docker.grub
    - watch:
      - file: docker
