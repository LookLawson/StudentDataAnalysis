// LOAD CSV

LOAD CSV WITH HEADERS from "output.txt" as row with row
LIMIT 1
RETURN row