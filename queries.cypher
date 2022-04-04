
// Second Year Slump question

// [1a1] Show average marks per year per programme [Bar Chart]
MATCH (p:Programme)
WITH p, RANGE(1,p.PROG_DURATION) as years
UNWIND years as year // For year of study in each programme
MATCH (p)-[:ON_PROGRAMME]-(:Student)-[r:ENROLLED]->(:Course)
WHERE r.YOS_CODE = year AND r.ACTIVE = FALSE
RETURN year as YearOfStudy, ROUND(AVG(r.PERC),2) as AverageGrade, p.PROG_DESC as Programme
// [1a2] Show the average change in marks from 1st year to 2nd year
MATCH (s:Student)-[r:ENROLLED]-(:Course)
WHERE r.ACTIVE = FALSE AND r.YOS_CODE = 1
WITH AVG(r.PERC) as Year1Avg, s
MATCH (s)-[r:ENROLLED]-(:Course)
WHERE r.ACTIVE = FALSE AND r.YOS_CODE = 2
WITH AVG(r.PERC)-Year1Avg as Delta, s
RETURN ROUND(AVG(Delta),2) as AverageDelta
// [1a2] Show the median change in marks from 1st year to 2nd year
MATCH (s:Student)-[r:ENROLLED]-(:Course)
WHERE r.ACTIVE = FALSE AND r.YOS_CODE = 1
WITH AVG(r.PERC) as Year1Avg, s
MATCH (p:Programme)-[:ON_PROGRAMME]-(s)-[r:ENROLLED]-(:Course)
WHERE r.ACTIVE = FALSE AND r.YOS_CODE = 2
WITH ROUND(AVG(r.PERC)-Year1Avg,2) as Delta, s, p.PROG_DESC as Programme
ORDER BY Delta
RETURN percentileCont(Delta, 0.5) as MedianDelta
	,Programme

// [1b1] Quantify the amount of students that drop beyond an percentage change.
MATCH (s:Student)-[r:ENROLLED]-(:Course)
WHERE r.ACTIVE = FALSE AND r.YOS_CODE = 1
WITH AVG(r.PERC) as Year1Avg, s
MATCH (s)-[r:ENROLLED]-(:Course)
WHERE r.ACTIVE = FALSE AND r.YOS_CODE = 2
WITH (1 - AVG(r.PERC)/Year1Avg) as DeltaPerc, s, TOFLOAT($neodash_thresholdperc) as thresh
WITH COUNT(CASE WHEN DeltaPerc >= thresh THEN DeltaPerc END) AS SlumpCount, COUNT(s) as TotalCount, thresh
RETURN thresh*100 + "%" as Threshold, SlumpCount, TotalCount, 
	ROUND(TOFLOAT(SlumpCount)/TotalCount * 100,2) + "%" as PercentSlumped
// [1b2] Quantify the amount of students that drop beyond an integer change.
MATCH (s:Student)-[r:ENROLLED]-(:Course)
WHERE r.ACTIVE = FALSE AND r.YOS_CODE = 1
WITH AVG(r.PERC) as Year1Avg, s
MATCH (s)-[r:ENROLLED]-(:Course)
WHERE r.ACTIVE = FALSE AND r.YOS_CODE = 2
WITH ROUND(AVG(r.PERC)-Year1Avg,2) as Delta, s, TOFLOAT($neodash_thresholdint) as thresh
WITH COUNT(CASE WHEN -Delta >= thresh THEN Delta END) AS SlumpCount, COUNT(s) as TotalCount, thresh
RETURN thresh + " marks" as Threshold, SlumpCount, TotalCount, 
	ROUND(TOFLOAT(SlumpCount)/TotalCount * 100,2) + "%" as PercentSlumped
	
	
	
// [1c2] Quantify the amount of students that drop beyond a $thresholdint change.	
MATCH (c1:Course)-[r1:ENROLLED]-(s:Student)-[r2:ENROLLED]-(c2:Course)
WHERE r1.ACTIVE = FALSE AND r2.ACTIVE = FALSE AND r1.YOS_CODE = 1 AND r2.YOS_CODE = 2
WITH ROUND(AVG(r1.PERC)-AVG(r2.PERC),2) as Delta, s, TOFLOAT($neodash_thresholdint) as thresh
WITH COUNT(CASE WHEN Delta >= thresh THEN Delta END) AS SlumpCount
MATCH (s:Student) WHERE s.YOS_CODE >= 2
RETURN $neodash_thresholdint + " Marks" as Threshold, SlumpCount, COUNT(s) as StudentsInSet, ROUND(TOFLOAT(SlumpCount)/COUNT(s) * 100,2) + "%" as PercentSlumped


