#
# Cookbook Name:: mysite
# Recipe:: default
#
# Copyright 2013, YOUR_COMPANY_NAME
#
# All rights reserved - Do Not Redistribute
#

mysite_user = "mysite"
mysite_group = "mysite"
mysite_root = "/home/#{mysite_user}"
mysite_source = "/var/www/parnurzeal.com/public_html"

# create mysite group
group mysite_group do
  action :create
end

# create mysite user
user mysite_user do
  group mysite_group
  home mysite_root
  shell "/bin/bash"
  supports :manage_home => true
  comment "mysite user"
  action :create
end

# create folder for source
directory mysite_source do
  owner mysite_user
  group mysite_group
  recursive true
  mode "755"
  action :create
end

# create symbolic link to source from user home
link "#{mysite_root}/web_src" do
  to mysite_source
end

# set virtual hosts in apache
# to understand url and source
web_app "mysite_vhost" do
  server_name "parnurzeal.com"
  server_aliases ["www.parnurzeal.com"]
  docroot mysite_source
end

# dealing with ssh private/public key for accessing git
# create directory .ssh
directory "#{mysite_root}/.ssh" do
  owner mysite_user
  group mysite_group
  mode "0700"
end

# add id_rsa.pub & id_rsa to .ssh to access git freely
sshkey = Chef::EncryptedDataBagItem.load("secrets", "sshkey")
puts "#{sshkey['id_rsa.pub']}"
template "#{mysite_root}/.ssh/authorized_keys" do
  source "id_rsa.pub.erb"
  owner mysite_user
  group mysite_group
  mode "0600"
  variables :public_key => sshkey['id_rsa.pub']
end

template "#{mysite_root}/.ssh/id_rsa" do
  source "id_rsa.erb"
  owner mysite_user
  group mysite_group
  mode "0600"
  variables :private_key => sshkey['id_rsa']
end


# add bitbucket host to ssh known_hosts file
bitbucket_host = "bitbucket.org"
bitbucket_key = `ssh-keyscan #{bitbucket_host} 2>&1`
ssh_known_hosts_file = "#{mysite_root}/.ssh/known_hosts"
bitbucket_only_key = bitbucket_key.split("\n")[1] || ''

bash "insert_known_host" do
  user mysite_user
  code <<-EOS
          echo "#{bitbucket_only_key}" >> "#{ssh_known_hosts_file}"
  EOS
  not_if "grep -q '#{bitbucket_only_key}' '#{ssh_known_hosts_file}'"
end

# add git package to node
package "git"
git_repo = "git@bitbucket.org:parnurzeal/mysite.git"
git "#{mysite_root}/web_src" do
  repository git_repo
  reference "master"
  user mysite_user
  group mysite_group
  action :sync
end

