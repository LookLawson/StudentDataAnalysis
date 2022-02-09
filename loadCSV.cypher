// To delete constraints, replace CREATE with DROP, then DROP INDEX ON
CREATE CONSTRAINT ON(s:Student) ASSERT s.BANNER_ID IS UNIQUE;
CREATE CONSTRAINT ON(p:Programme) ASSERT p.PROG_CODE IS UNIQUE;
CREATE CONSTRAINT ON(c:Course) ASSERT c.COURSE_CODE IS UNIQUE;
CREATE CONSTRAINT ON(d:Degree) ASSERT d.DEG_CLASS IS UNIQUE;

// XLSX LOAD (APOC plugin and library requirements at https://neo4j.com/labs/apoc/4.1/import/xls/)
//CALL apoc.load.xls("file:///sheet.xlsx", "Sheet1")

// CSV LOAD
LOAD CSV WITH HEADERS FROM "https://raw.githubusercontent.com/LookLawson/StudentDataAnnalysis/master/output.csv" as line with line
MERGE (s:Student {BANNER_ID: line.BANNER_ID})
SET s.TITLE = line.TITLE
SET s.LAST_NAME = line.LAST_NAME
SET s.MIDDLE_NAME = line.MIDDLE_NAME
SET s.FIRST_NAME = line.FIRST_NAME
SET s.ACTIVE_STATUS = line.ACTIVE_STATUS
SET s.LEVL_CODE = line.LEVL_CODE // SHOULD LEVEL CODE BE STUDENT OR PROGRAMME? BOTH?
//  SET s.CAMP_CODE = line.CAMP_CODE
SET s.CAMP_DESC = line.CAMP_DESC
SET s.TERM_CODE = line.TERM_CODE
SET s.YOS_CODE = line.YOS_CODE
SET s.USERNAME = line.USERNAME

MERGE (p:Programme {PROG_CODE: line.PROG_CODE})
SET p.PROG_DESC = line.PROG_DESC
SET p.LEVL_CODE = line.LEVL_CODE // SHOULD LEVEL CODE BE STUDENT OR PROGRAMME? BOTH?
MERGE (s)-[:ON_PROGRAMME]->(p);

// SCHEMA
MERGE (s:Student {BANNER_ID: "H0025"})
MERGE (c:Course {COURSE_CODE: "F28PL"})
MERGE (c2:Course {COURSE_CODE: "F29FN"})
MERGE (p:Programme {PROG_CODE: "F21-COS"})
MERGE (d:Degree {DEG_CLASS: "1st Class"})
MERGE (s)-[:completed {MARK: 70}]->(c)
MERGE (s)-[:enrolled]->(c2)
MERGE (c)-[:on]->(p)
MERGE (c2)-[:on]->(p)
MERGE (d)<-[:graduated]-(s)


DROP CONSTRAINT ON(s:Student) ASSERT s.BANNER_ID IS UNIQUE;
DROP CONSTRAINT ON(p:Programme) ASSERT p.PROG_CODE IS UNIQUE;
MATCH(n) DETACH DELETE n

