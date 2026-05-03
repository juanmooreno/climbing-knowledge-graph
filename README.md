# ClimbingGraph: Knowledge Graph & GNN for Route Recommendation

ClimbingGraph is a hybrid system that utilizes **Neo4j** and **Graph Neural Networks (PyTorch)** to address subjectivity in climbing grades and provide route recommendations based on physical and geographic structure.

## 🚀 Quick Start Guide

Follow these steps in order to replicate the project environment and results.

### 1. Data Acquisition
Download the original Mountain Project dataset from Kaggle:
*   **Dataset:** [Mountain Project Dataset (pdegner)](https://www.kaggle.com/datasets/pdegner/mountain-project-dataset)
*   Create a local folder named `data/` in the project root and place the downloaded file inside.

### 2. Preprocessing
Run the `notebooks/preprocess.ipynb` notebook.
*   This script cleans and filters the data for California routes.
*   Upon completion, it will generate **3 CSV files** required for the database: `routes.csv`, `locations.csv`, and `relationships.csv`.

### 3. Neo4j Configuration
1.  Create a new instance (Local DBMS) in **Neo4j Desktop**.
2.  **Important:** Install the **GDS (Graph Data Science)** library from the "Plugins" tab of your database instance.
3.  Copy the 3 generated CSV files into the `import/` folder of your Neo4j instance.
4.  Start the database.

### 4. Graph Construction
Open **Neo4j Browser** and execute the code found in `cypher/queries.cypher`. This script will:
*   Build the geographic hierarchy (`Route > Sector > Area > Region`).
*   Establish spatial `NEAR_TO` relationships for routes within 100m of each other.
*   Generate **64-dimensional FastRP Embeddings**.

### 5. Recommendation and Modeling (GNN)
Open the `notebooks/Embeddings and GNN.ipynb` notebook and follow these steps:
1.  **Connection:** Locate the `Neo4j Driver` configuration cell and update your **password** to establish a connection.
2.  **Recommendation:** Run the Cosine Similarity cells to search for similar routes by entering a route's internal ID.
3.  **GNN Evaluation:** You can train the Regression and Classification models from scratch or load the final results.
    *   *Note:* Performance is evaluated using the **Dice Score** (Macro-F1) to measure accuracy across athletic categories.

## 📂 Repository Structure

*   `notebooks/`: Contains `.ipynb` files for data processing and AI model training.
*   `cypher/`: Cypher scripts for creating and evolving the graph in Neo4j.
*   `docs/`: Technical documentation and project reports.

## 🛠️ Technology Stack
*   **Database:** Neo4j (GDS Library)
*   **Languages:** Python, Cypher
*   **ML Libraries:** PyTorch Geometric, Scikit-Learn, Pandas

---
**License:** This project is licensed under the MIT License.

Developed by Juan Moreno Segura for the Knowledge Graphs Course at TU Wien, 2026.
