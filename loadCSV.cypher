// To delete constraints, replace CREATE with DROP, then DROP INDEX ON
CREATE CONSTRAINT ON(s:Student) ASSERT s.BANNER_ID IS UNIQUE;
CREATE CONSTRAINT ON(p:Programme) ASSERT p.PROG_CODE IS UNIQUE;
CREATE CONSTRAINT ON(c:Course) ASSERT c.COURSE_CODE IS UNIQUE;
//#####################################################################
DROP CONSTRAINT ON(s:Student) ASSERT s.BANNER_ID IS UNIQUE;
DROP CONSTRAINT ON(p:Programme) ASSERT p.PROG_CODE IS UNIQUE;
DROP CONSTRAINT ON(c:Course) ASSERT c.COURSE_CODE IS UNIQUE;
MATCH(n) DETACH DELETE n
//#####################################################################

// XLSX LOAD (APOC plugin and library requirements at https://neo4j.com/labs/apoc/4.1/import/xls/)
//CALL apoc.load.xls("file:///sheet.xlsx", "Sheet1")

//#####################################################################

// CSV LOAD
LOAD CSV WITH HEADERS FROM "https://raw.githubusercontent.com/LookLawson/StudentDataAnnalysis/master/output.csv"
AS line WITH line //LIMIT 10
// Create Student node
MERGE (s:Student {BANNER_ID: line.BANNER_ID})
SET s.TITLE = line.TITLE,
	s.LAST_NAME = line.LAST_NAME,
	s.MIDDLE_NAME = line.MIDDLE_NAME,
	s.FIRST_NAME = line.FIRST_NAME,
	s.ACTIVE_STATUS = line.ACTIVE_STATUS,
	s.LEVL_CODE = line.LEVL_CODE,
	s.CAMP_DESC = line.CAMP_DESC,
	s.TERM_CODE = toInteger(line.TERM_CODE),
	s.YOS_CODE = toInteger(line.YOS_CODE),
	s.USERNAME = line.USERNAME,
	s.CAMP_CODE = line.CAMP_CODE
// Create Programme node
MERGE (p:Programme {PROG_CODE: line.PROG_CODE})
SET p.PROG_DESC = line.PROG_DESC,
	p.LEVL_CODE = line.LEVL_CODE
// Create Course node
MERGE (c:Course {COURSE_CODE: line.COURSE_CODE})
SET c.COURSE_TITLE = line.COURSE_TITLE,
	c.CREDIT_HOURS = toFloat(line.CREDIT_HOURS),
	c.PTRM = toInteger(line.PTRM)
//Create Relationships
MERGE (s)-[:ON_PROGRAMME]->(p)
MERGE (c)-[:ON]->(p)
// Relationship labels cannot be changed, so this would have to be deleted and a new one created
CREATE (s)-[r:ENROLLED]->(c)
SET r.ACTIVE = CASE line.PERC WHEN 'n/a' THEN TRUE WHEN '' THEN TRUE ELSE FALSE END;
//#####################################################################
// Once relationships have been created, load CSV again and add PERC values to INACTIVE student/course relationships
LOAD CSV WITH HEADERS FROM "https://raw.githubusercontent.com/LookLawson/StudentDataAnnalysis/master/output.csv"
AS line WITH line //LIMIT 10
MATCH (s:Student)-[r:ENROLLED]-(c:Course)
	WHERE r.ACTIVE = FALSE AND s.BANNER_ID = line.BANNER_ID AND c.COURSE_CODE = line.COURSE_CODE
SET r.PERC = toInteger(line.PERC)
//#####################################################################

// Calculate Average marks and assign expected grade for a single student
MATCH (s:Student)-[r:ENROLLED]-(c:Course) WHERE s.BANNER_ID = "H00135576" AND r.ACTIVE = FALSE
WITH SUM(toInteger(r.PERC)) / COUNT(r) as avg, s
SET s.DEG_CLASS = CASE WHEN avg>=70 THEN "First-class Honours" WHEN avg>=60 THEN "Upper Second-class Honours" WHEN avg>=50
THEN "Lower Second-class Honours" WHEN avg>=40 THEN "Third-class Honours" ELSE "Ordinary Degree" END
