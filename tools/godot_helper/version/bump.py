import godot_git
from godot_version import bump_major, bump_minor, bump_revision,get_project_version
import sys

if __name__ == '__main__':

    
    old_version = get_project_version()
    if len(sys.argv)>1:
        if sys.argv[1] == 'major':
            bump_major()
        elif sys.argv[1] == 'minor':
            bump_minor()
        elif sys.argv[1] == 'revision':
            bump_revision()
        else:
            print("Usage: bump.py major|minor|revision")
    else:
        bump_revision()

    new_version = get_project_version()
    print(f'{old_version} -> {new_version}')
