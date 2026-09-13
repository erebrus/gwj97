import godot_git
from godot_version import get_project_version

if __name__ == '__main__':

    new_version = get_project_version()
    
    if str(new_version) not in godot_git.get_tags():
        godot_git.tag_new_version(str(new_version))
        print(f'Latest tag:{godot_git.get_latest_tag()}')