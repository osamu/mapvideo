require 'nokogiri'
require 'time'
require 'net/http'

class EventTimeline
  Event = Struct.new(:offset, :event)

  def initialize(framerate, duration)
    @framerate = framerate # in seconds
    @duration = duration   # in seconds
    @events = []
  end

  def import(events)
    @events = events
  end

  def play
    event = @events.shift
    updated = true
    0.step(@duration, @framerate) do |i|
      if i > @events.first.offset
        event = @events.shift  
        updated = true
      end
      yield event, updated
      updated = false
    end
  end
end

class Route
  Place = Struct.new(:timestamp, :style_url, :lat, :lot)
  IconStyle = Struct.new(:id, :icon_url)


  def initialize(places)
    @places = places.sort {|a,b| a.timestamp <=> b.timestamp }
    @start_timestamp = @places.first.timestamp
    @stop_timestamp = @places.last.timestamp
    @duration = @stop_timestamp - @start_timestamp
  end

  def play(framerate)
    timeline = EventTimeline.new(framerate, @duration)
    events = @places.map do |p|
      EventTimeline::Event.new( p.timestamp - @start_timestamp, p)
    end
    timeline.import(events)
    timeline.play do |event, updated|
      yield event, updated
    end
  end

  def self.from_kml(file)
    doc = Nokogiri::XML(File.read(file))
    style_urls = {}
    doc.search("Style").map do |style|
      id = style.attribute("id").value
      url = style.search("href").text
      style_urls[id] = url
    end
    places = doc.xpath('//xmlns:Placemark').map do |place|
      timestamp = Time.parse(place.search('when').text)
      style_url = place.search("styleUrl").text
      if style_url =~ /^#(.+)/
        style_url = style_urls[$1]
      end
      lat, lot = place.search('coordinates').text.split(",")
      Place.new(timestamp, style_url, lat, lot)
    end
    return  self.new(places)
  end
end

class StaticMapRenderer

  def self.staticmap(lat, lot, icon_url)
    uri = URI("https://maps.googleapis.com/maps/api/staticmap")
    params = { 
               center: "#{lat},#{lot}",
                 zoom:17,
                 size: '400x400',
                 key: ENV["API_KEY"],
                 markers: "icon:#{icon_url}|#{lat},#{lot}"
    }
    uri.query = URI.encode_www_form(params)
    res = Net::HTTP.get_response(uri)
    res.body
  end

  def self.render(route)
    count = 0
    map_image = nil
    route.play(1) do |event, updated|
      if updated
        map_image = staticmap(event.event.lot, event.event.lat, event.event.style_url)
      end
      output_dir = 'output'
      if map_image
        Dir.mkdir(output_dir) unless Dir.exists?(output_dir)
        filename = File.join(output_dir,"%04d"% count + ".png" )
        File.write(filename, map_image)
      end
      count += 1
    end
  end

end

if ARGV[0]
  kml_filename = ARGV[0]
  route = Route.from_kml(kml_filename)
  StaticMapRenderer.render(route)
end
