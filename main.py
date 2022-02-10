# Import packages
import csv
import sys
import string
import random
import pandas as pd
import os
import re
from faker import Faker
from pathlib import Path

from collections import OrderedDict

# region Variables
studentCount = 3
currentAcademicYear = 202122
currentSemester = 2
courses = {}
programmes = {}

# Keep track of generated ID's to ensure uniqueness
uniqueHWIDs = []
uniqueUserIDs = []

# endregion


class Programme:

    def __init__(self, row):
        self.mandCourses = {
            1: [[], [], []],
            2: [[], [], []],
            3: [[], [], []],
            4: [[], [], []],
            5: [[], [], []]
        }
        self.optCourses = {
            1: [[], [], []],
            2: [[], [], []],
            3: [[], [], []],
            4: [[], [], []],
            5: [[], [], []]
        }
        self.optCount = {
            1: [0, 0, 0],
            2: [0, 0, 0],
            3: [0, 0, 0],
            4: [0, 0, 0],
            5: [0, 0, 0]
        }
        try:
            self.PROG_DESC = row[8].strip()
            # TODO: Make CSV include course code, then use this properly
            self.PROG_CODE = self.PROG_DESC
            self.addCourse(row)
            year = int(row[5][0])
            semester = int(row[4][0]) - 1
            if row[6] != "":
                self.optCount[year][semester] = int(row[6][0])
            else:
                self.optCount[year][semester] = 0
        except Exception as e:
            print(e)
            print(row)

    def addCourse(self, row):
        try:
            semester = courses[row[1]].PTRM - 1
            year = int(row[5][0])
            if "mandatory" in row[3].lower() and row[1] not in self.mandCourses[year][semester]:
                self.mandCourses[year][semester].append(row[1])
            elif "optional" in row[3].lower() and row[1] not in self.optCourses[year][semester]:
                self.optCourses[year][semester].append(row[1])

        except Exception as e:
            print(row)
            print(e)


class Course:

    def __init__(self, row):
        try:
            self.COURSE_CODE = row[1].strip()
            self.COURSE_TITLE = re.sub("[([].*?[)]]", "", row[2]).strip()
            if isinstance(row[4], int):
                self.PTRM = row[4]
            else:
                self.PTRM = int(row[4][0])
            self.CREDIT_HOURS = 15
        except Exception as e:
            print(e)
            print("/nSomething is wrong with line: /n" + row)


