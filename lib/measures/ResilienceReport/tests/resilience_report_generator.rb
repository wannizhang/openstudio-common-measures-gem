  require 'erb'
  require 'json'
  require 'time'

  # Mock hourly timestamps for a 3-day period (in milliseconds for Highcharts)
  start_time = Time.parse("2018-06-14 14:00 UTC")

  hours = 72
  interval = 3600

  timestamps = Array.new(hours) do |i|
    (start_time + i * interval).to_i * 1000
  end

  event_start_time = timestamps[23]
  event_end_time = timestamps[-23]

  # Mock zones
  available_zone_names = ['Zone 1', 'Zone 2', 'Zone 3']

  comparison_file_provided = true
  # Mock baseline and measure data for all variables
  compare_zone_data = {
    'Zone Air Temperature' => {
      'Zone 1' => timestamps.map { |t| [t, rand(30..32)] },
      'Zone 2' => timestamps.map { |t| [t, rand(30..35)] },
      'Zone 3' => timestamps.map { |t| [t, rand(38..40)] }
    },
    'Zone Heat Index' => {
      'Zone 1' => timestamps.map { |t| [t, rand(30..32)] },
      'Zone 2' => timestamps.map { |t| [t, rand(30..35)] },
      'Zone 3' => timestamps.map { |t| [t, rand(35..40)] }
    },
    'Zone Thermal Comfort Pierce Model Standard Effective Temperature' => {
      'Zone 1' => timestamps.map { |t| [t, rand(30..32)] },
      'Zone 2' => timestamps.map { |t| [t, rand(30..35)] },
      'Zone 3' => timestamps.map { |t| [t, rand(35..40)] }
    }
  }

  target_zone_data = {
    'Zone Air Temperature' => {
      'Zone 1' => timestamps.map { |t| [t, rand(28..32)] },
      'Zone 2' => timestamps.map { |t| [t, rand(30..35)] },
      'Zone 3' => timestamps.map { |t| [t, rand(35..40)] }
    },
    'Zone Heat Index' => {
      'Zone 1' => timestamps.map { |t| [t, rand(28..32)] },
      'Zone 2' => timestamps.map { |t| [t, rand(30..35)] },
      'Zone 3' => timestamps.map { |t| [t, rand(35..40)] }
    },
    'Zone Thermal Comfort Pierce Model Standard Effective Temperature' => {
      'Zone 1' => timestamps.map { |t| [t, rand(28..32)] },
      'Zone 2' => timestamps.map { |t| [t, rand(30..35)] },
      'Zone 3' => timestamps.map { |t| [t, rand(35..40)] }
    }
  }


  def generate_mock_boxplot_data_with_datetime(start_time, hour_count)
    data = []
    hour_count.times do |i|
      # Start time incremented by i hours
      datetime = (start_time + i * 3600).to_i * 1000
      # Generate five values for each box：[min, Q1, median, Q3, max]
      min = rand(10..20)
      q1 = rand(21..30)
      median = rand(31..40)
      q3 = rand(41..50)
      max = rand(51..60)

      # Add datetime and boxplot data into the array
      data << { datetime: datetime, data: [min, q1, median, q3, max] }
    end
    data
  end

  # Define the start time for the data (you can use Time.now or a fixed value)

  boxplot_data_target = {
    'Zone Air Temperature' => generate_mock_boxplot_data_with_datetime(start_time, hours),
    'heatIndex' => generate_mock_boxplot_data_with_datetime(start_time, hours),
    'Zone Thermal Comfort Pierce Model Standard Effective Temperature' => generate_mock_boxplot_data_with_datetime(start_time, hours)
  }

  boxplot_data_comparison = {
    'Zone Air Temperature' => generate_mock_boxplot_data_with_datetime(start_time, hours),
    'Zone Heat Index' => generate_mock_boxplot_data_with_datetime(start_time, hours),
    'Zone Thermal Comfort Pierce Model Standard Effective Temperature' => generate_mock_boxplot_data_with_datetime(start_time, hours)
  }

  tables_html = []

  # Energy comparison data
  energy_comparison = [
    ['Annual Site Energy (kWh)', 500, 400],
    ['Heating (kWh)', 120, 100],
    ['Cooling (kWh)', 80, 60]
  ]

  # Read and render ERB template
  template = File.read('/Users/wannizhang/Documents/OpenStudioFY25/openstudio-common-measures-gem/lib/measures/ResilienceReport/resources/report.html.erb')
  result = ERB.new(template).result(binding)

  # Write to an HTML file
  File.write(File.join(__dir__, 'output.html'), result)