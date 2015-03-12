{% from "roles/imgbuilder/defaults.jinja" import settings as s with context %}
{% set base= s.image_base+ "/templates/dokku" %}


{% macro dokku(command, param1, param2=None) %}
{% set opt_para="" if param2 == None else param2 %}
"{{ command }}_{{ param1 }}_{{ opt_para }}":
  cmd.run:
    - name: dokku {{ command }} {{ param1 }} {{ opt_para }}
{% endmacro %}


{% macro dokku_pipe(pipedata, command, param1) %}
"{{ command }}_{{ param1 }}":
  module.run:
    - name: cmd.run
    - cmd: dokku {{ command }} {{ param1 }}
    - stdin: |
{{ pipedata|indent(8, True) }}
{% endmacro %}


{% macro dokku_checkout(name, data) %}
{#
source:
  url:
  rev: branchname
  submodules: true/false
#}
{{ name }}_checkout:
  git.latest:
    - name: {{ data['source']['url'] }}
    - target: {{ base }}/{{ name }}
{% if data['source']['rev'] is defined %}
    - rev: {{ data ['source']['rev'] }}
{% endif %}
{% if data['source']['submodules'] is defined %}
    - submodules: {{ data ['source']['submodules'] }}
{% endif %}
    - user: {{ s.user }} 
{% endmacro %}


{% macro dokku_hostname(name, data) %}
{% if data['hostname'] is defined %}
{#
hostname: 'host.domain.com'
#}
  {{ dokku("docker-options:add", name, "-h "+ data['hostname']) }}
{% endif %}
{% endmacro %}


{% macro dokku_docker_opts(name, data) %}
{% if data['docker-opts'] is defined %}
{#
docker-opts: '-h host.domain.com'
#}
  {{ dokku("docker-options:add", name, data['docker-opts']) }}
{% endif %}
{% endmacro %}


{% macro dokku_ssl(name, data) %}
{% if data['ssl'] is defined %}
{#
ssl:
  certificate: selfsigned
  key: none
[hostname: x.y.z]
#}
  {% if data['ssl']['certificate'] == 'selfsigned' %}
    {% if data['hostname'] is defined %}
        {% set hostname= data['hostname'] %}
    {% else %}
        {% set hostname= name+"."+ salt['cmd.run']('cat /home/dokku/VHOST') %}
    {% endif %}
{% load_yaml as cert_input %}
stdout: |
  AT
  Vienna
  Vienna
  ep3.at
  security
  {{ hostname }}
  admin@ep3.at
{% endload %}
{{ dokku_pipe(cert_input.stdout, "ssl:selfsigned", name) }}
  {% else %}
{{ dokku_pipe(data['ssl']['certificate'], "ssl:certificate", name) }}
{{ dokku_pipe(data['ssl']['key'], "ssl:key", name) }}
  {% endif %}
{% endif %}
{% endmacro %}


{% macro dokku_env(name, data) %}
{% if data['env'] is defined %}
{#
env:
  envname: setting
  DOKKU_VERBOSE_DATABASE_ENV: "true"
#}
  {% set newenv=[] %}
  {% for ename, edata in data['env'].iteritems() %}
    {% do newenv.append(ename+'='+edata) %}
  {% endfor %}
  {{ dokku("config:set", name, newenv|join(' ')) }}
{% endif %}
{% endmacro %}


{% macro dokku_volume(name, data) %}
{% if data['volume'] is defined %}
{#
volume:
  data_container_name:
    - /mount_point/1
    - /opt/mount_point/2
#}
  {% for cname, cpaths in data['volume'].iteritems() %}
{{ dokku("volume:create", cname, cpaths|join(',')) }}
{{ dokku("volume:link", name, cname) }}
  {% endfor %}
{% endif %}
{% endmacro %}


{% macro dokku_database(name, data) %}
{% if data['database'] is defined %}
{#
database:
  mariadb: databasecontainername
  [mariadb:]
    - first_database
    - second_database
  postgresql: databasecontainername
  [postgresql:]
    - first_database
    - second_database
  redis: true
#}
  {% for dbtype, dbname in data['database'].iteritems() %}
    {% if dbtype in ['postgresql', 'mariadb', 'mongodb', 'elasticsearch', 'memcached' ] %}
      {% if dbname is string %}
{{ dokku(dbtype+ ":create", dbname) }}
{{ dokku(dbtype+ ":link", name, dbname) }}
      {% else %}
        {% for singledb in dbname %}
{{ dokku(dbtype+ ":create", singledb) }}
{{ dokku(dbtype+ ":link", name, singledb) }}
        {% endfor %}
      {% endif %}
    {% endif %}
    {% if dbtype in ['redis'] %}
{{ dokku(dbtype+ ":create", name) }}
    {% endif %}
  {% endfor %}
{% endif %}
{% endmacro %}


{% macro dokku_files(name, data, files_touched) %}
{% if data['files'] is defined %}
{#
files:
  content:
    /Procfile: |
        web: RAILS_ENV=${RACK_ENV:-production} rake db:migrate && bundle exec puma -t 5:5 -p ${PORT:-8080} -e ${RAILS_ENV}
    /config/database.yml: |
        production:
          url: <%= ENV['DATABASE_URL'] %>
  append:
    /Gemfile: |
        gem "pg", group: :postgres
        gem "rails_12factor", group: :production
        gem "puma", group: :production
  comment:
    .gitignore: ^(config/site.yml)|(config/database.yml)
  templates:
    /config/site.yml: "salt://roles/imgbuilder/extra/dokku-definitions/tracks/site.yml"
#}

{% if data['files']['content'] is defined %}
  {% for fname, fcontent in data['files']['content'].iteritems() %}
  {% do files_touched.append(fname) %}
content_{{ base }}/{{ name }}/{{ fname }}:
  file.managed:
    - name: {{ base }}/{{ name }}/{{ fname }}
    - contents: |
{{ fcontent|indent(8, true) }}
    - user: {{ s.user }} 
  {% endfor %}
{% endif %}

{% if data['files']['append'] is defined %}
  {% for fname, fappend in data['files']['append'].iteritems() %}
  {% do files_touched.append(fname) %}
append_{{ base }}/{{ name }}/{{ fname }}:
  file.append:
    - name: {{ base }}/{{ name }}/{{ fname }}
    - text: |
{{ fappend|indent(8, true) }}
    - user: {{ s.user }} 
  {% endfor %}
{% endif %}

{% if data['files']['comment'] is defined %}
  {% for fname, fregex in data['files']['comment'].iteritems() %}
  {% do files_touched.append(fname) %}
comment_{{ base }}/{{ name }}/{{ fname }}:
  file.comment:
    - name: {{ base }}/{{ name }}/{{ fname }}
    - regex: {{ fregex }}
    - user: {{ s.user }} 
  {% endfor %}
{% endif %}

{% if data['files']['templates'] is defined %}
  {% for fname, fsource in data['files']['templates'].iteritems() %}
  {% do files_touched.append(fname) %}
managed_{{ base }}/{{ name }}/{{ fname }}:
  file.managed:
    - name: {{ base }}/{{ name }}/{{ fname }}
    - source: {{ fsource }}
    - user: {{ s.user }} 
  {% endfor %}
{% endif %}

{% endif %}
{% endmacro %}



{% macro dokku_pre_commit(name, data) %}
{% if data['pre_commit'] is defined %}
  {% for fname in data['pre_commit'] %}
pre_commit_{{ fname }}:
  cmd.run:
    - cwd: {{ base }}/{{ name }}
    - name: {{ fname }}
    - user: {{ s.user }}
  {% endfor %}
{% endif %}
{% endmacro %}


{% macro dokku_git_commit(name, data, files_touched) %}
{% set commitlog=data['commit_log']|d('modified by salt') %}

git_add_user_{{ name }}:
  cmd.run:
    - cwd: {{ base }}/{{ name }}
    - name: git config user.email "saltmaster@localhost" && git config user.name "Salt Master"
    - user: {{ s.user }} 

{% if files_touched != [] %}
git_add_and_commit_{{ name }}:
  cmd.run:
    - cwd: {{ base }}/{{ name }}
    - name: git add {{ files_touched|join(' ') }} && git commit -a -m "{{ commitlog }}"
    - user: {{ s.user }} 
{% endif %}

{% endmacro %}


{% macro dokku_git_push(name, data) %}
{% set ourbranch=data['branch']|d('master') %}

git_add_remote_{{ name }}_{{ ourbranch }}:
  cmd.run:
    - cwd: {{ base }}/{{ name }}
    - name: git remote add dokku dokku@omoikane.ep3.at:{{ name }}
    - user: {{ s.user }} 

push_{{ name }}_{{ ourbranch }}:
  cmd.run:
    - cwd: {{ base }}/{{ name }}
    - name: git push dokku {{ ourbranch }}:master

{% endmacro %}


{% macro dokku_post_commit(name, data) %}
{% if data['post_commit'] is defined %}
  {% for fname in data['post_commit'] %}
{{ dokku("run", name, fname) }}
  {% endfor %}
{% endif %}
{% endmacro %}


{% macro create_container(name, orgdata) %}
{#
name: name of container
orgdata: loaded yml dict or filenamestring to import_yaml 
#}

{% if orgdata is string %}
{% import_yaml orgdata as data with context %}
{% else %}
{% set data=orgdata %}
{% endif %}

{% set files_touched=[] %}

{{ dokku_checkout(name, data) }}
{{ dokku("create", name) }}
{{ dokku_hostname(name, data) }}
{{ dokku_docker_opts(name, data) }}
{{ dokku_volume(name, data) }}
{{ dokku_database(name, data) }}
{{ dokku_env(name, data) }}
{{ dokku_ssl(name, data) }}
{{ dokku_files(name, data, files_touched) }}
{{ dokku_pre_commit(name, data) }}
{{ dokku_git_commit(name, data, files_touched) }}
{{ dokku_git_push(name, data) }}
{{ dokku_post_commit(name, data) }}

{% endmacro %}


{% macro destroy_container(name) %}

{% endmacro %}

