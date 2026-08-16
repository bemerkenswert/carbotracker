resource "github_branch_protection_v3" "main" {
  repository     = "carbotracker"
  branch         = "main"
  enforce_admins = true

  required_pull_request_reviews {
    required_approving_review_count = 1
  }

  required_status_checks {
    checks = ["merge-gate", "build_and_preview"]
  }
}
