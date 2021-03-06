include:
  - .init

{% if pillar.windows_select|d(false) %}

  {% if pillar.windows_excludes|d(false) %}
    {% set windows_excludes = pillar.windows_excludes %}
  {% else %}
    {% set windows_excludes = [] %}
  {% endif %}

  {% for a in pillar.windows_select %}
    {% for p in pillar['windows_packages'][a] %}
      {% if p not in windows_excludes %}

win_update_{{ p }}:
  cmd.run:
    - shell: cmd
    - cwd: c:\Chocolatey\bin
    - name: c:\Chocolatey\chocolateyinstall\chocolatey.cmd update {{ p }}
    - require:
      - cmd: chocolatey_install

      {% endif %}
    {% endfor %}
  {% endfor %}
{% endif %}
