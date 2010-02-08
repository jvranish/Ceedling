require 'constants' # for Verbosity enumeration


TOOL_EXECUTOR_ARGUMENT_REPLACEMENT_PATTERN = /(\$\{(\d+)\})/

class ToolExecutor

  constructor :tool_executor_helper, :streaminator, :system_wrapper

  def setup
    @tool_name  = ''
    @executable = ''
  end

  # build up a command line from yaml provided config
  def build_command_line(tool_config, *args)
    @tool_name  = tool_config[:name]
    @executable = tool_config[:executable]

    # basic premise is to iterate top to bottom through arguments using '$' as 
    #  a string replacement indicator to expand globals or inline yaml arrays
    #  into command line arguments via format strings
    return "#{expandify_element(@executable, *args)} #{build_arguments(tool_config[:arguments], *args)}".strip
  end


  # shell out, execute command, and return response
  def exec(command, args=[])
    command_str = "#{command} #{args.join(' ')}".strip
    
    shell_result = @system_wrapper.shell_execute(command_str)

    @tool_executor_helper.print_happy_results(command_str, shell_result)
    @tool_executor_helper.print_error_results(command_str, shell_result)

    raise if (shell_result[:exit_code] != 0)

    return shell_result[:output]
  end

  
  private #############################

  
  def build_arguments(config, *args)
    build_string = ''
    
    return '' if (config.nil?)
    
    # iterate through each argument
    config.each do |element|
      
      case(element)
        # if we find a simple string then look for string replacement operators
        #  and expand with the parameters in this method's argument list
        when String then build_string.concat( expandify_element(element, *args) )
        # if we find a hash, then we grab the key as a format string and expand the
        #  hash's value(s) within that format string
        when Hash   then build_string.concat( dehashify_argument_elements(element) )
      end

      build_string.concat(' ')
    end
    
    return build_string.strip
  end


  # handle simple text string argument & argument array string replacement operators
  def expandify_element(element, *args)
    match = //
    to_process = nil
    args_index = 0
    
    # handle ${#} input replacement
    if (element =~ TOOL_EXECUTOR_ARGUMENT_REPLACEMENT_PATTERN)
      args_index = ($2.to_i - 1)

      if (args.nil? or args[args_index].nil?)
        @streaminator.stderr_puts("ERROR: Tool '#{@tool_name}' expected valid argument data to accompany replacement operator #{$1}.", Verbosity::ERRORS)
        raise
      end

      match = /#{Regexp.escape($1)}/
      to_process = args[args_index]
    # simple string argument: replace escaped '\$' and strip
    else
      return element.sub(/\\\$/, '$').strip
    end

    build_string = ''
    # handle escaped $
    scrubbed_element = element.sub(/\\\$/, '$')

    # handle array or anything else passed into method to be expanded in place of replacement operators
    case (to_process)
      when Array then to_process.each {|value| build_string.concat( "#{scrubbed_element.sub(match, value.to_s)} " ) }
      else build_string.concat( scrubbed_element.sub(match, to_process.to_s) )
    end
        
    return build_string.strip
  end

  
  # handle argument hash: keys are format strings, values are data to be expanded within format strings
  def dehashify_argument_elements(hash)
    build_string = ''
    elements = []

    # grab the format string (hash key)
    format = hash.keys[0].to_s
    # grab the string(s) to squirt into the format string (hash value)
    expand = hash[hash.keys[0]]
    
    case(expand)
      # if String then assume we're looking up global constant
      when String
        if (not Object.constants.include?(expand))
          @streaminator.stderr_puts("ERROR: Tool '#{@tool_name}' found constant '#{expand}' undefined.", Verbosity::ERRORS)
          raise          
        end
        elements = Object.const_get(expand)
      # if array, then it's inline array provided in yaml
      when Array then elements = expand
    end
    
    if (elements.nil?)
      @streaminator.stderr_puts("ERROR: Tool '#{@tool_name}' could not expand nil elements for format string '#{format}'.", Verbosity::ERRORS)
      raise      
    end
    
    # expand elements (whether string or array) into format string & replace escaped '\$'
    elements.each do |element|
      build_string.concat( format.sub(/([^\\])\$/, "\\1#{element}") )
      build_string.gsub!(/\\\$/, '$')
      build_string.concat(' ')
    end
    
    return build_string.strip
  end

end