class Student:


    def __init__(self, f):
        self.ESTS_CODE = "EN"  # Language?
        self.ACTIVE_COURSES = []
        self.COMPLETED_COURSES = []
        self.__genPersonalInfo(f)
        self.__genCourseInfo()
        self.__genCoursesOLD()

    def __genPersonalInfo(self, f):
        self.BANNER_ID = genHWUid()
        self.TITLE = random.choices(["Mr", "Ms", "Mrs"], weights=[70, 25, 5])[0]
        if self.TITLE == "Mr":
            self.FIRST_NAME = f.first_name_male()
            if random.randint(1, 10) < 5:
                self.MIDDLE_NAME = f.first_name_male()
            else:
                self.MIDDLE_NAME = ''
        else:
            self.FIRST_NAME = f.first_name_female()
            if random.randint(1, 10) < 5:
                self.MIDDLE_NAME = f.first_name_female()
            else:
                self.MIDDLE_NAME = ''
        self.LAST_NAME = f.last_name()

        if not self.MIDDLE_NAME:
            userInitials = self.FIRST_NAME[0].lower() + self.LAST_NAME[0].lower()
        else:
            userInitials = self.FIRST_NAME[0].lower() + self.MIDDLE_NAME[0].lower() + self.LAST_NAME[0].lower()
        self.USERNAME = genUsername(userInitials)

    def __genCourseInfo(self):
        self.PROG_CODE = random.choice(list(programmes.keys()))
        self.PROG_DESC = programmes[self.PROG_CODE].PROG_DESC

        if "MSc" in self.PROG_DESC or "PhD" in self.PROG_DESC:
            # TODO: You're still an UG until year 5 even if you're own a MSc course though right?
            self.YOS_CODE = random.randrange(1, 6)
            if self.YOS_CODE != 5:
                self.LEVL_CODE = "UG"
            else:
                self.LEVL_CODE = "PG"
        else:
            self.YOS_CODE = random.randrange(1, 5)
            self.LEVL_CODE = "UG"

        # TODO: Account for inactive and non-Edinburgh campus students
        self.CAMP_CODE = "1ED"
        self.CAMP_DESC = "Edinburgh"
        self.ACTIVE_STATUS = "AS"

        if self.ACTIVE_STATUS == "AS":
            self.TERM_CODE = currentAcademicYear
        else:
            self.TERM_CODE = random.choice(["202021", "201920", "201819", "201718", "201617", "201516"])

    def __genCoursesOLD(self):
        # TODO: Account for courses that earn 7.5 Credits
        for i in range(self.YOS_CODE + 1):

            # For Current Year
            if i == self.YOS_CODE:
                # Add Mandatory Courses
                for semester in programmes[self.PROG_CODE].mandCourses[self.YOS_CODE]:
                    if semester:
                        for course in semester:
                            self.ACTIVE_COURSES.append(course)

                # Add Optional Courses
                for semester in programmes[self.PROG_CODE].optCourses[self.YOS_CODE]:
                    if semester:
                        # Semester 1
                        if programmes[self.PROG_CODE].optCount[self.YOS_CODE][0] != 0:
                            for j in range(programmes[self.PROG_CODE].optCount[self.YOS_CODE][0]):
                                course = random.choice(semester)
                                if course not in self.ACTIVE_COURSES and currentSemester == course.PTRM:
                                    self.ACTIVE_COURSES.append(course)
                        # Some tables don't explicitly say how many optional courses you can take
                        else:
                            while len(self.ACTIVE_COURSES) < 4:
                                course = random.choice(semester)
                                if course not in self.ACTIVE_COURSES and currentSemester == semester[course].PTRM:
                                    self.ACTIVE_COURSES.append(course)
                        # Semester 2
                        if programmes[self.PROG_CODE].optCount[self.YOS_CODE][1] != 0:
                            for j in range(programmes[self.PROG_CODE].optCount[self.YOS_CODE][1]):
                                course = random.choice(semester)
                                if course not in self.ACTIVE_COURSES and currentSemester == semester[course].PTRM:
                                    self.ACTIVE_COURSES.append(course)

            # For Previous Years
            else:
                for semester in programmes[self.PROG_CODE].mandCourses[self.YOS_CODE]:
                    if semester is not []:
                        for course in semester:
                            self.COMPLETED_COURSES.append((course, self.genMark()))

    def __genCourses(self):
        for year in programmes[s.PROG_CODE].mandCourses:
            break
        self.__addMandatoryCourses()
        self.__addOptionalCourse()

    def __addMandatoryCourses(self, year, semester):
        for course in programmes[self.PROG_CODE].mandCourses[year][semester]:
            if self.YOS_CODE < year:
                self.COMPLETED_COURSES.append((course, self.generateMark()))
            elif self.YOS_CODE == year:
                if semester == currentSemester:
                    self.ACTIVE_COURSES.append(course)
                elif semester < currentSemester:
                    self.COMPLETED_COURSES.append((course, self.generateMark()))

    # TODO: Break loop: Either when len(active/completed courses per semester) == 4 OR when optCount reached.
    # TODO: SUM of course credits > 60
    def __addOptionalCourse(self, year, semester):
        course = random.choice(programmes[self.PROG_CODE].optCourses[year][semester])
        if course not in self.COMPLETED_COURSES and course not in self.ACTIVE_COURSES:
            if self.YOS_CODE < year:
                self.COMPLETED_COURSES.append((course, self.generateMark()))
            elif self.YOS_CODE == year:
                if semester == currentSemester:
                    self.ACTIVE_COURSES.append(course)
                elif semester < currentSemester:
                    self.COMPLETED_COURSES.append((course, self.generateMark()))
        else:
            self.__addOptionalCourses(year, semester)

    def __genMark(self):
        return random.randrange(45, 90)


# region "Gen" Functions
def genHWUid():
    hwid = "H00" + str(random.randrange(100000, 400000))
    if hwid not in uniqueHWIDs:
        uniqueHWIDs.append(hwid)
    else:
        hwid = genHWUid()
    return hwid


def genUsername(userInitials):
    n = random.randrange(1, 100)
    username = userInitials + str(n)
    if username not in uniqueUserIDs:
        return username
    else:
        genUsername(userInitials)
# endregion


# region "File" Functions
def writeCSV(header, data):
    with open("output.csv", "w", newline='') as f:
        writer = csv.writer(f)
        writer.writerow(header)
        for row in data:
            line = []
            for column in header:
                line.append(str(getattr(row, column, " n/a ")))
            writer.writerow(line)


