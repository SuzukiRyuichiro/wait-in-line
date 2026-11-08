#!/usr/bin/env bash
# PostToolUse hook: auto-correct Ruby files with RuboCop (inside Docker Compose)
# after Claude edits/writes them. Remaining offenses are fed back to Claude.
set -uo pipefail

file_path=$(jq -r '.tool_input.file_path // empty')
[ -z "$file_path" ] && exit 0

case "$file_path" in
  *.rb | *.rake | *.ru | *.gemspec | *.jbuilder | */Gemfile | */Rakefile) ;;
  *) exit 0 ;;
esac

project_dir="${CLAUDE_PROJECT_DIR:-$(pwd)}"
case "$file_path" in
  "$project_dir"/*) rel_path="${file_path#"$project_dir"/}" ;;
  *) exit 0 ;; # outside the project (not mounted into the container)
esac
[ -f "$project_dir/$rel_path" ] || exit 0

cd "$project_dir" || exit 0

rubocop=(bundle exec rubocop --autocorrect --force-exclusion --format simple "$rel_path")

# Reuse the running web container if there is one; otherwise spin up a
# throwaway one (skip deps like mongo, and skip the entrypoint's server setup).
if [ -n "$(docker compose ps --status running -q web 2>/dev/null)" ]; then
  output=$(docker compose exec -T web "${rubocop[@]}" 2>&1)
else
  output=$(docker compose run --rm --no-deps -T --entrypoint bundle web "${rubocop[@]:1}" 2>&1)
fi
status=$?

if [ $status -ne 0 ]; then
  echo "RuboCop found offenses it could not auto-correct in $rel_path:" >&2
  echo "$output" >&2
  exit 2
fi
exit 0
