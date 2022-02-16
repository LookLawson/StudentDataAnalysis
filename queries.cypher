// Calculate Average marks and assign expected grade for all students
MATCH (s:Student)-[r:ENROLLED]-(c:Course) WHERE r.ACTIVE = FALSE
WITH (SUM(r.PERC) / COUNT(r)) AS average, s
SET s.DEG_CLASS = CASE WHEN average>=70 THEN "First-class Honours" WHEN average>=60 THEN "Upper Second-class Honours" WHEN average>=50 THEN "Lower Second-class Honours" WHEN average>=40 THEN "Third-class Honours" ELSE "Ordinary Degree" END
// Testing //##########################################################
MATCH (s:Student) WHERE s.DEG_CLASS = "First-class Honours" RETURN COUNT(s);
MATCH (s:Student) WHERE s.DEG_CLASS = "Upper Second-class Honours" RETURN COUNT(s);
MATCH (s:Student) WHERE s.DEG_CLASS = "Lower Second-class Honours" RETURN COUNT(s);
MATCH (s:Student) WHERE s.DEG_CLASS = "Third-class Honours" RETURN COUNT(s);
//#####################################################################

// Calculate the average difference in marks between each year in Computer Science
MATCH (s:Student) WHERE s.BANNER_ID = "H00333527"
WITH RANGE(1, s.YOS_CODE) AS years, s
UNWIND years as year
MATCH (s)-[r:ENROLLED]-(c:Course) WHERE r.YOS_CODE = year
WITH AVG(r.PERC) as average, s
SET s.year = average


MATCH (s:Student)-[r:ENROLLED]-(c:Course) WHERE s.BANNER_ID = "H00333527"
WITH s.BANNER_ID as student, r.YOS_CODE as year
RETURN student, year
	

