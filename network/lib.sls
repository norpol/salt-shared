{% macro config_system(sys_network) %}

{% if sys_network %}
network-system:
  network.system:
{% for item, data in sys_network.iteritems() %}
    - {{ item }}: {{ data }}{% endfor %}
{% endif %}

{% endmacro %}

{% macro config_interfaces(interfaces) %}

{% for item, data in interfaces.iteritems() %}
network-interface-{{ item }}:
  network.managed:
    - name: {{ item }}
{% for sub, subvalue in data.iteritems() %}
    - {{ sub }}: {{ subvalue }}
{% endfor %}
    - require_in:
      - file: /etc/init/networking.override
{% endfor %}

{% endmacro %}


{% macro config_routes(routes) %}

{% for interface, data in routes.iteritems() %}
network-route-{{ interface }}:
{% if grains['os_family'] == 'Debian' %}
  file.replace:
    - name: /etc/network/interfaces
    - flags:
      - MULTILINE
      - IGNORECASE
    - bufsize: file
    - pattern: "^iface {{ interface }} inet ([a-z0-9]+)[ ]*$(^[ ]+(up)|(down) ip route .+$)?"
    - repl: "iface {{ interface }} inet \\1\\n{% for ipaddr, subdata in data.iteritems() %}    up  ip route add {{ ipaddr }}/{{ subdata.netmask }} dev {{ interface }}\n    down ip route del {{ ipaddr }}/{{ subdata.netmask }} dev {{ interface }}\n{% endfor %}"
    - require_in:
      - file: /etc/init/networking.override
  cmd.run:
    - name: "ifup --force {{ interface }}"
    - require:
      - file: network-route-{{ interface }}
{% else %}
  network.routes:
    - name: {{ interface }}
    - routes:
{% for ipaddr, subdata in data.iteritems() %}
      - name: route-{{ ipaddr }}
        ipaddr: {{ ipaddr }}
{% for item, value in subdata.iteritems() %}
        {{ item }}: {{ value }}{% endfor %}{% endfor %}
    - require_in:
      - file: /etc/init/networking.override
{% endif %}
{% endfor %}

/etc/init/networking.override:
  file:
    - absent
    - require:
{%- for item, data in interfaces.iteritems() %}
      - network: network-interface-{{ item }}
{%- endfor %}

{% endmacro %}
