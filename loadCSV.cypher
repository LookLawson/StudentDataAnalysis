//#####################################################################
DROP CONSTRAINT ON(s:Student) ASSERT s.BANNER_ID IS UNIQUE;
DROP CONSTRAINT ON(p:Programme) ASSERT p.PROG_CODE IS UNIQUE;
DROP CONSTRAINT ON(c:Course) ASSERT c.COURSE_CODE IS UNIQUE;
DROP CONSTRAINT ON(s:School) ASSERT s.NAME IS UNIQUE;
MATCH(n) DETACH DELETE n;
// To delete constraints, replace CREATE with DROP, then DROP INDEX ON
CREATE CONSTRAINT ON(s:Student) ASSERT s.BANNER_ID IS UNIQUE;
CREATE CONSTRAINT ON(p:Programme) ASSERT p.PROG_CODE IS UNIQUE;
CREATE CONSTRAINT ON(c:Course) ASSERT c.COURSE_CODE IS UNIQUE;
CREATE CONSTRAINT ON(s:School) ASSERT s.NAME IS UNIQUE;
//#####################################################################

// CSV LOAD
LOAD CSV WITH HEADERS FROM "https://raw.githubusercontent.com/LookLawson/StudentDataAnnalysis/master/output.csv"
AS line WITH line
// Create Student node
MERGE (s:Student {BANNER_ID: line.BANNER_ID})
SET s.TITLE = line.TITLE,
	s.LAST_NAME = line.LAST_NAME,
	s.MIDDLE_NAME = line.MIDDLE_NAME,
	s.FIRST_NAME = line.FIRST_NAME,
	s.ACTIVE_STATUS = CASE WHEN line.ACTIVE_STATUS = "AS" THEN TRUE ELSE FALSE END,
	s.LEVL_CODE = line.LEVL_CODE,
	s.CAMP_DESC = line.CAMP_DESC,
	// s.TERM_CODE = TOINTEGER(line.TERM_CODE), // Defunct, properties assigned to [ENROLLED] relationship
	// s.YOS_CODE = TOINTEGER(line.YOS_CODE),
	s.USERNAME = line.USERNAME,
	s.CAMP_CODE = line.CAMP_CODE
// Create Programme node
MERGE (p:Programme {PROG_CODE: line.PROG_CODE})
SET p.PROG_DESC = line.PROG_DESC,
	p.LEVL_CODE = line.LEVL_CODE
// Create Course node
MERGE (c:Course {COURSE_CODE: line.COURSE_CODE})
SET c.COURSE_TITLE = line.COURSE_TITLE,
	c.CREDIT_HOURS = TOFLOAT(line.CREDIT_HOURS),
	c.PTRM = TOINTEGER(RIGHT(line.PTRM,1)) // Take rightmost character so it works for "2" and "S2"
//Create Student--Programme Relationships
MERGE (s)-[:ON_PROGRAMME]->(p)
// Create Course--Programme Relationships
MERGE (c)-[:ON_PROGRAMME {YOS_CODE: TOINTEGER(line.YOS_CODE)}]->(p)
// Create Student--Course relationship
CREATE (s)-[r:ENROLLED {TERM_CODE: TOINTEGER(line.TERM_CODE)}]->(c)
SET r.YOS_CODE = TOINTEGER(line.YOS_CODE),
	r.OPPORTUNITY = TOINTEGER(line.OPPORTUNITY),
	r.RESIT_FLAG = line.RESIT_FLAG,
	r.ACTIVE = CASE WHEN NOT line.PERC IS NULL THEN FALSE ELSE TRUE END;

//#####################################################################

// Once rels have been created, load CSV again and add PERC values to INACTIVE student/course rels
LOAD CSV WITH HEADERS FROM "https://raw.githubusercontent.com/LookLawson/StudentDataAnnalysis/master/output.csv"
AS line WITH line
MATCH (s:Student)-[r:ENROLLED]-(c:Course)
	WHERE r.ACTIVE = FALSE AND s.BANNER_ID = line.BANNER_ID AND c.COURSE_CODE = line.COURSE_CODE
SET r.PERC = TOINTEGER(line.PERC);

//#####################################################################

// Calculate Average marks and assign expected grade for all students
MATCH (s:Student)-[r:ENROLLED]-(c:Course) WHERE r.ACTIVE = FALSE
WITH AVG(r.PERC) AS average, s // AVG(r.PERC)
SET s.DEG_CLASS = CASE WHEN average>=70 THEN "First-class Honours" WHEN average>=60 THEN "Upper Second-class Honours" WHEN average>=50 THEN "Lower Second-class Honours" WHEN average>=40 THEN "Third-class Honours" ELSE "Ordinary Degree" END;

// Set the year of study of a student based on which courses they are enrolled on
MATCH (s:Student)-[r:ENROLLED]-(c:Course)
WITH MAX(r.YOS_CODE) as YOS_CODE, s
SET s.YOS_CODE = TOINTEGER(YOS_CODE);

