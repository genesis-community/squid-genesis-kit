This release modernizes the Squid kit to work well with Genesis 2.6
features and functionalities.  Primarily, this involves a heavier
emphasis on kit-provided hooks to do heavy lifting.

- Genesis 2.6.0 is the minimum version supported by this kit now.

- The `info` hook provides information about accessing the deployed
  proxy, including the environment variables that need set.

- Exodus data is now provided, for integration with other deployments.

- The `new` and `blueprint` hooks replace a lot of stuff that was in
  kit.yml (params and friends), while removing the complexity of the
  subkit decomposition.

- The `addon` hook provides for kit-specific functionality like
  testing the proxy for through connectivity.

- The `post-deploy` hook gives the operator a gentle nudge in the
  direction of _next steps_.
