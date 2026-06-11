# Email Comments Troubleshooting

## AUTHENTICATE failed

`AUTHENTICATE failed` happens before the script can read any email. The most likely cause is Microsoft account authentication, not the comment parser.

Check these items in order:

1. GitHub repository -> Settings -> Secrets and variables -> Actions.
2. Confirm `BLOG_EMAIL` is the full mailbox address, for example `name@hotmail.com`.
3. Confirm `BLOG_EMAIL_PASSWORD` is a Microsoft app password, not the normal web login password.
4. If the app password was shown with spaces, either paste it exactly or remove spaces. The script removes spaces automatically, but hidden characters still matter.
5. In the Microsoft account security page, two-step verification must be on before app passwords are available.
6. Create a fresh app password, update `BLOG_EMAIL_PASSWORD`, then run `Fetch Email Comments` manually.
7. If login still fails, open Outlook web once to confirm the mailbox is not locked by a security challenge.

Default IMAP settings used by the workflow:

- Server: `outlook.office365.com`
- Port: `993`
- SSL: on

Optional repository secrets:

- `BLOG_IMAP_SERVER`
- `BLOG_IMAP_PORT`
- `BLOG_COMMENTS_BOOTSTRAP_SINCE`, for example `01-Jan-2026`

## Local Comments

Comments are fetched by GitHub Actions and committed back into the repository. Before checking comments locally with `npx hexo server`, run:

```bash
git pull --ff-only origin main
npx hexo server
```

That pull brings down the latest `source/data/comments.json` and `.github/comments_state.json`.
