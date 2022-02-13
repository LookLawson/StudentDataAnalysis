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
studentCount = 400
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
        try:
            self.PROG_DESC = row[8].strip()
            # TODO: Make CSV include course code, then use this properly
            self.PROG_CODE = self.PROG_DESC
            self.addCourse(row)
        except Exception as e:
            print("(Programme__inti) Something is wrong with: ", end='')
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
            print("(Programme_addCourse) Something is wrong with: ", end='')
            print(e)
            print(row)


class Course:

    def __init__(self, row):
        try:
            self.COURSE_CODE = row[1].strip()
            self.COURSE_TITLE = re.sub(r"\(.*\)", "", row[2]).strip()
            if isinstance(row[4], int):
                self.PTRM = row[4]
            else:
                self.PTRM = int(row[4][0])
            # TODO: Future format of CSV may have credits in its own column. For now its within the description
            creds = re.match(r'^.*?\([^\d]*(\d+\.*\d+)[^\d]*\).*$', row[2])
            if creds and float(creds.group(1)) < 99:
                self.CREDIT_HOURS = float(creds.group(1))
            else:
                self.CREDIT_HOURS = 15.0
        except Exception as e:
            print("(Course__init) Something is wrong in line: /n" + row)


class Student:

    def __init__(self, f):
        self.ESTS_CODE = "EN"  # Language?
        self.ACTIVE_COURSES = []
        self.COMPLETED_COURSES = []

        self.__genPersonalInfo(f)
        self.__genCourseInfo()
        print("\nCreating new year " + str(self.YOS_CODE) + self.PROG_CODE + " student...")
        # print(self.PROG_DESC + " mandatory courses: ")
        # for m in [*programmes[self.PROG_CODE].mandCourses.values()]:
        #     print(m)
        # print(self.PROG_DESC + " optional courses: ")
        # for o in [*programmes[self.PROG_CODE].optCourses.values()]:
        #     print(o)
        self.__genCourses()

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

        # Discount picking years on a course where there are no courses
        validYears = []
        for year in programmes[self.PROG_CODE].mandCourses:
            if any(programmes[self.PROG_CODE].mandCourses[year]):
                validYears.append(year)
        self.YOS_CODE = random.randrange(0, max(validYears)) + 1

        if "MSc" in self.PROG_DESC or "PhD" in self.PROG_DESC:
            # TODO: You're still an UG until year 5 even if you're own a MSc course though right?
            # Check to see which years in a programme actually contain courses
            if self.YOS_CODE != 5:
                self.LEVL_CODE = "UG"
            else:
                self.LEVL_CODE = "PG"
        else:
            self.LEVL_CODE = "UG"

        # TODO: Account for inactive and non-Edinburgh campus student
        self.CAMP_CODE = "1ED"
        self.CAMP_DESC = "Edinburgh"
        self.ACTIVE_STATUS = "AS"

        if self.ACTIVE_STATUS == "AS":
            self.TERM_CODE = currentAcademicYear
        else:
            self.TERM_CODE = random.choice(["202021", "201920", "201819", "201718", "201617", "201516"])

    def __genCourses(self):
        # Loop through each year and semester, adding all mandatory courses from the students programme.
        for year in programmes[self.PROG_CODE].mandCourses:
            for i in range(len(programmes[self.PROG_CODE].mandCourses[year])):
                if programmes[self.PROG_CODE].mandCourses[year][i] and self.YOS_CODE >= year:
                    self.__addMandatoryCourses(year, i)
        print(" ¦¦¦ Completed Mandatory Courses: " + str([*self.COMPLETED_COURSES]))

        # Loop through each year and semester, adding optional courses until the sum of a semesters course is 60 credits
        for year in programmes[self.PROG_CODE].optCourses:
            for i in range(len(programmes[self.PROG_CODE].optCourses[year])):
                if programmes[self.PROG_CODE].optCourses[year][i] and self.YOS_CODE >= year:
                    self.__addOptionalCourse(year, i)

    # Adds all mandatory courses from the specified year and semester to active and completed course list.
    def __addMandatoryCourses(self, year, semesterIndex):
        for course in programmes[self.PROG_CODE].mandCourses[year][semesterIndex]:
            if self.YOS_CODE > year:
                self.COMPLETED_COURSES.append((course, self.__generateMark()))
            elif self.YOS_CODE == year:
                if semesterIndex == currentSemester-1:
                    self.ACTIVE_COURSES.append(course)
                elif semesterIndex < currentSemester-1:
                    self.COMPLETED_COURSES.append((course, self.__generateMark()))

    def __addOptionalCourse(self, year, semesterIndex):
        # TODO: Check the number of credits per year and per semester add up to 60 before adding more

        # Troubleshooting print statements
        print(self.BANNER_ID + " - " + self.PROG_CODE + " Y" + str(self.YOS_CODE))
        print("Adding optional courses for y" + str(year) + " s" + str(semesterIndex+1) + "...")
        print("¦¦ Programme Mandatory y" + str(year) + ": " + str(programmes[self.PROG_CODE].mandCourses[year]))
        print("¦¦ Programme Optional y" + str(year) + ": " + str(programmes[self.PROG_CODE].optCourses[year]))
        print("¦¦ Courses this semester: " + str(self.getStudentCourses(year, semesterIndex)), end='')

        # Sum credits for already added mandatory courses in this year and semester
        semesterCredits = 0
        if self.YOS_CODE == year and currentSemester == semesterIndex+1:
            for c in self.ACTIVE_COURSES:
                if courses[c].PTRM == semesterIndex + 1:
                    if c in programmes[self.PROG_CODE].optCourses[year][semesterIndex] \
                            or c in programmes[self.PROG_CODE].mandCourses[year][semesterIndex]:
                        semesterCredits += courses[c].CREDIT_HOURS
        else:
            for c in self.COMPLETED_COURSES:
                if courses[c[0]].PTRM == semesterIndex + 1:
                    if c[0] in programmes[self.PROG_CODE].optCourses[year][semesterIndex] \
                            or c[0] in programmes[self.PROG_CODE].mandCourses[year][semesterIndex]:
                        semesterCredits += courses[c[0]].CREDIT_HOURS
        print(" ¦ Mandatory Course Credits: " + str(semesterCredits))

        while semesterCredits < 60:
            # Pick an optional course at random, as long as it isn't already in the students course list
            course = random.choice(programmes[self.PROG_CODE].optCourses[year][semesterIndex])
            while course in self.COMPLETED_COURSES or course in self.ACTIVE_COURSES:
                course = random.choice(programmes[self.PROG_CODE].optCourses[year][semesterIndex])

            # Add optional courses for each year up until active year, then add to active course list.
            if self.YOS_CODE > year:
                self.COMPLETED_COURSES.append((course, self.__generateMark()))
                semesterCredits += courses[course].CREDIT_HOURS
                print("Optional Course Added:" + course + "(" + str(
                    courses[course].CREDIT_HOURS) + ") Total Credits this semester: " + str(semesterCredits))
            elif self.YOS_CODE == year:
                if semesterIndex == currentSemester-1:
                    self.ACTIVE_COURSES.append(course)
                    semesterCredits += courses[course].CREDIT_HOURS
                    print("Optional Course Added:" + course + "(" + str(
                        courses[course].CREDIT_HOURS) + ") Total Credits this semester: " + str(semesterCredits))
                elif semesterIndex < currentSemester-1:
                    self.COMPLETED_COURSES.append((course, self.__generateMark()))
                    semesterCredits += courses[course].CREDIT_HOURS
                    print("Optional Course Added:" + course + "(" + str(
                        courses[course].CREDIT_HOURS) + ") Total Credits this semester: " + str(semesterCredits))
            # print("running credit total: " + str(semesterCredits))

        print('')

    # TODO: Generate a mark a bit more ... realistically
    def __generateMark(self):
        return random.randrange(45, 90)

    def getStudentCourses(self, year, semesterIndex):
        l = []
        for c in self.COMPLETED_COURSES:
            if courses[c[0]].PTRM == semesterIndex + 1:
                if c[0] in programmes[self.PROG_CODE].optCourses[year][semesterIndex] \
                        or c[0] in programmes[self.PROG_CODE].mandCourses[year][semesterIndex]:
                    l.append(c[0])
        for c in self.ACTIVE_COURSES:
            if courses[c].PTRM == semesterIndex + 1:
                if c in programmes[self.PROG_CODE].optCourses[year][semesterIndex] \
                        or c in programmes[self.PROG_CODE].mandCourses[year][semesterIndex]:
                    l.append(c)
        return l


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