def readHeaders(filename: string):
    header = []
    with open(filename, "r") as file:
        h = csv.reader(file)
        for row in h:
            for element in row:
                header.append(element.strip())
    return header


def readProgrammes(fileName: string):
    # Read xlsx and write to csv
    curDir = os.getcwd()
    df = pd.ExcelFile(fileName)
    for sheet in df.sheet_names:
        if "raw" not in sheet.lower():
            df.parse(sheet_name=sheet).to_csv("programmes\\" + sheet + ".csv")

    # Read csv
    os.chdir("programmes")
    for file in os.listdir():
        if file.endswith(".csv"):
            file_path = Path(file)
            with open(file_path, 'r') as f:
                reader = csv.reader(f)
                for row in reader:
                    try:
                        if row[0] != "":
                            # Add courses to a dictionary of CourseCode: CourseObject
                            courseCode = row[1]
                            semester = int(row[4].strip()) - 1
                            year = int(row[5].strip())
                            progCode = row[8]
                            # TODO: Account for bullshitery with random-ass formatting on the macs site,
                            #  might not be relevant for the Uni-wide site
                            if courseCode not in courses and re.match(r'[A-Z]+[0-9]{2}[A-Z]{2}', courseCode):
                                courses[courseCode] = Course(row)
                            elif courseCode == "1 SCQ":
                                # TODO: Add SCQ course to Programme Objects
                                break

                            # Add Programmes to a dictionary of ProgCode: ProgrammeObject
                            # TODO: Optional Count
                            if progCode not in programmes:
                                p = Programme(row)
                                if row[6] != '':  # Don't judge, int() can't cast from a float String, but float() can
                                    p.optCount[year][semester] = int(float(row[6].strip()))
                                programmes[progCode] = p
                            else:
                                programmes[progCode].addCourse(row)
                                if row[6] != '':
                                    programmes[progCode].optCount[year][semester] = int(float(row[6].strip()))
                    except Exception as e:
                        print(e)
                        print(row)

    os.chdir(curDir)
# endregion


# TODO: TO BE REPLACED BY WEB SCRAPER WITH PROPER SEMESTER CLASSIFICATION
def readCourseList(folderPath: string):
    courseSemester = 1
    directory = os.getcwd()
    os.chdir(folderPath)
    for file in os.listdir():
        if file.endswith(".txt"):
            file_path = Path(file)
            with open(file_path, 'r') as f:
                for line in f.readlines():
                    match = re.search(r'\s[A-Z]+[0-9]{2}[A-Z]{2}\s', line)
                    if match:
                        courseCode = match.group(0).strip()
                        courseName = line[10:]
                        courses[courseCode] = Course(['', courseCode, courseName, '', courseSemester])
                    elif line.startswith("Semester "):
                        courseSemester = int(line[-2:])
    os.chdir(directory)


if __name__ == '__main__':
    students = []
    headers = readHeaders(sys.argv[1])

    readCourseList("programmes")
    readProgrammes("ProgrammeData.xlsx")

    faker = Faker(["en_GB"])
    for i in range(studentCount):
        s = Student(faker)
        students.append(s)

    ''' Print course List 
    for e in [*courses.values()]:
        for attribute in (e.__dict__.keys()):
            print(str(attribute) + ":" + str(getattr(e, attribute)), end=" ¦ ")
        print('')
    '''

    ''' Print programme List 
    for prog in [*programmes.values()]:
        print(prog.PROG_CODE)
        for year in prog.mandCourses:
            print("\nYear " + str(year))
            print(prog.mandCourses[year])
            print(prog.optCourses[year])
            print(prog.optCount[year])
        print("\n ############### \n")
    '''

    ''' Print student list '''
    for s in students:
        # for attribute in (s.__dict__.keys()):
        #    print(str(attribute) + ":" + str(getattr(s, attribute)), end=" ¦\t")


        print(s.BANNER_ID + "(" + s.PROG_CODE + "): " + str(s.ACTIVE_COURSES) + " ¦¦¦ " +  str(s.COMPLETED_COURSES))
        print(programmes[s.PROG_CODE].mandCourses)
        print(programmes[s.PROG_CODE].optCourses)
        print(programmes[s.PROG_CODE].optCount)
        print('')

    # writeCSV(headers, students)
