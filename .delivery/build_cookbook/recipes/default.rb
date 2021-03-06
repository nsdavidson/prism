#
# Cookbook Name:: build_cookbook
# Recipe:: default
#
# Copyright (c) 2016 The Authors, All Rights Reserved.

#########################################################################
# Habitat
#########################################################################
include_recipe 'habitat-build::default'

#########################################################################
# Docker
#########################################################################
delivery_secrets = get_project_secrets

include_recipe 'chef-apt-docker::default'

package 'docker-engine'

# Ensure the `dbuild` user is part of the `docker` group so they can
# connect to the Docker daemon
execute "usermod -aG docker #{node['delivery_builder']['build_user']}"

execute 'add docker auto creds' do
  command lazy { <<-EOH
docker login -u="#{delivery_secrets['docker']['user']}" -p="#{delivery_secrets['docker']['password']}"
  EOH
}
  cwd node['delivery_builder']['repo']
  environment(
    'HOME' => node['delivery']['workspace_path']
  )
  live_stream true
end

# change permissions on the docker config file and directory so it's readable by dbuild
execute 'fix docker directory permissions' do
  command "chmod 755 #{node['delivery']['workspace_path']}/.docker"
end

execute 'fix docker config permissions' do
  command "chmod 644 #{node['delivery']['workspace_path']}/.docker/config.json"
end

#########################################################################
# Ruby
#########################################################################

ruby_install node['build_cookbook']['ruby_version']

# get to the project root and use it as a cache
# as it is persistent between build jobs
gem_cache = File.join(node['delivery']['workspace']['root'], '../../../project_gem_cache')

directory gem_cache do
  # set the owner to the dbuild so that the other recipes can write to here
  owner node['delivery_builder']['build_user']
  mode '0755'
  recursive true
  action :create
end
