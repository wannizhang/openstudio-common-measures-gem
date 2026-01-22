# insert your copyright here

require 'openstudio'
require 'openstudio/measure/ShowRunnerOutput'
require 'minitest/autorun'
require_relative '../measure.rb'
require 'fileutils'
require 'json'

class PowerOutage_Test < Minitest::Test

  def test_good_argument_values
    # create an instance of the measure
    measure = PowerOutage.new

    # create runner with empty OSW
    osw = OpenStudio::WorkflowJSON.new
    runner = OpenStudio::Measure::OSRunner.new(osw)

    # load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = "#{File.dirname(__FILE__)}/Full_Service_Restaurant_CA.osm"
    model = translator.loadModel(path)
    assert(!model.empty?)
    model = model.get

    # get arguments
    arguments = measure.arguments(model)
    argument_map = OpenStudio::Measure.convertOSArgumentVectorToMap(arguments)

    # create hash of argument values.
    # If the argument has a default that you want to use, you don't need it in the hash
    args_hash = {
      'otg_date' => 'August 15',
      'otg_hr' => 14,
      'otg_len' => 24
    }
    #args_hash['space_name'] = 'New Space'
    # using defaults values from measure.rb for other arguments

    # populate argument with specified hash value if specified
    arguments.each do |arg|
      temp_arg_var = arg.clone
      if args_hash.key?(arg.name)
        assert(temp_arg_var.setValue(args_hash[arg.name]))
      end
      argument_map[arg.name] = temp_arg_var
    end

    # run the measure
    measure.run(model, runner, argument_map)
    result = runner.result

    # show the output
    show_output(result)

    # assert that it ran correctly
    assert_equal('Success', result.value.valueName)
    #assert(result.info.size == 1)
    assert(result.warnings.empty?)

    # save the model to test output directory
    output_file_path = "#{File.dirname(__FILE__)}/output_restaurant/test_output.osm"
    model.save(output_file_path, true)

    # test run the modified model
    osw = {}
    # osw["weather_file"] = File.join(File.dirname(__FILE__ ), "CA_LOS-ANGELES-IAP_722950S_12.epw")
    osw["seed_file"] = File.expand_path("output_restaurant/test_output.osm", File.dirname(__FILE__))
    osw["weather_file"] = File.expand_path("USA_TX_Austin-Camp.Mabry.722544_TMY3.epw", File.dirname(__FILE__))
    osw_path = "#{File.dirname(__FILE__)}/output_restaurant/test_output.osw"
    File.open(osw_path, 'w') do |f|
      f << JSON.pretty_generate(osw)
    end
    cli_path = OpenStudio.getOpenStudioCLI
    cmd = "\"#{cli_path}\" run -w \"#{osw_path}\""
    puts cmd
    system(cmd)
  end
end