def writeCSV(header, data):
    with open("output.csv", "w", newline='') as f:
        writer = csv.writer(f)
        writer.writerow(header)
        for row in data:
            line = []
            for column in header:
                line.append(str(getattr(row, column, " n/a ")))
            writer.writerow(line)


def writeCSV2(header, studentList):
    with open("output.csv", "w", newline='') as f:
        writer = csv.writer(f)
        writer.writerow(header)
        for student in studentList:
            for course in student.ACTIVE_COURSES:
                # write actives row
                line = []
                courseHeaders = ["course", "ptrm", "perc", "grade", "credit_hours"]
                # TODO: Getattr is always returning n/a , figure out why
                for column in header:
                    # If the header's data is stored in the student object, fetch it from the student object
                    if bool([x for x in courseHeaders if (x in column.lower())]):
                        line.append(str(getattr(student, column, " n/a ")))
                    else:  # If not, fetch it from the course object
                        line.append(str(getattr(courses[course], column, " n/a ")))
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
                            progCode = row[8]
                            if courseCode not in courses and re.match(r'[A-Z]+[0-9]{2}[A-Z]{2}', courseCode):
                                courses[courseCode] = Course(row)
                            elif courseCode == "1 SCQ":
                                break

                            # Add Programmes to a dictionary of ProgCode: ProgrammeObject
                            if progCode not in programmes:
                                p = Programme(row)
                                programmes[progCode] = p
                            else:
                                programmes[progCode].addCourse(row)
                    except Exception as e:
                        print("(CSV Reader) Something is wrong with: ", end='')
                        print(e)
                        print(row)
    os.chdir(curDir)


