# GitHub Provider configuration

terraform {
  required_providers {
    github = {
      source  = "integrations/github"
      version = "~> 6.0"
    }
  }
}

provider "github" {
  token = var.github_token
  owner = var.github_owner
}

# Import existing repository
resource "github_repository" "lab_repo" {
  name        = var.repo_name
  description = "DevOps Labs - Infrastructure as Code, CI/CD, Configuration Management"
  
  visibility = "public"  # or "private"
  
  has_issues    = true
  has_projects  = true
  has_wiki      = true
  has_downloads = true
  
  allow_merge_commit     = true
  allow_squash_merge     = true
  allow_rebase_merge     = true
  delete_branch_on_merge = true
  
  topics = [
    "devops",
    "terraform",
    "pulumi",
    "ansible",
    "docker",
    "cicd",
    "infrastructure-as-code",
  ]
}