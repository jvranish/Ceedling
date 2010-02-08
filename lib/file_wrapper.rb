require 'rubygems'
require 'rake' # for FileList
require 'fileutils'


class FileWrapper

  def get_expanded_path(path)
    return File.expand_path(path)
  end

  def exist?(filepath)
    return File.exist?(filepath)
  end

  def directory?(path)
    return File.directory?(path)
  end

  def dirname(path)
    return File.dirname(path)
  end

  def directory_listing(path)
    return Dir.entries(path)
  end

  def rm_f(filepath)
    FileUtils.rm_f(filepath)
  end

  def cp(source, destination, options={})
    FileUtils.cp(source, destination, options)
  end

  def open(filepath, flags)
    File.open(filepath, flags) do |file|
      yield(file)
    end
  end

  def read(filepath)
    return File.read(filepath)
  end

  def write(filepath, contents, flags='w')
    File.open(filepath, flags) do |file|
      file.write(contents)
    end    
  end

  def readlines(filepath)
    return File.readlines(filepath)
  end

  def instantiate_file_list(files=[])
    return FileList.new(files)
  end

end