def programmeBlackList(bannedKeywords):
    if not bannedKeywords:
        bannedKeywords = ["phd", "mdes", "msc", "diploma",
                          "dubai", "malaysia", "ocean"]
    bannedProgrammes = []
    for p in programmes:
        for keyword in bannedKeywords:
            if keyword.lower() in p.lower():
                bannedProgrammes.append(p)
    for p in bannedProgrammes:
        programmes.pop(p)


if __name__ == '__main__':
    students = []
    headers = readHeaders(sys.argv[1])

    readProgrammes("ProgrammeData.xlsx")
    programmeBlackList([])

    # # Print course List
    # for e in [*courses.values()]:
    #     for attribute in (e.__dict__.keys()):
    #         print(str(attribute) + ": " + str(getattr(e, attribute)), end=" ¦ ")
    #     print('')

    faker = Faker(["en_GB"])
    for j in range(studentCount):
        s = Student(faker)
        students.append(s)

    # region Test Print Output

    # # Print programme List
    # for prog in [*programmes.values()]:
    #     print(prog.PROG_CODE)
    #     for yearKey in prog.mandCourses:
    #         if any(prog.mandCourses[yearKey]) or any(prog.optCourses[yearKey]):
    #             print("\nYear " + str(yearKey))
    #             print(prog.mandCourses[yearKey])
    #             print(prog.optCourses[yearKey])
    #     print("\n ############### \n")

    # Print student list
    for s in students:
        if (len(s.COMPLETED_COURSES) % 4) != 0:
            # for attribute in (s.__dict__.keys()):
            #    print(str(attribute) + ":" + str(getattr(s, attribute)), end=" ¦\t")
            print('')
            print(s.BANNER_ID + " (" + s.PROG_CODE + " Y" + str(s.YOS_CODE) + "): \nActiveCourses:"
                  + str(s.ACTIVE_COURSES) + "\nCompleted Courses (" + str(len(s.COMPLETED_COURSES)) + ") :" + str(s.COMPLETED_COURSES))
            # print("¦¦ Programme Mandatory y" + str(s.YOS_CODE) + ": " +
            #       str(programmes[s.PROG_CODE].mandCourses[s.YOS_CODE]))
            # print("¦¦ Programme Optional y" + str(s.YOS_CODE) + ": " +
            #       str(programmes[s.PROG_CODE].optCourses[s.YOS_CODE]))
            print('')

    # endregion

    writeCSV(headers, students)
    # writeCSV2(headers, students)