////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////


// Question 2 
// [2a] Average difference between a students grades in a course and its prerequisite course [Bar Chart]
MATCH (c:Course)-[r1:ENROLLED]-(s:Student)-[r2:ENROLLED]-(pc:Course)<-[:PREREQUISITE]-(c)
WHERE r1.ACTIVE = FALSE AND r2.ACTIVE = FALSE
WITH c.COURSE_CODE + " / " + pc.COURSE_CODE as Course, ROUND(AVG(r1.PERC-r2.PERC),2) as Delta, r1.YOS_CODE + "/" + r2.YOS_CODE as Years
RETURN Course, Delta, Years
ORDER BY Delta

////////////////////////////////////////////////////////////////////////////////////////////////////////////
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
////////////////////////////////////////////////////////////////////////////////////////////////////////////


// Question 4
// [4a1] Degree Classification Distribution [Pie Chart]
MATCH (s:Student)
WITH s.DEG_CLASS as DegreeClassification, COUNT(s.DEG_CLASS) as DegCount
MATCH (s:Student)
RETURN DegreeClassification, ROUND(TOFLOAT(DegCount)/COUNT(s)*100) as DegPercent
ORDER BY DegPercent
// [4a2] Grades Distribution [Rounded to 10, line chart]
MATCH (s:Student)-[r:ENROLLED]-(c:Course)
WITH ROUND(TOFLOAT(AVG(r.PERC))*0.01/10,2)*1000 as average, s
RETURN average, COUNT(s)
ORDER BY average
// [4a3] Grades Distribution [Rounded to 5, line chart]
MATCH (s:Student)-[r:ENROLLED]-(c:Course)
WITH ROUND(TOFLOAT(AVG(r.PERC)*0.01)/5,2)*500 as average, s
RETURN average, COUNT(s)
ORDER BY average
// [4b] Mark distribution for Student by year
//MATCH (s:Student) WHERE s.BANNER_ID = $neodash_student_banner_id
//UNWIND RANGE(1,s.YOS_CODE) as year
//MATCH(s:Student)-[r:ENROLLED]-(c:Course)
//WHERE r.YOS_CODE = year
//RETURN year, ROUND(AVG(r.PERC)) as Value
// [4b] Mark distribution for Student by course
MATCH(s:Student)-[r:ENROLLED]-(c:Course) 
WHERE s.BANNER_ID = $neodash_student_banner_id AND r.ACTIVE = FALSE
RETURN c.COURSE_CODE as Course, r.PERC as Mark, r.YOS_CODE as YearofStudy
ORDER BY YearofStudy
// [4c] Degree Classification percentage by Programme
MATCH (p:Programme)-[r1:ON_PROGRAMME]-(s:Student)-[r2:ENROLLED]-(c:Course)-[r3:ON_PROGRAMME]-(p)
WHERE p.PROG_CODE = $neodash_programme_prog_code AND s.ACTIVE_STATUS = FALSE
WITH DISTINCT s.DEG_CLASS as degs, p, s
UNWIND degs as deg
	MATCH (s)-[:ON_PROGRAMME]-(p) WHERE s.DEG_CLASS = deg 
	WITH count(s) as StudentCount, deg
MATCH (s:Student)-[:ON_PROGRAMME]-(p:Programme)
WHERE p.PROG_CODE = $neodash_programme_prog_code AND s.ACTIVE_STATUS = FALSE
RETURN deg, ROUND(TOFLOAT(StudentCount)/Count(s)*100,1) as Percentage
// [4d] Mark distribution (rounded to 5) for all student on a programme and for a particular year range
MATCH (p:Programme)-[:ON_PROGRAMME]-(s:Student)-[r:ENROLLED]-(c:Course)
WHERE p.PROG_CODE = $neodash_programme_prog_code AND TOINTEGER($yearA) <= r.TERM_CODE <= TOINTEGER($yearB)
WITH ROUND(TOFLOAT(AVG(r.PERC)*0.01)/5,2)*500 as average, s
RETURN DISTINCT average, COUNT(s)
ORDER BY average



