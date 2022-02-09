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
studentCount = 10
currentAcademicYear = 202122

# region Programmes and Courses
courses = {}
programmes = {}

# endregion

# Keep track of generated ID's to ensure uniqueness
uniqueHWIDs = []
uniqueUserIDs = []

# endregion


class Programme:
    PROG_DESC = ""
    PROG_CODE = ""

    mandCourses = {
        1: [[], [], []],
        2: [[], [], []],
        3: [[], [], []],
        4: [[], [], []],
        5: [[], [], []]
    }
    optCourses = {
        1: [[], [], []],
        2: [[], [], []],
        3: [[], [], []],
        4: [[], [], []],
        5: [[], [], []]
    }
    optCount = {
        1: [0, 0, 0],
        2: [0, 0, 0],
        3: [0, 0, 0],
        4: [0, 0, 0]
    }

    def __init__(self, row):
        try:
            self.COURSE_DESC = row[8].strip()
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
            year = int(row[5][0])
            semester = int(row[4][0]) - 1
            if "mandatory" in row[3].lower():
                self.mandCourses[year][semester].append(self.PROG_CODE)
            else:
                self.optCourses[year][semester].append(self.PROG_CODE)
        except Exception as e:
            print(row)
            print(e)


class Course:
    COURSE_CODE = COURSE_TITLE = ""
    PTRM = CREDIT_HOURS = 0

    def __init__(self, row):
        try:
            self.COURSE_CODE = row[1].strip()
            # TODO: Fix regex sanitization to remove parenthesis and asterix
            self.COURSE_TITLE = re.sub("[([].*?[)]]", "", row[2]).strip()
            self.PTRM = int(row[4][0])
        except Exception as e:
            print(e)
            print("/nSomething is wrong with line: /n" + row)


class Student:
    # Class Parameter Declarations
    BANNER_ID = TITLE = FIRST_NAME = MIDDLE_NAME = LAST_NAME = USERNAME = ""
    ACTIVE_STATUS = PROG_CODE = PROG_DESC = LEVL_CODE = CAMP_CODE = TERM_CODE = YOS_DESC = ""
    YOS_CODE = "4"

    # LEVL_CODE = "UG" #  Student or Programme?
    ESTS_CODE = "EN"  # Language?
    CAMP_DESC = "Edinburgh"  # Needed?

    def __init__(self, f):
        # region Personal Information Generation
        self.BANNER_ID = genHWUid()
        self.TITLE = random.choices(["Mr", "Ms", "Mrs"], weights=[70, 25, 5])[0]
        if self.TITLE == "Mr":
            self.FIRST_NAME = f.first_name_male()
            if random.randint(1, 10) < 5:
                self.MIDDLE_NAME = f.first_name_male()
        else:
            self.FIRST_NAME = f.first_name_female()
            if random.randint(1, 10) < 5:
                self.MIDDLE_NAME = f.first_name_female()
        self.LAST_NAME = f.last_name()

        if not self.MIDDLE_NAME:
            userInitials = self.FIRST_NAME[0].lower() + self.LAST_NAME[0].lower()
        else:
            userInitials = self.FIRST_NAME[0].lower() + self.MIDDLE_NAME[0].lower() + self.LAST_NAME[0].lower()
        self.USERNAME = genUsername(userInitials)
        # endregion

        # region Course Information Generation
        self.PROG_CODE = random.choice(list(programmes.keys()))
        self.PROG_DESC = programmes[self.PROG_CODE].PROG_DESC

        if ("MSc" in self.PROG_DESC or "PhD" in self.PROG_DESC) and int(self.YOS_CODE) > 4:
            self.LEVL_CODE = "PG"
        else:
            self.LEVL_CODE = "UG"

        # TODO: Account for inactive and non-Edinburgh campus students
        self.CAMP_CODE = "1ED"
        self.CAMP_DESC = "Edinburgh"
        self.ACTIVE_STATUS = "AS"

        if self.ACTIVE_STATUS == "AS":
            self.TERM_CODE = currentAcademicYear
        else:
            self.TERM_CODE = random.choice(["202021", "201920", "201819", "201718", "201617", "201516"])
        # endregion


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
# endregion


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
                    if row[0] != "":
                        # Add courses to a dictionary of CourseCode: CourseObject
                        if row[1] not in courses and re.match(r'[A-Z]+[0-9]{2}[A-Z]{2}', row[1]):
                            courses[row[1]] = Course(row)
                        # Add Programmes to a dictionary of ProgCode: ProgrammeObject
                        if row[8] not in programmes:
                            p = Programme(row)
                            programmes[row[8]] = p
                        else:
                            programmes[row[8]].addCourse(row)
    os.chdir(curDir)


if __name__ == '__main__':
    students = []
    headers = readHeaders(sys.argv[1])
    # Also reads courses from it
    readProgrammes("ProgrammeData.xlsx")

    faker = Faker(["en_GB"])
    for i in range(studentCount):
        s = Student(faker)
        students.append(s)

    # for c in courses:
    # print(courses[c].COURSE_CODE + " " + courses[c].COURSE_TITLE)
    # for p in programmes:
    #    print(p)

    writeCSV(headers, students)
