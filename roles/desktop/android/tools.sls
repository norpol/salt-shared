include:
  - python
{% if (grains['os'] == 'Ubuntu' or grains['os'] == 'Mint') %}
  - repo.ubuntu
{% endif %}

tools:
  pkg.installed:
    - pkgs:
      - android-tools-adb
      - android-tools-adbd
      - android-tools-fastboot

python-adb:
  pip.installed:
    - name: git+https://github.com/google/python-adb


{% if (grains['os'] == 'Ubuntu' or grains['os'] == 'Mint') %}

{% from "repo/ubuntu.sls" import apt_add_repository %}
{{ apt_add_repository("heimdall-ppa", "modycz/heimdall") }}

heimdall:
  pkg.installed:
    - pkgs:
      - heimdall
    - require:
      - cmd: heimdall-ppa
{% endif %}