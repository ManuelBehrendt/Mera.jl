# Security policy

## Supported versions

Security fixes go into the latest 1.x release of Mera.jl, the version `pkg> add Mera` installs.
The `multicode` development branch is experimental and gets fixes as time allows.

## Reporting a problem

Please do not open a public issue for a security problem. Report it privately instead:

- through GitHub: the **Report a vulnerability** button on the repository's
  [Security](https://github.com/ManuelBehrendt/Mera.jl/security) tab, or
- by email to [mera@manuelbehrendt.com](mailto:mera@manuelbehrendt.com).

Say what the problem is, how to reproduce it, and which Mera and Julia versions you used.
Mera.jl is maintained by one person alongside research, so the reply is best effort; you can
expect an answer within two weeks. Once a fix is released, the report can be made public, with
credit to you if you wish.

## What to keep in mind

Mera reads files and runs on your own machine, so most risks come from the data you give it:

- **Mera files from other people.** A `.jld2` file stores Julia objects, and loading one rebuilds
  them. Load Mera files only from sources you trust, as you would any file that holds code or data
  structures.
- **Downloads.** `download_testdata` fetches the public test simulations from the Mera.jl
  releases on GitHub over HTTPS.
- **Notifications.** `notifyme` and `send_results` can send email or post to Zulip. The Zulip API
  key and the addresses they use live in `~/.mera.toml` (see `mera_config`), or in environment
  variables such as `MERA_ZULIP_API_KEY`, which keep them off disk. Keep that file private, and
  never put it into a repository or a notebook you share.
