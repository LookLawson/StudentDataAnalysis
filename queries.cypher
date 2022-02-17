

// Calculate average marks per year per programme [Bar Chart]
MATCH (p:Programme) //WHERE p.PROG_CODE = "F291-COS"
WITH p, RANGE(1,p.PROG_DURATION) as years
UNWIND years as year 
MATCH (:Student)-[r:ENROLLED]->(:Course)-[:COURSE_PROGRAMME]-(p) WHERE r.YOS_CODE = year AND r.ACTIVE = FALSE 
WITH AVG(r.PERC) as average, year, p
RETURN round(average,2) as value, year, p.PROG_DESC

// Degree Classification Distribution [Pie Chart]
MATCH (s:Student)
RETURN s.DEG_CLASS as DegreeClassification, 
count(s.DEG_CLASS) as Count ORDER BY Count


// Average difference between a students grades in a course and its prerequisite course [Table]
MATCH (c:Course)-[r1:ENROLLED]-(s:Student)-[r2:ENROLLED]-(pc:Course)<-[:PRE_REQUISITE]-(c)
WHERE r1.ACTIVE = FALSE AND r2.ACTIVE = FALSE
RETURN ABS(AVG(r1.PERC-r2.PERC)) AS AbsoluteDifference, c.COURSE_CODE as Course, pc.COURSE_CODE as PreReqCourse