////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////

[GRAPH]
// OBJECTIVE: Heatmap style graph pattern showing how linked failing one course leads to failing another
MATCH ()-[r:CORRELATED_FAILS]-() DELETE r;
// Matches pairs of courses a single student has failed both of, creates weighted relationship between them.
MATCH (c1:Course)-[r1:ENROLLED]-(s:Student)-[r2:ENROLLED]-(c2:Course)
WHERE r1.ACTIVE = FALSE AND r2.ACTIVE = FALSE AND r1.PERC < 40 AND r2.PERC < 40
AND (r1.YOS_CODE < r2.YOS_CODE OR (r1.YOS_CODE = r2.YOS_CODE AND c1.PTRM < c2.PTRM))
WITH c1, c2, r1, r2
MERGE (c1)-[f:CORRELATED_FAILS]->(c2)
	ON CREATE SET f.COUNT = 1
	ON MATCH SET f.COUNT = f.COUNT + 1;
// Match course correlated fails relationships 
MATCH (c1:Course)-[r:CORRELATED_FAILS]-(c2:Course)
WHERE r.COUNT > 40
RETURN c1,c2,r ORDER BY r.COUNT DESC

// Match correlated fail relationship of high percentage
MATCH (c1:Course)-[r:CORRELATED_FAILS]-(c2:Course)
WHERE r.COUNT > 10
WITH c1, c2, r, r.COUNT as FailCount
MATCH (c1)-[r1:ENROLLED]-(s:Student)-[r2:ENROLLED]-(c2)
WHERE r1.PERC < 40
WITH c1,c2, r, FailCount, Count(s) as Total
RETURN c1, c2, r, Total, FailCount, ROUND((TOFLOAT(FailCount)/Total)*100,1) as Percent
ORDER BY Percent DESC

// Add percentage to relationship weight
MATCH (c1:Course)-[r:CORRELATED_FAILS]-(c2:Course)
//WHERE r.COUNT > 10 // Threshold to discount minimal data count
WITH c1, c2, r, r.COUNT as FailCount
MATCH (c1)-[r1:ENROLLED]-(s:Student)-[r2:ENROLLED]-(c2)
WHERE r1.PERC < 40
WITH c1,c2, r, FailCount, Count(s) as Total
WITH c1, c2, r, Total, FailCount, ROUND((TOFLOAT(FailCount)/Total)*100,1) as Percent
MATCH (c1)-[r]-(c2) 
SET r.PERC_FAIL = Percent


// Test Data Creation
MATCH (s:Student) DETACH DELETE s;
UNWIND RANGE(1,100) as i
CREATE (s:Student {BANNER_ID: i});
// Over 50s fail F27PX
MATCH (s:Student), (c:Course {COURSE_CODE: "F27PX"})
MERGE (s)-[r:ENROLLED]-(c)
SET r.ACTIVE = FALSE, r.YOS_CODE = 2,
	r.PERC = CASE WHEN s.BANNER_ID > 50 THEN 20 ELSE 60 END;
// Under 50s fail F28PL
MATCH (s:Student), (c:Course {COURSE_CODE: "F28PL"})
MERGE (s)-[r:ENROLLED]-(c)
SET r.ACTIVE = FALSE, r.YOS_CODE = 2,
	r.PERC = CASE WHEN s.BANNER_ID <= 50 THEN 20 ELSE 60 END;
// Under 30s fail F29LP
MATCH (s:Student), (c:Course {COURSE_CODE: "F29LP"})
MERGE (s)-[r:ENROLLED]-(c)
SET r.ACTIVE = FALSE, r.YOS_CODE = 3,
	r.PERC = CASE WHEN s.BANNER_ID <= 30 THEN 20 ELSE 60 END;
// 30-80 fail F2SO
MATCH (s:Student), (c:Course {COURSE_CODE: "F29SO"})
MERGE (s)-[r:ENROLLED]-(c)
SET r.ACTIVE = FALSE, r.YOS_CODE = 3,
	r.PERC = CASE WHEN s.BANNER_ID <= 80 AND s.BANNER_ID > 30 THEN 20 ELSE 60 END;
	