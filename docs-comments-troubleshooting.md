# Email Comments Setup

## Gmail settings

The comment workflow now reads comments from Gmail through IMAP.

GitHub repository secrets:

- `BLOG_EMAIL`: `dwinnie137@gmail.com`
- `BLOG_EMAIL_PASSWORD`: a Google app password for `dwinnie137@gmail.com`, not the normal Gmail login password

Workflow IMAP settings:

- Server: `imap.gmail.com`
- Port: `993`
- SSL: on

Useful links:

- GitHub Actions secrets: <https://github.com/Laurentdiao/laurentdiao.github.io/settings/secrets/actions>
- New GitHub secret: <https://github.com/Laurentdiao/laurentdiao.github.io/settings/secrets/actions/new>
- Google account security: <https://myaccount.google.com/security>
- Google app passwords: <https://myaccount.google.com/apppasswords>
- Gmail forwarding and IMAP settings: <https://mail.google.com/mail/u/0/#settings/fwdandpop>
- Gmail IMAP official help: <https://support.google.com/mail/answer/7126229>

## What to check

1. Sign in to the Google account `dwinnie137@gmail.com`.
2. Open Google account security and turn on 2-Step Verification.
3. Open Google app passwords and create a new app password for Mail.
4. Copy the generated 16-character app password.
5. In GitHub Actions secrets, set `BLOG_EMAIL` to `dwinnie137@gmail.com`.
6. Set `BLOG_EMAIL_PASSWORD` to the Google app password.
7. In Gmail settings, open Forwarding and POP/IMAP and make sure IMAP is enabled.
8. Run the `Fetch Email Comments` workflow manually.

The script removes ordinary spaces, newlines, and hidden separators from the app password before logging in. If Google shows the password grouped like `abcd efgh ijkl mnop`, pasting it with spaces is okay.

## Workflow diagnostics

When the workflow starts, it prints safe diagnostics:

- `BLOG_EMAIL` is masked but should end with `@gmail.com`.
- `BLOG_EMAIL_PASSWORD length after cleanup` should usually be `16`.
- If the password length is `0`, the repository secret was not passed to the workflow.
- If the password length is much longer than `16`, it is probably not the Google app password.
- If the diagnostics look correct but `AUTHENTICATE failed` still appears, create a fresh Google app password and confirm IMAP is enabled in Gmail settings.

## Local comments

Comments are fetched by GitHub Actions and committed back into the repository. Before checking comments locally with `npx hexo server`, run:

```bash
git pull --ff-only origin main
npx hexo server
```

Or double-click `tools/review.command`; it pulls latest comments and opens the local preview after Hexo is ready.
