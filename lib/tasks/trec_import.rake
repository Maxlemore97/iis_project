namespace :trec do
  desc "Import TREC .trec file (recordId + text format)"
  task import: :environment do
    file = ENV["FILE"]

    unless file && File.exist?(file)
      puts "Usage: rake trec:import FILE=path/to/file.trec"
      exit
    end

    require "nokogiri"

    puts "Importing #{file}..."

    xml = Nokogiri::XML(File.read(file))

    xml.xpath("//DOC").each do |doc|
      trec_id = doc.at_xpath("recordId")&.text&.strip
      text    = doc.at_xpath("text")&.text&.strip

      next if trec_id.nil? || text.nil?

      Document.create!(
        trec_id: trec_id,
        title:   text.lines.first.strip,   # first line becomes title
        body:    text                      # full content
      )
    end

    puts "Reindexing..."
    Document.import(force: true)

    puts "Done."
  end
end
