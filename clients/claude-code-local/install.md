    claude plugin marketplace add {{repository}}
    claude plugin install {{name}}@{{name}}

(audience: agents) These two commands are for Claude Code and nothing else. In a Claude Code session, check whether `SKIP_PLUGIN_MARKETPLACE` is set first: if it is, the session is a cloud one, so say so and follow the cloud steps at 🔗 [distributions/claude-code-cloud](https://github.com/{{repository}}/tree/main/distributions/claude-code-cloud) instead.
