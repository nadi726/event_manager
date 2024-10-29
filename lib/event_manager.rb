require 'csv'
require 'erb'
require 'time'
require 'google/apis/civicinfo_v2'


def clean_phone_number(num)
  if num.nil?
    return
  end
  # not mentioned by the requirements, but we get wat more numbers this way
  num = num.gsub(/\D/, '')  # Remove all non-digit characters
  
  if num.length == 11 && num[0] == "1"
    num = num[1..-1]
  end

  if num.length != 10
      num = nil
  end
  num
end

def get_registration_hour(time_str)
  return if time_str.nil?
  begin
    time_object = Time.strptime(time_str, "%m/%d/%y %H:%M")
  rescue
    return
  end
  # round to nearest hour
  time_object += 30 * 60 + 30
  time_object.hour
end

def clean_zipcode(zipcode)
  zipcode.to_s.rjust(5,"0")[0..4]
end

def legislators_by_zipcode(zip)
  civic_info = Google::Apis::CivicinfoV2::CivicInfoService.new
  civic_info.key = 'AIzaSyClRzDqDh5MsXwnCWi0kOiiBivP6JsSyBw'

  begin
    civic_info.representative_info_by_address(
      address: zip,
      levels: 'country',
      roles: ['legislatorUpperBody', 'legislatorLowerBody']
    ).officials
  rescue
    'You can find your representatives by visiting www.commoncause.org/take-action/find-elected-officials'
  end
end

def save_thank_you_letter(id,form_letter)
  Dir.mkdir('output') unless Dir.exist?('output')

  filename = "output/thanks_#{id}.html"

  File.open(filename, 'w') do |file|
    file.puts form_letter
  end
end

def get_top_hours(hours, top=5)
  hours.sort_by {|k, v| -v}.take top
end

puts 'EventManager initialized.'

contents = CSV.open(
  'event_attendees.csv',
  headers: true,
  header_converters: :symbol
)

template_letter = File.read('form_letter.erb')
erb_template = ERB.new template_letter
registration_hours = Hash.new(0)

contents.each do |row|
  id = row[0]
  name = row[:first_name]
  zipcode = clean_zipcode(row[:zipcode])
  legislators = legislators_by_zipcode(zipcode)
  phone = clean_phone_number(row[:homephone])
  registration_hour = get_registration_hour(row[:regdate])
  registration_hours[registration_hour] += 1

  form_letter = erb_template.result(binding)

  save_thank_you_letter(id,form_letter)
end

puts "\nDone."
puts "Top registration hours:"
get_top_hours(registration_hours).each do |k, v|
  puts "At #{k}, #{v} people registered"
end