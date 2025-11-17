namespace :trec do
  desc "Import TREC file"
  task import: :environment do
    file = ENV["FILE"]

    unless file && File.exist?(file)
      puts "Usage: rake trec:import FILE=path/to/file.trec"
      exit
    end

    require 'nokogiri'

    puts "Importing #{file}..."

    xml = Nokogiri::XML(File.read(file))

    xml.xpath("//DOC").each do |doc|
      trec_id = doc.xpath("DOCNO").text.strip
      title   = doc.xpath("TITLE").text.strip rescue nil
      body    = doc.xpath("TEXT").text.strip rescue nil

      Document.create!(
        trec_id: trec_id,
        title:   title,
        body:    body
      )
    end

    puts "Reindexing..."
    Document.import(force: true)

    puts "Done."
  end
end
