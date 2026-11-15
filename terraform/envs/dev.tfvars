region      = "us-east-1"
project     = "rag-platform"
environment = "dev"

# Your GitHub user/org and the app repo name.
# github_org is passed by the pipeline (TF_VAR_github_org), so it is not set here.
app_repo = "rag-app"

# Numeric IDs used in GitHub's OIDC subject (repo:<owner>@<owner id>/<repo>@<repo id>:...).
# Find the app repo id with:
#   curl -s https://api.github.com/repos/naveenks720/rag-app | grep -m1 '"id"'
# The first "id" printed is the repository id.
github_owner_id = "25269118"
app_repo_id     = "1457103571"
