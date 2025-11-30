namespace :search do
  desc "Run many queries from a .trec file against Elasticsearch"
  task run: :environment do
    file = ENV["FILE"]

    unless file && File.exist?(file)
      puts "Usage: rake search:run FILE=iis1_queries.trec"
      exit
    end

    require "nokogiri"

    puts "Loading queries from #{file}..."

    xml = Nokogiri::XML(File.read(file))

    # Extract queries from TREC <TOP> blocks
    topics = xml.xpath("//TOP")

    topics.each_with_index do |topic, i|
      # Use <TITLE> text as query (standard TREC field)
      q = topic.at_xpath("TITLE")&.text&.strip

      # fallback to <DESC> if no title found
      q = topic.at_xpath("DESC")&.text&.strip if q.nil? || q.empty?

      next unless q

      puts "Running query #{i + 1}: #{q}"

      result = Document.search(
        query: {
          multi_match: {
            query: q,
            fields: ["title^2", "body"]
          }
        }
      )

      puts "Hits: #{result.results.total}"
    end
  end
end
