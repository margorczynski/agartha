"""
dlt source for GitHub API data ingestion.

This module demonstrates a non-trivial dlt source that:
- Fetches data from a REST API with pagination
- Handles nested/complex data structures
- Supports incremental loading
- Includes multiple related resources
"""

from typing import Iterator

import dlt
from dlt.sources.helpers.rest_client import RESTClient
from dlt.sources.helpers.rest_client.paginators import HeaderLinkPaginator


BASE_URL = "https://api.github.com"


def _get_client(access_token: str | None = None) -> RESTClient:
    """Create a REST client for GitHub API with optional authentication."""
    headers = {
        "Accept": "application/vnd.github+json",
        "X-GitHub-Api-Version": "2022-11-28",
    }
    if access_token:
        headers["Authorization"] = f"Bearer {access_token}"

    return RESTClient(
        base_url=BASE_URL,
        headers=headers,
        paginator=HeaderLinkPaginator(),
    )


@dlt.source(name="github")
def github_source(
    organization: str,
    access_token: str | None = dlt.secrets.value,
    max_repos: int = 100,
):
    """
    A dlt source that extracts data from GitHub's REST API.

    Args:
        organization: GitHub organization name to fetch data from
        access_token: Optional GitHub personal access token for higher rate limits
        max_repos: Maximum number of repositories to fetch (default 100)

    Yields:
        dlt resources for repositories, contributors, issues, and pull requests
    """
    client = _get_client(access_token)

    @dlt.resource(
        name="repositories",
        write_disposition="replace",
        primary_key="id",
    )
    def repositories() -> Iterator[dict]:
        """Fetch all public repositories for the organization."""
        count = 0
        for page in client.paginate(
            f"/orgs/{organization}/repos",
            params={"type": "public", "sort": "updated", "per_page": 100},
        ):
            for repo in page:
                if count >= max_repos:
                    return
                yield {
                    "id": repo["id"],
                    "name": repo["name"],
                    "full_name": repo["full_name"],
                    "description": repo["description"],
                    "html_url": repo["html_url"],
                    "language": repo["language"],
                    "stargazers_count": repo["stargazers_count"],
                    "watchers_count": repo["watchers_count"],
                    "forks_count": repo["forks_count"],
                    "open_issues_count": repo["open_issues_count"],
                    "created_at": repo["created_at"],
                    "updated_at": repo["updated_at"],
                    "pushed_at": repo["pushed_at"],
                    "default_branch": repo["default_branch"],
                    "archived": repo["archived"],
                    "topics": repo.get("topics", []),
                    "license_name": repo.get("license", {}).get("name") if repo.get("license") else None,
                }
                count += 1

    @dlt.resource(
        name="contributors",
        write_disposition="replace",
        primary_key=["repo_name", "contributor_id"],
    )
    def contributors() -> Iterator[dict]:
        """Fetch contributors for each repository."""
        count = 0
        for page in client.paginate(
            f"/orgs/{organization}/repos",
            params={"type": "public", "sort": "updated", "per_page": 100},
        ):
            for repo in page:
                if count >= max_repos:
                    return
                repo_name = repo["name"]
                try:
                    for contrib_page in client.paginate(
                        f"/repos/{organization}/{repo_name}/contributors",
                        params={"per_page": 100, "anon": "false"},
                    ):
                        for contributor in contrib_page:
                            yield {
                                "repo_name": repo_name,
                                "contributor_id": contributor["id"],
                                "login": contributor["login"],
                                "avatar_url": contributor["avatar_url"],
                                "contributions": contributor["contributions"],
                                "type": contributor["type"],
                            }
                except Exception:
                    # Skip repos where we can't fetch contributors (empty repos, etc.)
                    pass
                count += 1

    @dlt.resource(
        name="issues",
        write_disposition="merge",
        primary_key="id",
    )
    def issues(
        updated_at: dlt.sources.incremental[str] = dlt.sources.incremental(
            "updated_at", initial_value="2020-01-01T00:00:00Z"
        ),
    ) -> Iterator[dict]:
        """
        Fetch issues for repositories with incremental loading.

        Uses the updated_at field for incremental sync - only fetches
        issues updated since the last run.
        """
        count = 0
        for page in client.paginate(
            f"/orgs/{organization}/repos",
            params={"type": "public", "sort": "updated", "per_page": 100},
        ):
            for repo in page:
                if count >= max_repos:
                    return
                repo_name = repo["name"]
                try:
                    for issue_page in client.paginate(
                        f"/repos/{organization}/{repo_name}/issues",
                        params={
                            "state": "all",
                            "sort": "updated",
                            "direction": "asc",
                            "since": updated_at.last_value,
                            "per_page": 100,
                        },
                    ):
                        for issue in issue_page:
                            # Skip pull requests (they appear in issues endpoint too)
                            if "pull_request" in issue:
                                continue
                            yield {
                                "id": issue["id"],
                                "repo_name": repo_name,
                                "number": issue["number"],
                                "title": issue["title"],
                                "state": issue["state"],
                                "user_login": issue["user"]["login"] if issue.get("user") else None,
                                "labels": [label["name"] for label in issue.get("labels", [])],
                                "assignees": [a["login"] for a in issue.get("assignees", [])],
                                "comments": issue["comments"],
                                "created_at": issue["created_at"],
                                "updated_at": issue["updated_at"],
                                "closed_at": issue.get("closed_at"),
                            }
                except Exception:
                    pass
                count += 1

    @dlt.resource(
        name="pull_requests",
        write_disposition="merge",
        primary_key="id",
    )
    def pull_requests(
        updated_at: dlt.sources.incremental[str] = dlt.sources.incremental(
            "updated_at", initial_value="2020-01-01T00:00:00Z"
        ),
    ) -> Iterator[dict]:
        """
        Fetch pull requests for repositories with incremental loading.
        """
        count = 0
        for page in client.paginate(
            f"/orgs/{organization}/repos",
            params={"type": "public", "sort": "updated", "per_page": 100},
        ):
            for repo in page:
                if count >= max_repos:
                    return
                repo_name = repo["name"]
                try:
                    for pr_page in client.paginate(
                        f"/repos/{organization}/{repo_name}/pulls",
                        params={
                            "state": "all",
                            "sort": "updated",
                            "direction": "asc",
                            "per_page": 100,
                        },
                    ):
                        for pr in pr_page:
                            # Filter by updated_at for incremental
                            if pr["updated_at"] < updated_at.last_value:
                                continue
                            yield {
                                "id": pr["id"],
                                "repo_name": repo_name,
                                "number": pr["number"],
                                "title": pr["title"],
                                "state": pr["state"],
                                "user_login": pr["user"]["login"] if pr.get("user") else None,
                                "draft": pr.get("draft", False),
                                "merged_at": pr.get("merged_at"),
                                "created_at": pr["created_at"],
                                "updated_at": pr["updated_at"],
                                "closed_at": pr.get("closed_at"),
                                "head_ref": pr["head"]["ref"],
                                "base_ref": pr["base"]["ref"],
                            }
                except Exception:
                    pass
                count += 1

    return [repositories, contributors, issues, pull_requests]