// Set the length of a programme based on the maximum year code of a course that is associated with it
MATCH (c:Course)-[r:ON_PROGRAMME]-(p:Programme)
WITH MAX(r.YOS_CODE) as YOS_CODE, p
SET p.PROG_DURATION = TOINTEGER(YOS_CODE);

// Matches pairs of courses a single student has failed both of, creates weighted relationship between them.
MATCH (c1:Course)-[r1:ENROLLED]-(s:Student)-[r2:ENROLLED]-(c2:Course)
WHERE r1.ACTIVE = FALSE AND r2.ACTIVE = FALSE AND r1.PERC < 40 AND r2.PERC < 40
AND (r1.YOS_CODE < r2.YOS_CODE OR (r1.YOS_CODE = r2.YOS_CODE AND c1.PTRM < c2.PTRM))
WITH c1, c2, r1, r2
MERGE (c1)-[f:CORRELATED_FAILS]->(c2)
	ON CREATE SET f.COUNT = 1
	ON MATCH SET f.COUNT = f.COUNT + 1;
	
// Add percentage to relationship weight
MATCH (c1:Course)-[r:CORRELATED_FAILS]-(c2:Course)
WHERE r.COUNT > 10 // Threshold to discount minimal data count
WITH c1, c2, r, r.COUNT as FailCount
MATCH (c1)-[r1:ENROLLED]-(s:Student)-[r2:ENROLLED]-(c2)
WHERE r1.PERC < 40
WITH c1,c2, r, FailCount, Count(s) as Total
WITH c1, c2, r, Total, FailCount, ROUND((TOFLOAT(FailCount)/Total)*100,1) as Percent
MATCH (c1)-[r]-(c2) 
SET r.PERC_FAIL = Percent;

// Create a relationship between every programme and its School (Currently Only MACS)
CREATE (s:School {NAME: "MACS"});
MATCH (p:Programme), (s:School) WHERE s.NAME = "MACS"
MERGE (p)-[:PART_OF]-(s);

// Manually add Pre-requisite course relationships (Computer Science Courses)
MATCH (c:Course {COURSE_CODE: "F28ED"}), (d:Course {COURSE_CODE: "F27ID"}) MERGE (c)-[:PRE_REQUISITE]->(d);
MATCH (c:Course {COURSE_CODE: "F28PL"}), (d:Course {COURSE_CODE: "F27SB"}) MERGE (c)-[:PRE_REQUISITE]->(d);
MATCH (c:Course {COURSE_CODE: "F28PL"}), (d:Course {COURSE_CODE: "F27CS"}) MERGE (c)-[:PRE_REQUISITE]->(d);
MATCH (c:Course {COURSE_CODE: "F28WP"}), (d:Course {COURSE_CODE: "F27WD"}) MERGE (c)-[:PRE_REQUISITE]->(d);
MATCH (c:Course {COURSE_CODE: "F28SD"}), (d:Course {COURSE_CODE: "F27SA"}) MERGE (c)-[:PRE_REQUISITE]->(d);
MATCH (c:Course {COURSE_CODE: "F28DM"}), (d:Course {COURSE_CODE: "F27WD"}) MERGE (c)-[:PRE_REQUISITE]->(d);
MATCH (c:Course {COURSE_CODE: "F28HS"}), (d:Course {COURSE_CODE: "F27CS"}) MERGE (c)-[:PRE_REQUISITE]->(d);
MATCH (c:Course {COURSE_CODE: "F28DA"}), (d:Course {COURSE_CODE: "F27SB"}) MERGE (c)-[:PRE_REQUISITE]->(d);
MATCH (c:Course {COURSE_CODE: "F28CD"}), (d:Course {COURSE_CODE: "F27IS"}) MERGE (c)-[:PRE_REQUISITE]->(d);
MATCH (c:Course {COURSE_CODE: "F28CD"}), (d:Course {COURSE_CODE: "F27WD"}) MERGE (c)-[:PRE_REQUISITE]->(d);
MATCH (c:Course {COURSE_CODE: "F28LL"}), (d:Course {COURSE_CODE: "F27SA"}) MERGE (c)-[:PRE_REQUISITE]->(d);
MATCH (c:Course {COURSE_CODE: "F28LL"}), (d:Course {COURSE_CODE: "F27SB"}) MERGE (c)-[:PRE_REQUISITE]->(d);
MATCH (c:Course {COURSE_CODE: "F28LL"}), (d:Course {COURSE_CODE: "F27CX"}) MERGE (c)-[:PRE_REQUISITE]->(d);
MATCH (c:Course {COURSE_CODE: "F28SX"}), (d:Course {COURSE_CODE: "F27SA"}) MERGE (c)-[:PRE_REQUISITE]->(d);

