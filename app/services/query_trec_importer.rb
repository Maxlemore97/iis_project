class QueryTrecImporter
  def self.import_string(xml_string)
    require "nokogiri"

    xml = Nokogiri::XML(xml_string)
    count = 0

    xml.xpath("//DOC").each do |node|
      trec_id = node.at_xpath("recordId")&.text&.strip
      text    = node.at_xpath("text")&.text&.strip

      next if trec_id.blank? || text.blank?

      # Try to read precomputed <style_vec>
      vec_node = node.at_xpath("style_vec")

      style_vec =
        if vec_node
          vec_node.text.strip.split(",").map(&:to_f)
        else
          StyleFeatureService.extract(text)
        end

      QueryDocument.create!(
        trec_id: trec_id,
        title: text.lines.first&.strip.to_s,
        body: text,
        style_vec: style_vec
      )

      count += 1
    end

    QueryDocument.import(force: true)
    count
  end
end
