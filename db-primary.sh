#!/bin/bash

DB_HOST="invengo-dev-rds.cdrku6gbyima.eu-central-1.rds.amazonaws.com"
DB_PORT="5432"
DB_USER="support_services"
DB_NAME="postgres"
DB_PASSWORD="DevSup2017"
OUTPUT_FILE="tables_without_primary_keys.txt"
DB_LIST_FILE="db.txt"


# Export password to avoid prompting
export PGPASSWORD=$DB_PASSWORD

# Initialize the output file with a header
echo "Tables Without Primary Keys Report" > $OUTPUT_FILE
echo "==================================" >> $OUTPUT_FILE
echo "" >> $OUTPUT_FILE

# SQL query to find tables without primary keys
SQL_QUERY="
SELECT tab.table_catalog,
       tab.table_schema,
       tab.table_name
FROM information_schema.tables tab
LEFT JOIN information_schema.table_constraints tco 
ON tco.table_schema = tab.table_schema
   AND tco.table_name = tab.table_name
   AND tco.constraint_type = 'PRIMARY KEY'
WHERE tab.table_schema NOT IN ('pg_catalog', 'information_schema')
      AND tco.constraint_type IS NULL
      AND tab.table_type = 'BASE TABLE'
ORDER BY tab.table_schema,
         tab.table_name;
"

# Loop through each database in the db.txt file and run the query
while IFS= read -r DB_NAME; do
    echo "Processing database: $DB_NAME"
    
    echo "Database: $DB_NAME" >> $OUTPUT_FILE
    echo "----------------------------" >> $OUTPUT_FILE
    
    # Execute the query and format the results
    psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d "$DB_NAME" -c "$SQL_QUERY" -F ',' --no-align --tuples-only | while IFS=',' read -r table_catalog table_schema table_name; do
        echo "Schema: $table_schema, Table: $table_name" >> $OUTPUT_FILE
    done
    
    echo "" >> $OUTPUT_FILE
done < "$DB_LIST_FILE"

echo "Report generation complete. Check the file: $OUTPUT_FILE"
