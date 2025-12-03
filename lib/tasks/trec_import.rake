namespace :trec do
  desc "Import TREC .trec file (recordId + text + auto style_vec)"
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
      text = doc.at_xpath("text")&.text&.strip

      next if trec_id.nil? || text.nil?

      # --- Try to find precomputed <style_vec> ---
      vec_node = doc.at_xpath("style_vec")

      style_vec = if vec_node
                    vec_node.text.strip.split(",").map(&:to_f)
                  else
                    # --- Compute dynamically using the service ---
                    StyleFeatureService.extract(text)
                  end

      words = StyleFeatureService.tokenize(text)
      sentences = text.split(/(?<=[.!?])\s+/)

      style_keywords = StyleKeywordService.generate(
        words: words,
        sentences: sentences,
        style_vec: style_vec
      )

      Document.create!(
        trec_id: trec_id,
        title: text.lines.first.strip,
        body: text,
        style_vec: style_vec,
        style_keywords: style_keywords
      )
    end

    puts "Reindexing..."

    Document.import(force: true)

    puts "Done."
  end
end
