import git

repo_path = '../../../'

def get_latest_tag()->git.TagReference:
    repo = git.Repo(repo_path)
    tags = sorted(repo.tags, key=lambda t: t.commit.committed_datetime)
    latest_tag = tags[-1]    
    return latest_tag

def get_tags()->[]:
    repo = git.Repo(repo_path)
    return [tag.name for tag in repo.tags]

def tag_new_version(v):
    print(f'tagging {v}')
    repo = git.Repo(repo_path)
    new_tag = repo.create_tag(v, message='Automatic tag "{0}"'.format(v)) 
    print(f'tagged:{new_tag.name}')
    if repo.remotes:
       repo.remotes.origin.push(new_tag)
    else:
       print("No origin to push to. Tag created locally only.")
