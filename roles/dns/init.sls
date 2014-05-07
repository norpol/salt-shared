djbdns:
  pkg.installed:
    - pkgs:
      - djbdns
      - daemontools
      - runit

{% for u in ("Gdnscache", "Gdnslog", "Gtinydns", "Gaxfrdns") %}
{{ u }}:
  user.present:
    - shell: /bin/false
    - home: /home/{{ u }}
    - system: True
    - require_in:
      - file: /etc/sv
{% endfor %}

{% for u in ("dnscache", "tinydns", "axfrdns") %}
/var/log/{{ u }}:
  file.directory:
    - makedirs: True
    - group: adm
    - user: Gdnslog
    - require:
      - user: Gdnslog

/etc/sv/{{ u }}/log/main:
  file.symlink:
    - target: /var/log/{{ u }}
    - require:
      - file: /var/log/{{ u }}
      - file: /etc/sv

{% for v in ("", "/log") %}
/etc/sv/{{ u }}{{ v }}/run:
    cmd.run:
     - name: chmod +x /etc/sv/{{ u }}{{ v }}/run
     - unless: test -x /etc/sv/{{ u }}{{ v }}/run
     - require:
       - file: /etc/sv
{% endfor %}  
{% endfor %}  

/etc/sv:
  file.recurse:
    - source: salt://roles/dns/sv
    - template: jinja
    - defaults: 
        dnscache_ip: {{ salt['network.ip_addrs']()[0] }}
{% if pillar.dns_server.cache_ip %}
    - context: 
        dnscache_ip: {{ pillar.dns_server.cache_ip }}
{% endif %}

/etc/sv/tinydns/root/data:
  file.managed:
    - source: {{ "%s" % pillar.dns_server.data if pillar.dns_server.data else 'salt://roles/dns/localhost' }}
    - require:
      - file: /etc/sv

compiled_data:
  cmd.run:
    - name: make
    - cwd: /etc/sv/tinydns/root
    - watch:
      - file: /etc/sv/tinydns/root/data
    - watch_in: 
      - cmd: dnscache_service
      - cmd: tinydns_service
      - cmd: axfrdns_service

create_seed:
  cmd.run:
    - name: dnscache-conf Gdnscache Gdnslog /tmp/dnscache.$$; mv /tmp/dnscache.$$/seed /etc/sv/dnscache/seed; rm -r /tmp/dnscache.$$
    - unless: test -e /etc/sv/dnscache/seed
    - require:
      - file: /etc/sv
      - pkg: djbdns

/etc/sv/axfrdns/tcp:
  file.managed:
    - source: salt://roles/dns/axfr_permissions
    - template: jinja
    - context:
      permissions: {{ pillar.dns_server.axfr_permissions|d(None) }}

compiled_tcp:
  cmd.run:
    - name: make
    - cwd: /etc/sv/axfrdns
    - watch:
      - file: /etc/sv/axfrdns/tcp
    - watch_in: 
      - cmd: axfrdns_service
    - require:
      - cmd: compiled_data

{% if pillar.dns_server.axfr_export_cmd|d(false) %}
axfrdns_export:
  cmd.run:
    - name: {{ pillar.dns_server.axfr_export_cmd }}
    - watch_in:
      - cmd: axfrdns_service
{% endif %}

{% set dnscache_serve_to= salt['network.ip_addrs']() %}
{% set dnscache_follow= [('0.0.127.in-addr.arpa','127.0.0.1')] %}
{% if pillar.dns_server.cache_serve_to %}
    {% set dnscache_serve_to= pillar.dns_server.cache_serve_to %}
{% endif %}
{% if pillar.dns_server.cache_follow %}
    {% set dnscache_follow= pillar.dns_server.cache_follow %}
{% endif %}

/etc/sv/dnscache/root/ip:
  file.directory:
    - makedirs: True

{% for n in dnscache_serve_to %}
/etc/sv/dnscache/root/ip/{{ n }}:
  file.touch:
    - require:
      - file: /etc/sv
      - file: /etc/sv/dnscache/root/ip
    - require_in: 
      - cmd: dnscache_service
    - watch_in:
      - cmd: dnscache_service
{% endfor %}

{% for n,s in dnscache_follow.iteritems() %}
/etc/sv/dnscache/root/servers/{{ n }}:
  file.managed:
    - source: salt://roles/dns/dnsfollow
    - template: jinja
    - context:
        ip: {{ "%s" % s if s != '' else '127.0.0.1' }}
    - require:
      - file: /etc/sv
    - require_in: 
      - cmd: dnscache_service
    - watch_in:
      - cmd: dnscache_service
{% endfor %}

{% for u in ("dnscache", "tinydns", "axfrdns") %}
{{ u }}_install:
  cmd.run:
    - name: update-service --add /etc/sv/{{ u }}
    - unless: test -e /etc/service/{{ u }}
    - require:
      - pkg: djbdns
      - file: /etc/sv
      - file: /var/log/{{ u }}

{{ u }}_service:
   cmd.run:
    - name: svc -t /etc/service/{{ u }}
    - onlyif: test -e /etc/service/{{ u }}
    - require:
      - cmd: {{ u }}_install
{% endfor %}
