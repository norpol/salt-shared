include:
  - .ppa
  - nginx
  - roles.docker

dokku-alt:
  pkg:
    - installed
{% if grains['os'] == 'Ubuntu' %}
    - require:
      - pkgrepo: dokku-alt
      - pkg: docker
      - pkg: nginx
{% endif %}
  service.running:
    - require:
      - pkg: dokku-alt

