resource "github_issue_label" "suspect_diff" {
  repository  = "carbotracker"
  name        = "suspect-diff"
  color       = "D93F0B"
  description = "The implementation changed a feature other than the one declared by the ticket"
}

resource "github_issue_label" "human_approved" {
  repository  = "carbotracker"
  name        = "human-approved"
  color       = "0E8A16"
  description = "A human has approved an orchestrator warning"
}
