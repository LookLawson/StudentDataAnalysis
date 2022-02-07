# Import packages
import csv
import sys
import string
import random
import os
import re
from faker import Faker
from pathlib import Path

from collections import OrderedDict

# region Variables
studentCount = 5
currentAcademicYear = 202122

# region Programmes and Courses
sem1Courses, sem2Courses, sem3Courses = {}, {}, {}
progCodes = ["F291-COS"]
programmes = { "F291-COS": "BSc Computer Science"}

# endregion

# Keep track of generated ID's to ensure uniqueness
uniqueHWIDs = []
uniqueUserIDs = []

# endregion


# TODO: Restructure to account for possible existence of optional courses
class Programme:
    PROG_DESC = ""
    PROG_CODE = ""

    mandCourses = {
        "y1": [],
        "y2": [],
        "y3": [],
        "y4": []
    }
    optCourses = {
        "y1": [],
        "y2": [],
        "y3": [],
        "y4": []
    }


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
        self.PROG_CODE = random.choice(progCodes)
        self.PROG_DESC = programmes[self.PROG_CODE]

        if ("MSc" in self.PROG_DESC or "PhD" in self.PROG_DESC) and int(self.YOS_CODE) > 4:
            self.LEVL_CODE = "PG"
        else:
            self.LEVL_CODE = "UG"

        # TODO: Account for inactive and non-Edinburgh campus students
        self.CAMP_CODE = "Edinburgh"
        self.ACTIVE_STATUS = "AS"

        if self.ACTIVE_STATUS == "AS":
            self.TERM_CODE = currentAcademicYear
        else:
            self.TERM_CODE = random.choice(["202021", "201920", "201819", "201718", "201617", "201516"])
        # endregion


def pickClasses(course: string, yearOfStudy: int):
    if course == "BSc Computer Science":
        return []
    elif course == "BSc Information Systems":
        return []
    elif course == "MSc Software Engineering":
        return []
    return []


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
    with open("output.txt", "w", newline='') as f:
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
                        courseName = line[10:-1]
                        if courseSemester == 1:
                            sem1Courses[courseCode] = courseName
                        elif courseSemester == 2:
                            sem2Courses[courseCode] = courseName
                        elif courseSemester == 3:
                            sem3Courses[courseCode] = courseName
                    elif line.startswith("Semester "):
                        courseSemester = int(line[-2:])
    os.chdir(directory)


# TODO: Fix.
def readProgrammeList(folderPath: string):
    programmeYear = 1
    directory = os.getcwd()
    os.chdir(folderPath)
    for file in os.listdir():
        if file.endswith(".txt"):
            p = Programme()
            file_path = Path(file)
            with open(file_path, 'r') as f:
                for line in f.readlines():

                    match = re.findall(r'\s[A-Z]+[0-9]{2}[A-Z]{2}\s', line)
                    if match is not []:
                        return
                    elif line.startswith("Year ") and len(line) == 7:
                        programmeYear = int(line[-2:-1])
                    elif line.startswith("Programme Code: "):
                        p.PROG_CODE = line[-9:-1]
    os.chdir(directory)
    return []


# endregion


if __name__ == '__main__':
    students = []
    headers = readHeaders(sys.argv[1])
    readCourseList("courses")

    # Create Student Objects and store them in a list

    faker = Faker(["en_GB"])
    for i in range(studentCount):
        s = Student(faker)
        students.append(s)
    # for student in students:
    #     print(student.__dict__)

    writeCSV(headers, students)
