# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
  config.vm.box = "cloud-image/ubuntu-24.04"

  # Private network subnet:
  # Reserved for future use: 192.168.56.15
  backend_ip = "192.168.56.11"
  nginx1_ip  = "192.168.56.12"
  nginx2_ip  = "192.168.56.13"

  config.vm.define "backend" do |backend|
    backend.vm.hostname = "backend"
    backend.vm.network "private_network", ip: backend_ip
    backend.vm.provider "virtualbox" do |vb|
      vb.memory = 2048
    end
  end

  config.vm.define "nginx1" do |nginx1|
    nginx1.vm.hostname = "nginx1"
    nginx1.vm.network "private_network", ip: nginx1_ip
    nginx1.vm.provider "virtualbox" do |vb|
      vb.memory = 1024
    end
  end

  config.vm.define "nginx2" do |nginx2|
    nginx2.vm.hostname = "nginx2"
    nginx2.vm.network "private_network", ip: nginx2_ip
    nginx2.vm.provider "virtualbox" do |vb|
      vb.memory = 1024
    end
  end
end
