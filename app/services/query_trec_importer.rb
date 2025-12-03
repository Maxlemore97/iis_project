class QueryTrecImporter
  def self.import_string(xml_string)
    require "nokogiri"

    xml = Nokogiri::XML(xml_string)
    count = 0

    xml.xpath("//DOC").each do |node|
      trec_id = node.at_xpath("recordId")&.text&.strip
      text = node.at_xpath("text")&.text&.strip

      next if trec_id.blank? || text.blank?

      # ------------------------------------------------------
      # 1. Try to read <style_vec> from XML or compute it
      # ------------------------------------------------------
      vec_node = node.at_xpath("style_vec")

      style_vec =
        if vec_node
          vec_node.text.strip.split(",").map(&:to_f)
        else
          StyleFeatureService.extract(text)
        end

      # ------------------------------------------------------
      # 2. Generate style_keywords for the query document
      # ------------------------------------------------------
      words = StyleFeatureService.tokenize(text)
      sentences = text.split(/(?<=[.!?])\s+/)

      style_keywords = StyleKeywordService.generate(
        words: words,
        sentences: sentences,
        style_vec: style_vec
      )

      # ------------------------------------------------------
      # 3. Save QueryDocument
      # ------------------------------------------------------
      QueryDocument.create!(
        trec_id: trec_id,
        title: text.lines.first&.strip.to_s,
        body: text,
        style_vec: style_vec,
        style_keywords: style_keywords
      )

      count += 1
    end

    # ------------------------------------------------------
    # 4. Reindex Elasticsearch
    # ------------------------------------------------------
    QueryDocument.import(force: true)

    count
  end
end
