import os
import re
import fileinput

project_path:str = '../../../godot/'

class GameVersion:
    major:int
    minor:int
    revision:int

    def __init__(self, major:int, minor:int, revision:int) -> None:
        self.major = major
        self.minor = minor
        self.revision = revision

    def __str__(self) -> str:
        return f'{self.major}.{self.minor}.{self.revision}'

    def bump_major(self):
        self.major+=1
        self.minor=0
        self.revision=0
    def bump_minor(self):
        self.minor+=1
        self.revision=0

    def bump_revision(self):
        self.revision += 1

def create_version_from_str(string_version:str)->GameVersion:
        m = re.match('([0-9]+).([0-9]+).([0-9]+)', string_version)
        if m:
            return GameVersion(int(m.group(1)),int(m.group(2)),int(m.group(3)))
        else:
            raise Exception(f"Invalid version {string_version}")
        
def get_project_fname()->str:
    return os.path.join(project_path,'project.godot')

def get_project_version()->GameVersion:

    with open(get_project_fname()) as fp:
        # read all lines in a list
        for line in fp.readlines():
            # check if string present on a current line
            m = re.match('config/version="(.*)"', line)
            if m:
                return create_version_from_str(m.group(1))
    raise Exception(f"Could not find version in {get_project_fname()}")

def update_version(version:GameVersion)->None:
    
    for line in fileinput.input(get_project_fname(), inplace=True):
        m = re.match('config/version', line)
        if m:
            print(f'config/version="{version}"')
        else:
            print('{}'.format(line), end='') 

def bump_major():
    v = get_project_version()
    v.bump_major()
    update_version(v)


def bump_minor():
    v = get_project_version()
    v.bump_minor()
    update_version(v)


def bump_revision():
    v = get_project_version()
    v.bump_revision()
    update_version(v)


if __name__ == '__main__':
    print(get_project_version())
