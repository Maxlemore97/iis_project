class HomeController < ApplicationController
  def index
  end

  # ---------------------------
  # DOCUMENT UPLOAD
  # ---------------------------
  def upload_trec
    unless params[:file].present?
      redirect_to root_path, alert: "Please select a .trec file."
      return
    end

    file = params[:file]

    unless file.original_filename.downcase.ends_with?(".trec")
      redirect_to root_path, alert: "Only .trec files are allowed."
      return
    end

    imported = TrecImporter.import_string(file.read)
    redirect_to root_path, notice: "Imported #{imported} documents successfully."
  rescue => e
    redirect_to root_path, alert: "Import failed: #{e.message}"
  end

  def delete_all
    Document.delete_all
    redirect_to root_path, notice: "All documents deleted."
  end

  # ---------------------------
  # QUERY UPLOAD
  # ---------------------------
  def upload_query_trec
    unless params[:query_file].present?
      redirect_to root_path, alert: "Please select a query .trec file."
      return
    end

    file = params[:query_file]

    unless file.original_filename.downcase.ends_with?(".trec")
      redirect_to root_path, alert: "Only .trec files are allowed."
      return
    end

    imported = QueryTrecImporter.import_string(file.read)
    redirect_to root_path, notice: "Imported #{imported} query documents successfully."
  rescue => e
    redirect_to root_path, alert: "Query import failed: #{e.message}"
  end

  def delete_all_queries
    QueryDocument.delete_all
    redirect_to root_path, notice: "All query documents deleted."
  end
end
