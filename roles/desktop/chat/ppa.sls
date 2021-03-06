{% if (grains['os'] == 'Ubuntu' or grains['os'] == 'Mint') %}
include:
  - repo.ubuntu
{% endif %}

{% if (grains['os'] == 'Ubuntu' or grains['os'] == 'Mint') %}

{% from "repo/ubuntu.sls" import apt_add_repository %}
{{ apt_add_repository("whatsapp_ppa", "whatsapp-purple/ppa") }}
{{ apt_add_repository("pidgin_gnome_keyring_ppa", "pidgin-gnome-keyring/ppa") }}

{% endif %}

{% if grains['os_family'] == 'Debian' %}
gajim_ppa:
  pkgrepo.managed:
    - repo: 'deb ftp://ftp.gajim.org/debian unstable main'
    - file: /etc/apt/sources.list.d/gajim.list
    - key_url: salt://roles/desktop/chat/gajim_key.asc

{% endif %}
