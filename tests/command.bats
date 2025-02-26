#!/usr/bin/env bats

load '/usr/local/lib/bats/load.bash'

setup() {
  export BUILDKITE_PLUGIN_MONOREPO_DIFF_BUILDKITE_PLUGIN_TEST_MODE="true"

  stub buildkite-agent pipeline upload
}

@test "Notify when the plugin cannot be parsed" {

  run $PWD/hooks/command

  assert_failure
  assert_output --partial "failed to parse plugin configuration"
}

@test "Pipeline is generated without wait property" {
  DIFF_CMD="echo foo-service/"
  LOG_LEVEL="debug"

  export BUILDKITE_PLUGINS='[{
    "github.com/rajatvig/monorepo-diff-buildkite-plugin": {
      "diff":"echo foo-service/",
      "log_level": "debug",
      "watch": [
        {
          "path":"foo-service/",
          "config": {
            "trigger":"foo-service"
          }
        },
        {
          "path":"bar-service/",
          "config": {
            "trigger":"foo-service"
          }
        }
      ]
    }
  }]'

  run $PWD/hooks/command

  assert_success

  refute_output --partial "- wait"

  assert_output --partial << EOM
steps:
- trigger: foo-service
EOM
}

@test "Pipeline is generated with notifications" {
  export BUILDKITE_BRANCH="go-rewrite"
  export BUILDKITE_MESSAGE="some message"
  export BUILDKITE_COMMIT="commit-hash"

  export BUILDKITE_PLUGINS='[{
    "github.com/rajatvig/monorepo-diff-buildkite-plugin": {
      "diff":"echo foo-service/ \nuser-service",
      "log_level": "debug",
      "notify": [
        { "email": "foo@gmail.com" },
        { "basecamp_campfire": "https://basecamp-url" },
        { "github_commit_status": { "context" : "my-custom-status" } },
        { "pagerduty_change_event": "pagerduty-event" },
        { "slack": "@someuser" },
        { "webhook": "https://webhook-url" }
      ],
      "watch": [
        {
          "path":"foo-service/",
          "config": {
            "trigger":"foo-service",
            "notify": [
              { "basecamp_campfire": "https://basecamp-url" },
              { "github_commit_status": { "context" : "my-custom-status" } },
              { "slack": "@someuser", "if": "build.state === \"passed\"" }
            ]
          }
        },
        {
          "path": "user-service",
          "config": {
            "command": "echo foo"
          }
        }
      ]
    }
  }]'

  run $PWD/hooks/command

  assert_success

  assert_output --partial << EOM
notify:
- email: foo@gmail.com
- basecamp_campfire: https://basecamp-url
- github_commit_status:
    context: my-custom-status
- pagerduty_change_event: pagerduty-event
- slack: '@someuser'
- webhook: https://webhook-url
steps:
- trigger: foo-service
  build:
    message: some message
    branch: go-rewrite
    commit: commit-hash
  notify:
  - basecamp_campfire: https://basecamp-url
  - github_commit_status:
      context: my-custom-status
  - slack: '@someuser'
    if: build.state === "passed"
- command: echo foo
EOM
}

@test "Pipeline is generated with build config from env" {
  export BUILDKITE_BRANCH="go-rewrite"
  export BUILDKITE_MESSAGE="some message"
  export BUILDKITE_COMMIT="commit-hash"

  export BUILDKITE_PLUGINS='[{
    "github.com/rajatvig/monorepo-diff-buildkite-plugin": {
      "diff":"echo foo-service/",
      "log_level": "debug",
      "watch": [
        {
          "path":"foo-service/",
          "config": {
            "trigger":"foo-service"
          }
        }
      ]
    }
  }]'

  run $PWD/hooks/command

  assert_success

  assert_output --partial << EOM
steps:
- trigger: foo-service
  build:
    message: some message
    branch: go-rewrite
    commit: commit-hash
EOM
}

@test "Pipeline is generated with all options" {
  export BUILDKITE_BRANCH="branch from env"
  export BUILDKITE_MESSAGE="message from env"
  export BUILDKITE_COMMIT="commit from env"

  export BUILDKITE_PLUGINS='[
  {
    "github.com/rajatvig/monorepo-diff-buildkite-plugin": {
      "diff": "echo foo-service/ \nbat-service/",
      "log_level": "debug",
      "wait": true,
      "hooks": [
        { "command": "echo \"hello world\"" },
        { "command": "cat ./foo-file.txt" }
      ],
      "watch": [
        {
          "path": "foo-service/",
          "config": {
            "trigger": "foo-service-pipeline",
            "label": "foo service pipeline",
            "notify": [
              { "slack": "@adikari" }
            ],
            "build": {
              "message": "some-message",
              "commit": "commit-hash",
              "branch": "go-rewrite"
            },
            "async": true,
            "agents": {
              "queue": "foo-service-queue"
            },
            "artifacts": [
              "coverage/**/*",
              "tests/*"
            ]
          }
        },
        {
          "path": "bar-service/",
          "config": {
            "trigger": "bar-service-pipeline"
          }
        },
        {
          "path": [
            "bat-service/",
            "non-existant-service"
          ],
          "config": {
            "group": "my group",
            "command": "echo \"hello group\""
          }
        },
        {
          "path": [
            "bat-service/",
            "non-existant-service"
          ],
          "config": {
            "command": "echo \"i can fail\" && exit -1",
            "soft_fail": true
          }
        },
        {
          "path": [
            "bat-service/",
            "non-existant-service"
          ],
          "config": {
            "command": "echo \"i can fail\" && exit 1",
            "soft_fail": [{ "exit_status": 1 }, { "exit_status": "255" }]
          }
        },
        {
          "path": "**/*.md",
          "config": {
            "trigger": "markdown-pipeline"
          }
        },

        {
          "path": "bat-service/",
          "config": {
            "command": ["echo one", "echo two"]
          }
        }
      ]
    }
  },
  {
    "some-another-plugin": {
      "some-config": "some-config"
    }
  }
]'

  run $PWD/hooks/command

  assert_success

  assert_output --partial "--- running monorepo-diff"
  assert_output --partial "Running diff command: echo foo-service/ \nbat-service/"
  assert_output --partial "Output from diff: \nfoo-service/ \nbat-service/"

  assert_output --partial << EOM
steps:
- trigger: foo-service-pipeline
  label: foo service pipeline
  build:
    message: some-message
    branch: go-rewrite
    commit: commit-hash
  agents:
    queue: foo-service-queue
  artifacts:
  - coverage/**/*
  - tests/*
  async: true
  notify:
  - slack: '@adikari'
- group: my group
  steps:
  - command: echo "hello group"
- command: echo "i can fail" && exit -1
  soft_fail: true
- command: echo "i can fail" && exit 1
  soft_fail:
  - exit_status: 1
  - exit_status: "255"
- command:
  - echo one
  - echo two
- wait: null
- command: echo "hello world"
- command: cat ./foo-file.txt
EOM
}
