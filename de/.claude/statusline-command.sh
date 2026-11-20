#!/bin/bash
# Claude Code two-line truecolor statusline
# Line 1: model(effort) | mode | ctx | 5h | 7d | cost | velocity
# Line 2: cwd | branch/worktree
input=$(cat)
R='\033[0m'
P='\033[38;2;110;110;110m | \033[0m'

color_rgb() {
    local p=${1%.*}; : "${p:=0}"
    if (( p <= 50 )); then
        _r=$(( 25+195*p/50 )); _g=$(( 180+20*p/50 )); _b=$(( 95-95*p/50 ))
    else
        local q=$(( p-50 ))
        _r=220; _g=$(( 200-160*q/50 )); _b=$(( 20*q/50 ))
    fi
}

circle() {
    local p=${1%.*}; : "${p:=0}"
    if (( p < 20 )); then _c='\xe2\x97\x8b'
    elif (( p < 40 )); then _c='\xe2\x97\x94'
    elif (( p < 60 )); then _c='\xe2\x97\x91'
    elif (( p < 80 )); then _c='\xe2\x97\x95'
    else _c='\xe2\x97\x8f'; fi
}

usage_emoji() {
    local p=${1%.*}; : "${p:=0}"
    if (( p < 20 )); then _e='\xf0\x9f\x9f\xa2'
    elif (( p < 70 )); then _e='\xe2\x9a\xa1'
    elif (( p < 90 )); then _e='\xf0\x9f\x94\xa5'
    else _e='\xf0\x9f\x9a\xa8'; fi
}

{
    IFS= read -r model; IFS= read -r effort; IFS= read -r mode
    IFS= read -r used_pct; IFS= read -r cost
    IFS= read -r added; IFS= read -r removed
    IFS= read -r five_pct; IFS= read -r five_reset
    IFS= read -r seven_pct; IFS= read -r seven_reset
    IFS= read -r cwd; IFS= read -r git_wt; IFS= read -r orig_br
} < <(echo "$input" | jq -r '
    (.model.display_name // "unknown"),
    (.effort.level // ""),
    (.output_style.name // ""),
    (.context_window.used_percentage // 0),
    (.cost.total_cost_usd // ""),
    (.cost.total_lines_added // ""),
    (.cost.total_lines_removed // ""),
    (.rate_limits.five_hour.used_percentage // ""),
    (.rate_limits.five_hour.resets_at // ""),
    (.rate_limits.seven_day.used_percentage // ""),
    (.rate_limits.seven_day.resets_at // ""),
    (.workspace.current_dir // ""),
    (.workspace.git_worktree // ""),
    (.worktree.original_branch // "")
')
[ -z "$cwd" ] && cwd="$PWD"

# Line 1
L="\033[1;38;2;217;119;87m${model}${R}"
[ -n "$effort" ] && L="${L} \033[38;2;217;119;87m(${effort})${R}"

usage_emoji "$used_pct"; circle "$used_pct"; color_rgb "$used_pct"
L="${L}${P}${_e} \033[1;38;2;${_r};${_g};${_b}m${_c} ${used_pct%.*}%${R}"

if [ -n "$five_pct" ]; then
    circle "$five_pct"; t=""
    [ -n "$five_reset" ] && t=$(date -d "@${five_reset}" +"%-I:%M %p" 2>/dev/null || date -r "${five_reset}" +"%-I:%M %p" 2>/dev/null) && t=" (${t})"
    L="${L}${P}\033[38;2;120;200;255m5h: ${_c} ${five_pct%.*}%${t}${R}"
fi
if [ -n "$seven_pct" ]; then
    circle "$seven_pct"; t=""
    if [ -n "$seven_reset" ]; then
        d=$(( seven_reset - $(date +%s) )); (( d < 0 )) && d=0
        t=" ($(( d/86400 ))d$(( d%86400/3600 ))h)"
    fi
    L="${L}${P}\033[38;2;120;200;255m7d: ${_c} ${seven_pct%.*}%${t}${R}"
fi

if [ -n "$cost" ]; then
    printf -v cost_str '$%.2f' "$cost"
    L="${L}${P}\033[38;2;220;200;0m${cost_str}${R}"
fi
if [ -n "$added" ] || [ -n "$removed" ]; then
    L="${L}${P}\033[38;2;25;180;95m+${added:-0}${R} \033[38;2;220;40;20m-${removed:-0}${R}"
fi

# Line 2
L2="\033[38;2;150;200;255m\xf0\x9f\x93\x81 ${cwd}${R}"
if [ -z "$git_wt" ]; then
    branch=$(git -C "$cwd" rev-parse --abbrev-ref HEAD 2>/dev/null)
    [ -n "$branch" ] && [ "$branch" != HEAD ] && L2="${L2}${P}\033[38;2;120;200;120m\xf0\x9f\x8c\xbf ${branch}${R}"
else
    L2="${L2}${P}\033[38;2;0;220;220m\xf0\x9f\x8c\xbf ${git_wt}${R}"
    [ -n "$orig_br" ] && L2="${L2}${P}\033[38;2;220;180;0m\xe2\x86\x90 ${orig_br}${R}"
fi
[ -n "$mode" ] && L2="${L2}${P}\033[38;2;215;225;130m${mode}${R}"

printf '%b\n%b' "$L" "$L2"
