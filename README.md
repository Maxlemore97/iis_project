# 📘 **SearchApp – Rails 7 + PostgreSQL + Elasticsearch**

This project is a minimal search engine built with:

* **Rails 7**
* **PostgreSQL**
* **Elasticsearch 8.x**
* **elasticsearch-model / elasticsearch-rails**
* Ability to **import .trec files** and **run multiple search queries for evaluation**

---

# 🚀 **1. Requirements**

* Ruby 3.x
* Rails 7.x
* PostgreSQL 13+
* Elasticsearch 8.x (via Docker or tar.gz — *Homebrew not recommended*)
* Docker (optional but recommended)

---

# 🏗 **2. Installation**

Clone the repo:

```bash
git clone https://github.com/your-org/search_app.git
cd search_app
```

Install dependencies:

```bash
bundle install
yarn install --check-files
```

---

# 🛢 **3. Database Setup**

Ensure PostgreSQL is running, then:

```bash
rails db:create
rails db:migrate
```

---

# 🔍 **4. Start Elasticsearch (Docker recommended)**

`docker-compose.yml`:

```yaml
version: '3.7'

services:
  elasticsearch:
    image: docker.elastic.co/elasticsearch/elasticsearch:8.15.0
    environment:
      - discovery.type=single-node
      - xpack.security.enabled=false
    ports:
      - "9200:9200"
    mem_limit: 1g
```

Start it:

```bash
docker compose up -d
```

Verify:

```bash
curl http://localhost:9200
```

---

# 🔧 **5. Initialize Elasticsearch Index**

Run:

```bash
rails runner "Document.__elasticsearch__.create_index!"
rails runner "Document.import(force: true)"
```

This creates the index and imports existing DB records if present.

---

# 📥 **6. Import a `.trec` File**

Place your file anywhere, then run:

```bash
rake trec:import FILE=path/to/data.trec
```

This will:

1. Parse the `.trec` XML
2. Insert records into PostgreSQL
3. Reindex them into Elasticsearch

Example TREC structure supported:

```xml
<DOC>
  <DOCNO>DOC001</DOCNO>
  <TITLE>Sample title</TITLE>
  <TEXT>This is the full document text.</TEXT>
</DOC>
```

---

# 🔎 **7. Running Bulk Queries (50+ queries)**

Create a text file containing one query per line:

```
pirate king
ruby on rails tutorial
weather forecast
...
```

Run:

```bash
rake search:run
```

This executes every query sequentially and prints hit counts.

---

# 🌐 **8. API Endpoints**

Below are all public endpoints exposed by the application.

---

## **GET /search**

### **Search for documents**

**Query parameters:**

| Param | Required | Description             |
| ----- | -------- | ----------------------- |
| `q`   | Yes      | The search query string |

**Example:**

```
GET /search?q=pirate+king
```

**Response:**

```json
[
  {
    "id": 42,
    "trec_id": "DOC123",
    "title": "Pirate King Adventure",
    "body": "A long time ago..."
  }
]
```

---

## **GET /documents/:id**

### **Fetch a single document**

```
GET /documents/42
```

Returns the document stored in PostgreSQL.

---

## **POST /documents**

### **Create a document manually**

**Request body (JSON):**

```json
{
  "document": {
    "trec_id": "DOC900",
    "title": "New Title",
    "body": "Document text here."
  }
}
```

**Response:**

```json
{
  "status": "created",
  "id": 900
}
```

---

## **POST /reindex**

### **Force reindex all documents into Elasticsearch**

Call:

```
POST /reindex
```

This is useful after imports or schema changes.

---

# ▶️ **9. Start the Application**

```bash
rails s
```

Project will run at:

```
http://localhost:3000
```

---

# 🧪 **10. Running Tests (optional)**

```bash
bundle exec rspec
```

---

# 📚 **11. Directory Overview**

```
app/models/document.rb       # TREC-backed searchable model
lib/tasks/trec_import.rake   # TREC importer task
lib/tasks/run_queries.rake   # bulk 50-query test
app/controllers/documents    # REST endpoints
app/controllers/search       # search endpoint
```

---

# 🏁 **12. Summary**

This project gives you:

✔ Rails 7 API
✔ PostgreSQL persistence
✔ Elasticsearch 8.x for full-text search
✔ TREC document importer
✔ Bulk query evaluator
✔ Clean search endpoint and REST API
