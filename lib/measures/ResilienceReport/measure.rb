# insert your copyright here

# see the URL below for information on how to write OpenStudio measures
# http://nrel.github.io/OpenStudio-user-documentation/reference/measure_writing_guide/

require 'erb'
require 'json'
require 'date'
require 'time'
require 'set'
# require "#{File.dirname(__FILE__)}/resources/os_lib_reporting"
require "#{File.dirname(__FILE__)}/resources/os_lib_helper_methods"

# start the measure
class ResilienceReport < OpenStudio::Measure::ReportingMeasure
  # human readable name
  def name
    # Measure name should be the title case of the class name.
    return 'Generate Resilience Report'
  end

  # human readable description
  def description
    return 'This measure generates resilience report after the resilience simulation.'
  end

  # human readable description of modeling approach
  def modeler_description
    return 'This is a reporting measure that generates resilience report after the resilience simulation.' +
      'The measure takes the output SQL file of the model used in the workflow, calculates the resilience metrics for the specified time period of the extreme event, and ' +
      'generates a report in HTML format, including charts visualizing the time-series resilience metrics, and summarized data tables.' +
      'Another SQL file can be provided as a baseline to compare with the target model.' +
      'For example, the measure can be used to generate report to compare a normal condition and the power outage condition.'
  end

  # define the arguments that the user will input
  def arguments(model = nil)
    args = OpenStudio::Measure::OSArgumentVector.new

    outage_start_date = OpenStudio::Ruleset::OSArgument.makeStringArgument('outage_start_date', true)
    outage_start_date.setDisplayName('The start date of the extreme event for which the resilience metrics are calculated.')
    outage_start_date.setDescription('In MM-DD format')
    outage_start_date.setDefaultValue('06-15')
    args << outage_start_date

    outage_start_hour = OpenStudio::Measure::OSArgument.makeStringArgument('outage_start_hour', true)
    outage_start_hour.setDisplayName('The start time of the extreme event for which the resilience metrics are calculated.')
    outage_start_hour.setDescription('Use 24 hour format HH:MM')
    outage_start_hour.setDefaultValue('14:00')
    args << outage_start_hour

    outage_end_date = OpenStudio::Ruleset::OSArgument.makeStringArgument('outage_end_date', true)
    outage_end_date.setDisplayName('The end date of the extreme event for which the resilience metrics are calculated.')
    outage_end_date.setDescription('In MM-DD format')
    outage_end_date.setDefaultValue('06-18')
    args << outage_end_date

    outage_end_hour = OpenStudio::Measure::OSArgument.makeStringArgument('outage_end_hour', true)
    outage_end_hour.setDisplayName('The end time of the extreme event for which the resilience metrics are calculated.')
    outage_end_hour.setDescription('Use 24 hour format HH:MM')
    outage_end_hour.setDefaultValue('14:00')
    args << outage_end_hour

    plot_start_date = OpenStudio::Ruleset::OSArgument.makeStringArgument('plot_start_date', true)
    plot_start_date.setDisplayName('The beginning date for resilience reporting charts. This can be some hours or days before the start time of the extreme event to show the change.')
    plot_start_date.setDescription('In MM-DD format')
    plot_start_date.setDefaultValue('06-14')
    args << plot_start_date

    plot_start_hour = OpenStudio::Measure::OSArgument.makeStringArgument('plot_start_hour', true)
    plot_start_hour.setDisplayName('The beginning time for resilience reporting charts.')
    plot_start_hour.setDescription('Use 24 hour format HH:MM')
    plot_start_hour.setDefaultValue('14:00')
    args << plot_start_hour

    plot_end_date = OpenStudio::Ruleset::OSArgument.makeStringArgument('plot_end_date', true)
    plot_end_date.setDisplayName('The end date for resilience reporting charts. This can be some hours or days after the end time of the extreme event to show the change.')
    plot_end_date.setDescription('In MM-DD format')
    plot_end_date.setDefaultValue('06-19')
    args << plot_end_date

    plot_end_hour = OpenStudio::Measure::OSArgument.makeStringArgument('plot_end_hour', true)
    plot_end_hour.setDisplayName('The end time for resilience reporting charts.')
    plot_end_hour.setDescription('Use 24 hour format HH:MM')
    plot_end_hour.setDefaultValue('14:00')
    args << plot_end_hour


    comparison_sql_path = OpenStudio::Measure::OSArgument.makePathArgument('comparison_sql_path', true, "", false)
    comparison_sql_path.setDisplayName('Provide the SQL file path if you need a case added for comparison in the resilience report. The sql file should contain all the variables required for the resilience report as well.')
    comparison_sql_path.setDefaultValue('')
    args << comparison_sql_path

    return args
  end

  # define the outputs that the measure will create
  def outputs
    outs = OpenStudio::Measure::OSOutputVector.new

    # this measure does not produce machine readable outputs with registerValue, return an empty list

    return outs
  end

  # return a vector of IdfObject's to request EnergyPlus objects needed by the run method
  # Warning: Do not change the name of this method to be snake_case. The method must be lowerCamelCase.
  def energyPlusOutputRequests(runner, user_arguments)
    super(runner, user_arguments)  # Do **NOT** remove this line

    result = OpenStudio::IdfObjectVector.new

    # To use the built-in error checking we need the model...
    # get the last model and sql file
    model = runner.lastOpenStudioModel
    if model.empty?
      runner.registerError('Cannot find last model.')
      return false
    end
    model = model.get

    # use the built-in error checking
    # if !runner.validateUserArguments(arguments(model), user_arguments)
    #   return false
    # end

    # if runner.getBoolArgumentValue('report_drybulb_temp', user_arguments)
    #   request = OpenStudio::IdfObject.load('Output:Variable,,Site Outdoor Air Drybulb Temperature,Hourly;').get
    #   result << request
    # end
    #
    request = OpenStudio::IdfObject.load('Output:Variable,,Zone Heat Index,timestep;').get
    result << request
    request = OpenStudio::IdfObject.load('Output:Variable,,Zone Air Temperature,timestep;').get
    result << request
    request = OpenStudio::IdfObject.load('Output:Variable,,Zone Thermal Comfort Pierce Model Standard Effective Temperature,timestep;').get
    result << request
    request = OpenStudio::IdfObject.load('Output:Variable,,Site Outdoor Air Drybulb Temperature,timestep;').get
    result << request

    return result
  end

  # define what happens when the measure is run
  def run(runner, user_arguments)
    super(runner, user_arguments)

    # get the last model and sql file
    model = runner.lastOpenStudioModel
    if model.empty?
      runner.registerError('Cannot find the last OpenStudio model.')
      return false
    end
    model = model.get

    # use the built-in error checking (need model)
    if !runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end

    # assign the user inputs to variables
    args = OsLib_HelperMethods.createRunVariables(runner, model, user_arguments, arguments)
    unless args
      return false
    end
    puts args

    # load sql file
    target_sql_file = runner.lastEnergyPlusSqlFile
    if target_sql_file.empty?
      runner.registerError('Cannot find the last SQL file.')
      return false
    end
    target_sql_file = target_sql_file.get
    model.setSqlFile(target_sql_file)

    comparison_sql_file = nil
    if user_arguments['comparison_sql_path'].hasValue
      comparison_sql_path = runner.getPathArgumentValue('comparison_sql_path', user_arguments)
      unless File.exist?(comparison_sql_path.to_s)
        runner.registerError('The provided comparison (baseline) SQL file was not found.')
        return false
      end
      comparison_sql_file = OpenStudio::SqlFile.new(OpenStudio::Path.new(comparison_sql_path))
    else
      runner.registerInfo("Comparison (baseline) SQL file path is not provided. The report will not compare the baseline.")
    end

    # # put data into the local variable 'output', all local variables are available for erb to use when configuring the input html file
    # output =  'Measure Name = ' << name << '<br>'
    # output << 'Building Name = ' << model.getBuilding.name.get << '<br>'
    # output << 'Floor Area = ' << model.getBuilding.floorArea.to_s << '<br>'
    # output << 'Net Site Energy = ' << target_sql_file.netSiteEnergy.to_s << ' (GJ)<br>'

    # read in HTML template
    html_in_path = "#{File.dirname(__FILE__)}/resources/report.html.erb"
    if File.exist?(html_in_path)
      html_in_path = html_in_path
    else
      html_in_path = "#{File.dirname(__FILE__)}/report.html.erb"
    end
    html_in = ''
    File.open(html_in_path, 'r') do |file|
      html_in = file.read
    end

    # get the weather file run period (as opposed to design day run period)
    ann_env_pd = nil
    target_sql_file.availableEnvPeriods.each do |env_pd|
      # runner.registerInfo("Environment period: #{env_pd}")
      env_type = target_sql_file.environmentType(env_pd)
      if env_type.is_initialized
        if env_type.get == OpenStudio::EnvironmentType.new('WeatherRunPeriod')
          ann_env_pd = env_pd
          runner.registerInfo("Found weather file run period: #{env_pd}")
          break
        end
      end
    end

    plot_variables = ['Zone Heat Index',
                      'Zone Air Temperature',
                      'Zone Thermal Comfort Pierce Model Standard Effective Temperature']
    # Use the first report frequency ("Hourly","Zone Timestep" or "HVAC System Timestep") that applied to all outputs variables to plot
    available_report_frequencies = target_sql_file.availableReportingFrequencies(ann_env_pd)
    frequency_to_plot = nil
    available_report_frequencies.each do |frequency|
      available_variables = target_sql_file.availableVariableNames(ann_env_pd, frequency)
      puts "SQL available variables for #{frequency}: #{available_variables}"
      if (plot_variables - available_variables).empty?
        frequency_to_plot = frequency
        runner.registerInfo("Use #{frequency} frequency for resilience metrics in the report.")
        break
      end
    end
    if frequency_to_plot.nil?
      runner.registerError("Couldn't find all required variables in the output. These variables need to be output for the resilience report: #{plot_variables}")
      return false
    end

    target_zone_data = {}
    compare_zone_data = {}
    # The output key name for the plot_variables are:
    # Zone Heat Index: thermal_zone_name
    # Zone Air Temperature: thermal_zone_name
    # SET:
    #   if the People object belongs to a Space: people_name
    #   if the People object belongs to a SpaceType: space_name people_name

    # Both Space and SpaceTypes can have People objects
    set_output_key_map = {}  #{zone_name: people_object_name}
    model.getThermalZones.each do |zone|
      zone.spaces.each do |space|
        space.people.each do |space_people|
          set_output_key_map[zone.name.to_s] = space_people.name.to_s
          puts "People #{space_people.name.to_s} belongs to space #{space.name.to_s} in zone #{zone.name.to_s}."
        end
      end
    end

    # If the People object was not found for the Space, find it in the parent SpaceType object
    model.getSpaceTypes.each do |spc_type|
      spc_type.people.each do |space_type_people|
        spc_type.spaces.each do |space|
          next if space.thermalZone.empty?
          thermal_zone_name = space.thermalZone.get.name.to_s
          unless set_output_key_map.key?(thermal_zone_name)
            set_output_key_map[thermal_zone_name] = "#{space.name.to_s} #{space_type_people.name.to_s}"
          end
        end
        puts "People #{space_type_people.name.to_s} belongs to space type #{spc_type.name.to_s}."
      end
    end
    puts "SET output key for each thermal zone: #{set_output_key_map}"

    timeseries_yr = nil
    plot_start_time, plot_end_time = nil, nil
    event_start_time, event_end_time = nil, nil
    available_zone_names = set_output_key_map.keys

    # Check if baseline SQL file is provided
    comparison_file_provided = !comparison_sql_file.nil?
    plot_variables.each do |variable_name|
      target_zone_data[variable_name] = {}
      compare_zone_data[variable_name] = {}
      # available_keys = target_sql_file.availableKeyValues(ann_env_pd, frequency_to_plot, variable_name)
      set_output_key_map.each do |zone_name, set_key_name|
        # Get the variable for the zone from EnergyPlus sql output file
        # For SET, the key name is the People object name, for temperature and heat index, the key name is zone name
        if variable_name == 'Zone Thermal Comfort Pierce Model Standard Effective Temperature'
          key_name = set_key_name
        else
          key_name = zone_name
        end
        output_timeseries = target_sql_file.timeSeries(ann_env_pd, frequency_to_plot, variable_name, key_name)
        if output_timeseries.empty?
          puts "Timeseries #{variable_name} for #{zone_name} not found."
          runner.registerWarning("Timeseries #{variable_name} for #{zone_name} not found.")
          next
        end
        runner.registerInfo("Found #{variable_name} timeseries for #{zone_name}.")
        datetimes = output_timeseries.get.dateTimes
        if timeseries_yr.nil?
          # Get the actual year from the timeseries output. This only needs to be done once
          timeseries_yr = datetimes[0].date.year
          begin
            # Get the milliseconds epoch (UNIX) time from the input arguments
            # which is the required datetime format by Highcharts plot
            event_start_time = OsLib_HelperMethods.get_epoch_time_from_inputs(timeseries_yr, args['outage_start_date'], args['outage_start_hour'])
            event_end_time = OsLib_HelperMethods.get_epoch_time_from_inputs(timeseries_yr, args['outage_end_date'], args['outage_end_hour'])
            plot_start_time = OsLib_HelperMethods.get_epoch_time_from_inputs(timeseries_yr, args['plot_start_date'], args['plot_start_hour'])
            plot_end_time = OsLib_HelperMethods.get_epoch_time_from_inputs(timeseries_yr, args['plot_end_date'], args['plot_end_hour'])
            puts "plot start time: #{plot_start_time}, plot end time: #{plot_end_time}"

            # year, month, day = args['outage_end_date'].split('-').map(&:to_i)
            # hour, minute, second = args['outage_end_hour'].split(':').map(&:to_i)
            # end_time = OpenStudio::DateTime.new(
            #   OpenStudio::Date.new(OpenStudio::MonthOfYear.new(month), day, timeseries_yr),
            #   OpenStudio::Time.new(0, hour, minute, second)
          rescue ArgumentError => e
            runner.registerError("Invalid date or time format: #{e.message} - #{args['outage_start_date']}")
            return false
          end
        end
        timeseries_values = output_timeseries.get.values.map { |value| value.round(1) }
        plot_timestamp = datetimes.map{ |h| h.toEpoch()*1000 }
        formatted_data = plot_timestamp.zip(timeseries_values).select do |datetime, value|
          datetime >= plot_start_time && datetime <= plot_end_time
        end
        target_zone_data[variable_name][zone_name] = formatted_data

        # Retrieve comparison timeseries if the comparison file is provided
        if comparison_file_provided
          compare_output_timeseries = comparison_sql_file.timeSeries(ann_env_pd, frequency_to_plot, variable_name, key_name)
          if compare_output_timeseries.empty?
            runner.registerWarning("Comparison #{variable_name} timeseries for #{zone_name} not found.")
          else
            runner.registerInfo("Found comparison #{variable_name} timeseries for #{zone_name}.")
            compare_datetimes = compare_output_timeseries.get.dateTimes
            compare_plot_timestamp = compare_datetimes.map{ |h| h.toEpoch()*1000 }
            compare_timeseries_values = compare_output_timeseries.get.values.map { |value| value.round(1) }
            compare_formatted_data = compare_plot_timestamp.zip(compare_timeseries_values).select do |datetime, value|
              datetime >= plot_start_time && datetime <= plot_end_time
            end
            compare_zone_data[variable_name][zone_name] = compare_formatted_data
          end
        end
      end
    end

    outdoor_temp = target_sql_file.timeSeries(ann_env_pd, frequency_to_plot, "Site Outdoor Air Drybulb Temperature", "Environment")
    timestamps = outdoor_temp.get.dateTimes.map{ |h| h.toEpoch()*1000 }
    outdoor_temp_values = outdoor_temp.get.values.map { |value| value.round(1) }
    outdoor_temperature_data = timestamps.zip(outdoor_temp_values).select do |datetime, value|
      datetime >= plot_start_time && datetime <= plot_end_time
    end

    boxplot_data_target = OsLib_HelperMethods.compute_boxplot_data_flat_all_vars(target_zone_data)
    if comparison_file_provided
      boxplot_data_comparison = OsLib_HelperMethods.compute_boxplot_data_flat_all_vars(compare_zone_data)
    else
      boxplot_data_comparison = {}
    end
    target_site_energy = target_sql_file.totalSiteEnergy.get.round(0)
    compare_site_energy = comparison_sql_file.totalSiteEnergy.get.round(0)
    target_source_energy = target_sql_file.totalSourceEnergy.get.round(0)
    compare_source_energy = comparison_sql_file.totalSourceEnergy.get.round(0)
    energy_comparison = [
      ['Annual site energy (GJ)', target_site_energy, compare_site_energy],
      ['Annual source energy (GJ)', target_source_energy, compare_source_energy]
    ]

    output_table_summaryreports = model.getOutputTableSummaryReports
    output_table_summaryreports ||= OpenStudio::Model::OutputTableSummaryReports.new(model)
    output_table_summaryreports.addSummaryReport('ThermalResilienceSummary')

    table_names = ['Heat Index OccupiedHours', 'Heating SET Degree-Hours', 'Cooling SET Degree-Hours',
                   'Hours of Safety for Cold Events']

    eplustbl_path = "/Users/wannizhang/Documents/OpenStudioFY25/openstudio-common-measures-gem/lib/measures/ResilienceReport/tests/output/test_many_zones/reports/eplustbl.html"
    tables_html = OsLib_HelperMethods.extract_table(eplustbl_path, table_names)

    # configure template with variable values
    renderer = ERB.new(html_in)
    html_out = renderer.result(binding)

    # write html file: any file named 'report*.*' in the current working directory
    # will be copied to the ./reports/ folder as 'reports/<measure_class_name>_<filename>.html'
    html_out_path = './resilience_report.html'
    File.open(html_out_path, 'w') do |file|
      file << html_out
      # make sure data is written to the disk one way or the other
      begin
        file.fsync
      rescue StandardError
        file.flush
      end
    end

    # close the sql file
    target_sql_file.close




    return true
  end
end

# register the measure to be used by the application
ResilienceReport.new.registerWithApplication
