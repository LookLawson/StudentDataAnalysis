

// Calculate the average difference in marks between each year in Computer Science
MATCH (s:Student) WHERE s.BANNER_ID = "H00333527"
WITH RANGE(1, s.YOS_CODE) AS years, s
UNWIND years as year
MATCH (s)-[r:ENROLLED]-(c:Course) WHERE r.YOS_CODE = year
WITH AVG(r.PERC) as average, s
SET s.year = average


MATCH (s:Student)-[r:ENROLLED]-(c:Course) WHERE s.BANNER_ID = "H00333527"
WITH s.BANNER_ID as student, r.YOS_CODE as year
RETURN student, year;

MATCH (s:Student) WHERE s.BANNER_ID = "H00144254"
WITH s, RANGE(1,s.YOS_CODE) as years
UNWIND years as year 
	CALL apoc.cypher.run('MATCH (s:Student)-[r:ENROLLED]-(c:Course) WHERE s.BANNER_ID = "'+s.BANNER_ID+'" AND r.YOS_CODE = '+year+' AND r.ACTIVE = FALSE RETURN AVG(r.PERC) as average', {})
YIELD value
RETURN value
	