MATCH (c:Course {COURSE_CODE: "F29DC"}), (d:Course {COURSE_CODE: "F28WP"}) MERGE (c)-[:PRE_REQUISITE]->(d);
MATCH (c:Course {COURSE_CODE: "F29SO"}), (d:Course {COURSE_CODE: "F28DM"}) MERGE (c)-[:PRE_REQUISITE]->(d);
MATCH (c:Course {COURSE_CODE: "F29SO"}), (d:Course {COURSE_CODE: "F28SD"}) MERGE (c)-[:PRE_REQUISITE]->(d);
MATCH (c:Course {COURSE_CODE: "F29FB"}), (d:Course {COURSE_CODE: "F17SC"}) MERGE (c)-[:PRE_REQUISITE]->(d);
MATCH (c:Course {COURSE_CODE: "F29LP"}), (d:Course {COURSE_CODE: "F28PL"}) MERGE (c)-[:PRE_REQUISITE]->(d);
MATCH (c:Course {COURSE_CODE: "F29DS"}), (d:Course {COURSE_CODE: "F28IR"}) MERGE (c)-[:PRE_REQUISITE]->(d);
MATCH (c:Course {COURSE_CODE: "F29NC"}), (d:Course {COURSE_CODE: "F27CX"}) MERGE (c)-[:PRE_REQUISITE]->(d);
MATCH (c:Course {COURSE_CODE: "F29NC"}), (d:Course {COURSE_CODE: "F28IR"}) MERGE (c)-[:PRE_REQUISITE]->(d);

MATCH (c:Course {COURSE_CODE: "F20BC"}), (d:Course {COURSE_CODE: "F29AI"}) MERGE (c)-[:PRE_REQUISITE]->(d);
MATCH (c:Course {COURSE_CODE: "F20DL"}), (d:Course {COURSE_CODE: "F29AI"}) MERGE (c)-[:PRE_REQUISITE]->(d);
MATCH (c:Course {COURSE_CODE: "F20IF"}), (d:Course {COURSE_CODE: "F29SO"}) MERGE (c)-[:PRE_REQUISITE]->(d);
MATCH (c:Course {COURSE_CODE: "F20IF"}), (d:Course {COURSE_CODE: "F29PD"}) MERGE (c)-[:PRE_REQUISITE]->(d);
MATCH (c:Course {COURSE_CODE: "F20RO"}), (d:Course {COURSE_CODE: "F29AI"}) MERGE (c)-[:PRE_REQUISITE]->(d);
MATCH (c:Course {COURSE_CODE: "F20RS"}), (d:Course {COURSE_CODE: "F28SD"}) MERGE (c)-[:PRE_REQUISITE]->(d);
MATCH (c:Course {COURSE_CODE: "F20SA"}), (d:Course {COURSE_CODE: "F17SC"}) MERGE (c)-[:PRE_REQUISITE]->(d);
MATCH (c:Course {COURSE_CODE: "F20AD"}), (d:Course {COURSE_CODE: "F27ID"}) MERGE (c)-[:PRE_REQUISITE]->(d);
MATCH (c:Course {COURSE_CODE: "F20AN"}), (d:Course {COURSE_CODE: "F29DC"}) MERGE (c)-[:PRE_REQUISITE]->(d);
MATCH (c:Course {COURSE_CODE: "F20CA"}), (d:Course {COURSE_CODE: "F29AI"}) MERGE (c)-[:PRE_REQUISITE]->(d);

MATCH (c:Course {COURSE_CODE: "F21BC"}), (d:Course {COURSE_CODE: "F29AI"}) MERGE (c)-[:PRE_REQUISITE]->(d);
MATCH (c:Course {COURSE_CODE: "F21DL"}), (d:Course {COURSE_CODE: "F29AI"}) MERGE (c)-[:PRE_REQUISITE]->(d);
MATCH (c:Course {COURSE_CODE: "F21IF"}), (d:Course {COURSE_CODE: "F29SO"}) MERGE (c)-[:PRE_REQUISITE]->(d);
MATCH (c:Course {COURSE_CODE: "F21IF"}), (d:Course {COURSE_CODE: "F29PD"}) MERGE (c)-[:PRE_REQUISITE]->(d);
MATCH (c:Course {COURSE_CODE: "F21RO"}), (d:Course {COURSE_CODE: "F29AI"}) MERGE (c)-[:PRE_REQUISITE]->(d);
MATCH (c:Course {COURSE_CODE: "F21RS"}), (d:Course {COURSE_CODE: "F28SD"}) MERGE (c)-[:PRE_REQUISITE]->(d);

MATCH (c:Course {COURSE_CODE: "F21AD"}), (d:Course {COURSE_CODE: "F27ID"}) MERGE (c)-[:PRE_REQUISITE]->(d);
MATCH (c:Course {COURSE_CODE: "F21AN"}), (d:Course {COURSE_CODE: "F21CN"}) MERGE (c)-[:PRE_REQUISITE]->(d);
MATCH (c:Course {COURSE_CODE: "F21CA"}), (d:Course {COURSE_CODE: "F29AI"}) MERGE (c)-[:PRE_REQUISITE]->(d);
MATCH (c:Course {COURSE_CODE: "F21MP"}), (d:Course {COURSE_CODE: "F21RP"}) MERGE (c)-[:PRE_REQUISITE]->(d);


