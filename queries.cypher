
// QUESTION 1 
// [1a] Show average marks per year per programme [Bar Chart]
MATCH (p:Programme)
WITH p, RANGE(1,p.PROG_DURATION) as years
UNWIND years as year
MATCH (:Student)-[r:ENROLLED]->(:Course)-[:COURSE_PROGRAMME]-(p)
WHERE r.YOS_CODE = year AND r.ACTIVE = FALSE 
RETURN year as Year, ROUND(AVG(r.PERC),2) as Average, p.PROG_DESC as Programme

// [1b] Show the average change in marks from 1st year to 2nd year
MATCH (c1:Course)-[r1:ENROLLED]-(s:Student)-[r2:ENROLLED]-(c2:Course)
WHERE r1.ACTIVE = FALSE AND r2.ACTIVE = FALSE AND r1.YOS_CODE = 1 AND r2.YOS_CODE = 2
RETURN ROUND(AVG(r2.PERC-r1.PERC),2) as Delta

// [1c] Quantify the amount of students that drop beyond a threshold change.	
//MATCH (c1:Course)-[r1:ENROLLED]-(s:Student)-[r2:ENROLLED]-(c2:Course)
//WHERE r1.ACTIVE = FALSE AND r2.ACTIVE = FALSE AND r1.YOS_CODE = 1 AND r2.YOS_CODE = 2
//WITH ROUND(AVG(r1.PERC)-AVG(r2.PERC),2) as Delta, s
//WITH COUNT(CASE WHEN Delta >= 10 THEN Delta WHEN Delta <= -10 THEN Delta END) AS thresholdCount
//MATCH (s:Student)
//RETURN thresholdCount, COUNT(s) as TotalStudents
// [1c1] Quantify the amount of students that drop beyond a $thresholdperc change.	
MATCH (c1:Course)-[r1:ENROLLED]-(s:Student)-[r2:ENROLLED]-(c2:Course)
WHERE r1.ACTIVE = FALSE AND r2.ACTIVE = FALSE AND r1.YOS_CODE = 1 AND r2.YOS_CODE = 2
WITH (1 - ROUND(AVG(r2.PERC)/AVG(r1.PERC),2)) as Delta, s, TOFLOAT($neodash_thresholdperc) as thresh
WITH COUNT(CASE WHEN Delta >= thresh THEN Delta END) AS SlumpCount
MATCH (s:Student) WHERE s.YOS_CODE >= 2
RETURN TOFLOAT($neodash_thresholdperc)*100 + "%" as Threshold, SlumpCount, COUNT(s) as StudentsInSet, ROUND(TOFLOAT(SlumpCount)/COUNT(s) * 100,2) + "%" as PercentSlumped

// [1c2] Quantify the amount of students that drop beyond a $thresholdint change.	
MATCH (c1:Course)-[r1:ENROLLED]-(s:Student)-[r2:ENROLLED]-(c2:Course)
WHERE r1.ACTIVE = FALSE AND r2.ACTIVE = FALSE AND r1.YOS_CODE = 1 AND r2.YOS_CODE = 2
WITH ROUND(AVG(r1.PERC)-AVG(r2.PERC),2) as Delta, s, TOFLOAT($neodash_thresholdint) as thresh
WITH COUNT(CASE WHEN Delta >= thresh THEN Delta END) AS SlumpCount
MATCH (s:Student) WHERE s.YOS_CODE >= 2
RETURN $neodash_thresholdint + " Marks" as Threshold, SlumpCount, COUNT(s) as StudentsInSet, ROUND(TOFLOAT(SlumpCount)/COUNT(s) * 100,2) + "%" as PercentSlumped

////////////////////////////////////////////////////////////////////////////////////////////////////////////

// Question 3
// [3a1] Show the list of other courses failed previously by students who failed the given course
MATCH (c1:Course)-[r1:ENROLLED]-(s:Student)-[r2:ENROLLED]-(c2:Course)
WHERE r1.PERC < 40 AND r2.PERC < 40 AND c1.COURSE_CODE = $neodash_course_course_code AND r2.YOS_CODE < r1.YOS_CODE
RETURN c2.COURSE_CODE, COUNT(r2) as failCount ORDER BY failCount DESC
// [3a2] Show the list of other courses failed by students after failing the given course
MATCH (c1:Course)-[r1:ENROLLED]-(s:Student)-[r2:ENROLLED]-(c2:Course)
WHERE r1.PERC < 40 AND r2.PERC < 40 AND c1.COURSE_CODE = $neodash_course_course_code AND r2.YOS_CODE > r1.YOS_CODE
RETURN c2.COURSE_CODE, COUNT(r2) as failCount ORDER BY failCount DESC
// [3b] Show the percentage of students who failed the set of related courses after failing the given course
MATCH (c1:Course)-[r1:ENROLLED]-(s:Student)-[r2:ENROLLED]-(c2:Course)
WHERE r1.PERC < 40 AND r2.PERC < 40 AND c1.COURSE_CODE = $neodash_course_course_code
WITH c2.COURSE_CODE as Course, COUNT(r2) as CountFailed, r2.YOS_CODE as year
MATCH (c1:Course)-[r1:ENROLLED]-(s:Student)-[r2:ENROLLED]-(c2:Course)
WHERE r1.PERC < 40 AND r2.PERC < 40 AND c1.COURSE_CODE = $neodash_course_course_code
RETURN Course, ROUND(TOFLOAT(CountFailed)/COUNT(s)*100,2) as PercentFailed, year 
ORDER BY PercentFailed DESC
// NOTE: Could exclude courses from the same year. 

////////////////////////////////////////////////////////////////////////////////////////////////////////////


// [2] Degree Classification Distribution [Pie Chart]
MATCH (s:Student)
RETURN s.DEG_CLASS as DegreeClassification, 
count(s.DEG_CLASS) as Count ORDER BY Count


// [3] Average difference between a students grades in a course and its prerequisite course [Bar Chart]
MATCH (c:Course)-[r1:ENROLLED]-(s:Student)-[r2:ENROLLED]-(pc:Course)<-[:PRE_REQUISITE]-(c)
WHERE r1.ACTIVE = FALSE AND r2.ACTIVE = FALSE
WITH c.COURSE_CODE + " / " + pc.COURSE_CODE as Course, ROUND(AVG(r1.PERC-r2.PERC),2) as Delta, r1.YOS_CODE + "/" + r2.YOS_CODE as Years
RETURN Course, Delta, Years
ORDER BY Delta




