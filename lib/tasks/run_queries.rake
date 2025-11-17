namespace :search do
  desc "Run many queries against Elasticsearch"
  task run: :environment do
    queries = File.read("queries.txt").split("\n") # 50 lines

    queries.each_with_index do |q, i|
      puts "Running query #{i+1}: #{q}"

      result = Document.search({
                                 query: {
                                   multi_match: {
                                     query: q,
                                     fields: ["title^2", "body"]
                                   }
                                 }
                               })

      puts "Hits: #{result.results.total}"
    end
  end
end
