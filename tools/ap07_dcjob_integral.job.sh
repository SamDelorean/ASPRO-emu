#!/usr/bin/env bash
# AP07 approved-launch payload for the existing dcjob dispatcher.
# PREPARED ONLY. Never execute from this repository without explicit
# per-intervention Commander authorization. No polling or discovery.
set -Eeuo pipefail
umask 077
RESULT_DIR="${DCJOB_RESULT_DIR:?dcjob launcher required}"
ASPRO="${ASPRO_ROOT:-/home/spc/Projects/alphasmart/ASPRO-emu}"
MAME="${ASPRO_MAME_REFERENCE:-/home/spc/Projects/alphasmart/mame-as2k}"
BRANCH="codex/ap02-aspro-diag-20261019"
STATUS="BLOCKED_PREFLIGHT"
REASON="not_started"
finish() {
    local rc=$?
    trap - EXIT
    printf 'AP07_DISPATCH_STATE=%s\nAP07_REASON=%s\nAP07_EXIT=%s\nAP07_AUTHENTIC_SCI=NOT_IMPLEMENTED\n' \
        "$STATUS" "$REASON" "$rc" > "$RESULT_DIR/ap07_dispatch.status"
    for name in d0_datasheet_tests.log payload_static_tests.log build.log \
                campaign.latest.json final.status; do
        if [[ -f "$ASPRO/private/ap07/$name" ]]; then
            cp -- "$ASPRO/private/ap07/$name" "$RESULT_DIR/$name" || true
        fi
    done
    exit "$rc"
}
trap finish EXIT
# Strictly known local paths, no find/ls/pwd or ad hoc Commander probes.
# A valid Git worktree may have .git as a FILE. Fetch before checking the
# AP07 script, because an AP06 checkout does not contain newer AP07 files.
git -C "$ASPRO" rev-parse --is-inside-work-tree >/dev/null 2>&1 ||
    { REASON=missing_aspro_worktree; exit 20; }
[[ -f "$MAME/makefile" ]] ||
    { REASON=missing_read_only_mame_reference; exit 20; }
[[ "$(git -C "$ASPRO" remote get-url origin)" == *SamDelorean/ASPRO-emu* ]] ||
    { REASON=unexpected_git_origin; exit 21; }
[[ "$(git -C "$ASPRO" branch --show-current)" == "$BRANCH" ]] ||
    { REASON=unexpected_aspro_branch; exit 21; }
[[ -z "$(git -C "$ASPRO" status --porcelain --untracked-files=no)" ]] ||
    { REASON=dirty_aspro_tracked_tree; exit 21; }
# Fast-forward ASPRO only, never modify AS2K or a donor MAME checkout.
git -C "$ASPRO" fetch --no-tags origin "$BRANCH" ||
    { REASON=fetch_aspro_failed; exit 22; }
git -C "$ASPRO" merge --ff-only FETCH_HEAD ||
    { REASON=non_fast_forward_checkout; exit 22; }
[[ -f "$ASPRO/tools/ap07_run_once.sh" ]] ||
    { REASON=ap07_script_missing_after_sync; exit 23; }
for source in "$ASPRO/tools/ap07_run_once.sh" "$ASPRO/tools/build_send_diag.sh"; do
    bash -n "$source" || { REASON=bad_bash_syntax; exit 23; }
done
for source in "$ASPRO/tools/ap07_campaign.py" "$ASPRO/tools/ap07_patch_d0_cpu.py" "$ASPRO/tools/ap07_assemble_payload0.py" "$ASPRO/tools/ap07_static_campaign.py"; do
    PYTHONPYCACHEPREFIX="$RESULT_DIR/pycache" python3 -m py_compile "$source" ||
        { REASON=bad_python_syntax; exit 23; }
done
STATUS=LAUNCHING_INDEPENDENT_ASPRO_DIAG
REASON=AP07_ONE_SHOT
bash "$ASPRO/tools/ap07_run_once.sh" "$MAME" 3
STATUS=AP07_SCRIPT_EXIT_ZERO_RUNTIME_STATUS_IN_REPORT
REASON=check_campaign_latest_json
