require 'puppet/util/execution'

Puppet::Type.type(:pip).provide :default do
  desc 'Maintains programs inside an Pyenv setup'

  commands :su => 'su'

  def install
    command = ['install']

    if @resource[:package].kind_of?(Array)
      if @resource[:package_version] && @resource[:package_version].kind_of?(Array)
        @resource[:package].zip(@resource[:package_version]) { |p, v| command << p.to_s + v.to_s }
      else
        command << @resource[:package]
      end
    else
      command << @resource[:package] + @resource[:package_version].to_s
    end

    execute(command)
  end

  def uninstall
    command = ['uninstall', '-y', @resource[:package]]
    execute(command)
  end

  def update
    command = ['install', '--upgrade']
    command << @resource[:package]

    execute(command)
  end

  def pip
    if @resource[:pyenv_root].is_a? NilClass
      'pip'
    else
      "#{@resource[:pyenv_root]}/shims/pip"
    end
  end

  def query
    list().detect { |r|
      r[:package] == @resource[:package]
    } || { :ensure => :absent }
  end

  private

  def execute(command)
    command.unshift(pip)

    unless @resource[:python_version].is_a? NilClass
      command.unshift("PYENV_VERSION=#{resource[:python_version]}")
    end

    cmd = command.join(' ')

    begin
      su('-', @resource[:user], '-c', cmd)
    rescue Puppet::ExecutionFailure => e
      return if e.message =~ 'Requirement already satisfied'
    else
      raise e
    end
  end

  def list(options = {})
    command = ['list']
    packages = execute(command)
    [].new.tap do |item|
      packages.split("\n").each do |package|
        match = /^(.*) \((.*)\)$/.match(package)
        item << {
          :package => match[1],
          :ensure  => match[2]
        } if match
      end
    end.compact
  end
end
