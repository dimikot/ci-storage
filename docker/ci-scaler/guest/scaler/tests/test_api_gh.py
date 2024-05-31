from api_gh import (
    gh_fetch_rate_limits,
    gh_fetch_runners,
    gh_fetch_workflow,
    gh_get_webhook_secret,
    gh_predict_workflow_labels,
    gh_runner_ensure_absent,
    gh_webhook_ensure_absent,
    gh_webhook_ping,
    gh,
)
from unittest import TestCase


class Test(TestCase):
    @classmethod
    def setUpClass(cls):
        cls.repository = gh(
            "repo",
            "view",
            "--json",
            "owner,name",
            "--jq",
            r'.owner.login + "/" + .name',
        ).strip()

    def test_gh_fetch_runners(self):
        res = gh_fetch_runners(repository=self.repository)
        self.assertIsInstance(res, list)

    def test_gh_runner_ensure_absent(self):
        gh_runner_ensure_absent(repository=self.repository, runner_id="42")

    def test_gh_get_webhook_secret(self):
        self.assertIsNotNone(gh_get_webhook_secret())

    def test_gh_webhook_ensure_exists(self):
        pass

    def test_gh_webhook_ping(self):
        gh_webhook_ping(repository=self.repository, url="https://example.com")

    def test_gh_webhook_ensure_absent(self):
        gh_webhook_ensure_absent(repository=self.repository, url="https://example.com")

    def test_gh_fetch_workflow(self):
        workflow = gh_fetch_workflow(
            repository=self.repository,
            sha="main",
            path=".github/workflows/ci.yml",
        )
        self.assertIsInstance(workflow, dict)
        self.assertIn("jobs", workflow)

    def test_gh_fetch_rate_limits(self):
        rate_limits = gh_fetch_rate_limits()
        self.assertGreater(rate_limits.limit, 0)
        self.assertGreater(rate_limits.remaining, 0)

    def test_gh_predict_workflow_labels(self):
        self.assertEqual(
            gh_predict_workflow_labels(
                workflow={
                    "jobs": {
                        "job1": {"runs-on": "lab1"},
                        "job2": {"runs-on": "lab2"},
                        "job3": {"runs-on": "lab2"},
                        "job4": {
                            "runs-on": ["lab4"],
                            "strategy": {
                                "max-parallel": 2,
                                "matrix": {
                                    "my": [1, 2, 3],
                                },
                            },
                        },
                        "job5": {
                            "runs-on": ["lab5"],
                            "strategy": {
                                "matrix": {
                                    "my": [1, 2, 3, 4],
                                },
                            },
                        },
                    }
                }
            ),
            {"lab1": 1, "lab2": 2, "lab4": 2, "lab5": 4},
        )
