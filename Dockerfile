FROM node:20-alpine
LABEL "repository"="https://github.com/naga1090/github-bump-tag-action"
LABEL "homepage"="https://github.com/naga1090/github-bump-tag-action"
LABEL "maintainer"="Naga Nannapuneni"

RUN apk --no-cache add bash git git-lfs curl jq && npm install -g semver

COPY entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
