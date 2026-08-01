# Sourced by every tests/api-design/*.sh file before invoking a gate.sh.
# Resolves CLAUDE_PLUGIN_ROOT_CORE for the test run: honors an already-set
# value (a real marketplace/CI checkout), otherwise shallow-clones
# tokenmaxxxer-core into a reusable cache under $TMPDIR so gate.sh's own
# "${CLAUDE_PLUGIN_ROOT_CORE:-...}" sourcing has something real to find —
# this is a test-run-time fetch, not a vendored copy committed to this repo
# (docs/handbooks/canon-scripts.md's reference-not-copy rule governs the
# repo's own gate.sh files, not an ephemeral test fixture).
if [ -z "${CLAUDE_PLUGIN_ROOT_CORE:-}" ] || [ ! -d "${CLAUDE_PLUGIN_ROOT_CORE:-/nonexistent}" ]; then
  _cache="${TMPDIR:-/tmp}/tokenmaxxxer-core-test-fixture"
  if [ ! -d "$_cache/.git" ]; then
    rm -rf "$_cache"
    git clone --depth 1 -q https://github.com/tokenmaxxxer/tokenmaxxxer-core "$_cache" \
      || { echo "core-fixture: could not clone tokenmaxxxer-core for test fixture" >&2; exit 1; }
  fi
  export CLAUDE_PLUGIN_ROOT_CORE="$_cache"
  unset _cache
fi
