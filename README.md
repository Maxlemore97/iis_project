# 📘 **IIS Project – Rails 6.1 + PostgreSQL + Vite + Bootstrap**

This project is a miniature information-retrieval system featuring:

* **Rails 6.1**
* **PostgreSQL**
* **Vite Ruby (JS bundler)**
* **Bootstrap 5**
* **Chart.js**
* Ability to:

    * **Import `.trec` files**
    * **Auto-compute style vectors (TTR, sentence length, pronoun ratio, readability)**
    * **Query documents via different scoring approaches**
    * **Visualize vectors in the browser**

---

# 🚀 **1. Requirements**

Ensure the following are installed:

* Ruby **3.3.x**
* Rails **6.1**
* PostgreSQL **13+**
* Node.js / Bun
* Yarn or npm
* Vite Ruby (installed via Gemfile)

---

# 🏗 **2. Installation**

Clone the project:

```bash
git clone https://github.com/your-org/iis_project.git
cd iis_project
```

Install Ruby dependencies:

```bash
bundle install
```

Install JavaScript dependencies (using Bun or Yarn):

```bash
bun install
# or:
yarn install
```

---

# 🛢 **3. Database Setup**

```bash
rails db:create
rails db:migrate
```

---

# 🎨 **4. Frontend Setup – Vite Ruby**

### Start the Vite dev server:

```bash
bin/vite dev
```

If needed, restart the Rails server afterward.

The frontend entrypoint is:

```
app/frontend/entrypoints/application.js
```

---

# 📥 **5. Importing a `.trec` File**

Import any TREC XML file containing:

```xml

<DOC>
  <recordId>DOC001</recordId>
  <text>Full document text…</text>
  <style_vec>1.0,4.3,0.05,60.2</style_vec> <!-- optional -->
</DOC>
```

Run:

```bash
rake trec:import FILE=path/to/file.trec
```

The task will:

1. Parse the XML
2. Compute style vectors if missing (`StyleFeatureService`)
3. Store everything in PostgreSQL
4. Reindex Document model (Searchkick-style or custom)

---

# 📊 **6. Style Vector Extraction**

Style vectors use:

1. **TTR** (type-token ratio)
2. **Avg sentence length**
3. **Pronoun ratio**
4. **Flesch readability score**

Implemented in:

```
app/services/style_feature_service.rb
```

---

# 🔎 **7. Search Modes**

### **1. Lexical Search**

```
GET /search?q=keyword
```

### **2. Style-based Similarity Search**

```
GET /search_style?q=your text
```

### **3. Hybrid Search (lexical + vector score)**

```
GET /search_hybrid?q=your text
```

---

# 🌐 **8. Application Routes**

| Path             | Purpose                 |
|------------------|-------------------------|
| `/home`          | Document list           |
| `/search`        | Lexical search          |
| `/search_style`  | Vector-based search     |
| `/search_hybrid` | Combined score          |
| `/vectors`       | Vector visualization UI |

Route definitions:

```ruby
get "home" => "documents#index", as: :documents_home
get "vectors" => "vectors#index"

get "search" => "documents#search"
get "search_style" => "documents#search_style"
get "search_hybrid" => "documents#search_hybrid"
```

---

# 📊 **9. Vector Visualization UI**

Accessible at:

```
/vectors
```

Displays:

* Document ID
* Title
* Body (optional)
* Extracted style vector
* Mini-charts using **Chart.js** inside Bootstrap Accordions

---

# ▶️ **10. Start the Application**

In one terminal:

```bash
bin/vite dev
```

In another:

```bash
rails s
```

Then visit:

```
http://localhost:3000/home
```

---

# 📚 **11. Directory Overview**

```
app/models/document.rb             # Model storing trec_id, title, body, style_vec
app/services/style_feature_service.rb
app/controllers/documents_controller.rb
app/controllers/vectors_controller.rb
lib/tasks/trec_import.rake
app/frontend/entrypoints/application.js
app/views/vectors/index.html.haml  # Visualization UI
```

---

# 🏁 **12. Summary**

This project provides:

✔ Import + processing of TREC documents
✔ Style-feature vector extraction
✔ Multiple search strategies
✔ Beautiful Vite-powered frontend
✔ Chart.js vector visualization
✔ Clean Rails 6.1 backend
